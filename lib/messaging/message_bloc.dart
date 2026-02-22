import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'message_event.dart';
import 'message_state.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/storage_util.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final WebSocketService _wsService = WebSocketService();
  final Map<String, StreamSubscription<Map<String, dynamic>>> _subscriptions = {};
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  String? _currentUserId;

  Timer? _typingTimer;

  MessageBloc() : super(const MessageInitialState()) {
    on<ConnectWebSocketEvent>(_onConnect);
    on<DisconnectWebSocketEvent>(_onDisconnect);
    on<LoadChannelMessagesEvent>(_onLoadChannelMessages);
    on<LoadDirectMessagesEvent>(_onLoadDirectMessages);
    on<SendChannelMessageEvent>(_onSendChannelMessage);
    on<SendDirectMessageEvent>(_onSendDirectMessage);
    on<SubscribeToChannelEvent>(_onSubscribeToChannel);
    on<UnsubscribeFromChannelEvent>(_onUnsubscribeFromChannel);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<MarkConversationAsReadEvent>(_onMarkConversationAsRead);
    on<StartTypingEvent>(_onStartTyping);
    on<StopTypingEvent>(_onStopTyping);
    on<UserTypingEvent>(_onUserTyping);
    on<ConnectionStatusChangedEvent>(_onConnectionStatusChanged);

    _initializeUserId();
    _listenToConnectionStatus();
  }

  void _listenToConnectionStatus() {
    _statusSubscription = _wsService.statusStream.listen((status) {
      if (isClosed) return;
      final isConnected = status == ConnectionStatus.connected;
      add(ConnectionStatusChangedEvent(isConnected: isConnected));
    });
  }

  Future<void> _initializeUserId() async {
    final userJson = await StorageUtil.getUser();
    if (userJson != null && userJson.containsKey('id')) {
      _currentUserId = userJson['id']?.toString();
    }
  }

  Future<void> _onConnect(ConnectWebSocketEvent event, Emitter<MessageState> emit) async {
    if (kDebugMode) debugPrint('[MessageBloc] [DEBUG] ConnectWebSocketEvent received');
    try {
      if (kDebugMode) debugPrint('[MessageBloc] [DEBUG] Calling _wsService.connect()...');
      await _wsService.connect();
      if (kDebugMode) debugPrint('[MessageBloc] [DEBUG] ✓ WebSocket connect() returned (status: ${_wsService.status})');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MessageBloc] [DEBUG] ✗ WebSocket connection error: $e');
        debugPrint('[MessageBloc] [DEBUG] Stack: $st');
      }
    }
  }

  Future<void> _onDisconnect(DisconnectWebSocketEvent event, Emitter<MessageState> emit) async {
    _wsService.disconnect();
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    if (kDebugMode) debugPrint('[MessageBloc] WebSocket disconnected');
  }

  Future<void> _onLoadChannelMessages(LoadChannelMessagesEvent event, Emitter<MessageState> emit) async {
    if (_currentUserId == null) {
      await _initializeUserId();
    }

    try {
      if (state is MessageLoadedState) {
        final currentState = state as MessageLoadedState;
        if (currentState.channelId == event.channelId && event.loadMore) {
          emit(currentState.copyWith(isSending: true));
          final nextPage = currentState.currentPage + 1;
          final response = await ApiService.fetchChannelMessages(event.channelId, page: nextPage);
          
          final newMessages = (response['items'] as List?)
              ?.map((m) => Message.fromJson(m as Map<String, dynamic>, _currentUserId ?? ''))
              .toList() ?? [];

          emit(currentState.copyWith(
            messages: [...currentState.messages, ...newMessages],
            hasMore: newMessages.length >= 50,
            currentPage: nextPage,
            isSending: false,
          ));
          return;
        }
      }

      emit(MessageLoadingState(channelId: event.channelId));

      final response = await ApiService.fetchChannelMessages(event.channelId);
      final messages = (response['items'] as List?)
          ?.map((m) => Message.fromJson(m as Map<String, dynamic>, _currentUserId ?? ''))
          .toList() ?? [];

      emit(MessageLoadedState(
        channelId: event.channelId,
        channelType: 'channel',
        messages: messages,
        hasMore: messages.length >= 50,
        isConnected: true,
      ));

      if (kDebugMode) debugPrint('[MessageBloc] Loaded ${messages.length} channel messages, now subscribing...');
      add(SubscribeToChannelEvent(channelType: 'channel', channelId: event.channelId));
    } catch (e) {
      if (kDebugMode) debugPrint('[MessageBloc] Load channel messages error: $e');
      emit(MessageErrorState(channelId: event.channelId, error: e.toString()));
    }
  }

  Future<void> _onLoadDirectMessages(LoadDirectMessagesEvent event, Emitter<MessageState> emit) async {
    if (_currentUserId == null) {
      await _initializeUserId();
    }

    try {
      if (state is MessageLoadedState) {
        final currentState = state as MessageLoadedState;
        if (currentState.channelId == event.conversationId && event.loadMore) {
          emit(currentState.copyWith(isSending: true));
          final nextPage = currentState.currentPage + 1;
          final response = await ApiService.fetchDirectMessages(event.conversationId, page: nextPage);
          
          final newMessages = (response['items'] as List?)
              ?.map((m) => Message.fromJson(m as Map<String, dynamic>, _currentUserId ?? ''))
              .toList() ?? [];

          emit(currentState.copyWith(
            messages: [...currentState.messages, ...newMessages],
            hasMore: newMessages.length >= 50,
            currentPage: nextPage,
            isSending: false,
          ));
          return;
        }
      }

      emit(MessageLoadingState(channelId: event.conversationId));

      final response = await ApiService.fetchDirectMessages(event.conversationId);
      final messages = (response['items'] as List?)
          ?.map((m) => Message.fromJson(m as Map<String, dynamic>, _currentUserId ?? ''))
          .toList() ?? [];

      emit(MessageLoadedState(
        channelId: event.conversationId,
        channelType: 'direct',
        messages: messages,
        hasMore: messages.length >= 50,
        isConnected: true,
      ));

      if (kDebugMode) debugPrint('[MessageBloc] Loaded ${messages.length} direct messages, now subscribing...');
      add(SubscribeToChannelEvent(channelType: 'direct', channelId: event.conversationId));
      
      add(MarkConversationAsReadEvent(conversationId: event.conversationId));
    } catch (e) {
      if (kDebugMode) debugPrint('[MessageBloc] Load direct messages error: $e');
      emit(MessageErrorState(channelId: event.conversationId, error: e.toString()));
    }
  }

  Future<void> _onSendChannelMessage(SendChannelMessageEvent event, Emitter<MessageState> emit) async {
    if (state is! MessageLoadedState) return;
    
    final currentState = state as MessageLoadedState;
    emit(currentState.copyWith(isSending: true));

    try {
      final response = await ApiService.sendChannelMessage(event.channelId, event.body);
      
      if (kDebugMode) debugPrint('[MessageBloc] Channel message sent, parsing response...');
      
      if (_currentUserId == null) {
        await _initializeUserId();
      }
      
      final messageData = response['items'] is Map 
          ? response['items'] as Map<String, dynamic>
          : (response['message'] is Map ? response['message'] as Map<String, dynamic> : null);
      
      if (messageData != null) {
        final sentMessage = Message.fromJson(messageData, _currentUserId ?? '');
        
        final isDuplicate = currentState.messages.any((m) => m.id == sentMessage.id);
        if (!isDuplicate) {
          final updatedMessages = [sentMessage, ...currentState.messages];
          emit(currentState.copyWith(messages: updatedMessages, isSending: false));
          if (kDebugMode) debugPrint('[MessageBloc] ✓ Added sent message to UI');
        } else {
          emit(currentState.copyWith(isSending: false));
          if (kDebugMode) debugPrint('[MessageBloc] Duplicate sent message, skipping');
        }
      } else {
        if (kDebugMode) debugPrint('[MessageBloc] Warning: Could not find message data in response');
        emit(currentState.copyWith(isSending: false));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MessageBloc] Send message error: $e');
      emit(currentState.copyWith(isSending: false));
      emit(MessageErrorState(channelId: event.channelId, error: 'Failed to send message'));
      emit(currentState);
    }
  }

  Future<void> _onSendDirectMessage(SendDirectMessageEvent event, Emitter<MessageState> emit) async {
    if (state is! MessageLoadedState) return;
    
    final currentState = state as MessageLoadedState;
    emit(currentState.copyWith(isSending: true));

    try {
      final response = await ApiService.sendDirectMessage(event.conversationId, event.body);
      
      if (kDebugMode) debugPrint('[MessageBloc] Direct message sent, parsing response...');
      
      if (_currentUserId == null) {
        await _initializeUserId();
      }
      
      final messageData = response['items'] is Map 
          ? response['items'] as Map<String, dynamic>
          : (response['message'] is Map ? response['message'] as Map<String, dynamic> : null);
      
      if (messageData != null) {
        final sentMessage = Message.fromJson(messageData, _currentUserId ?? '');
        
        final isDuplicate = currentState.messages.any((m) => m.id == sentMessage.id);
        if (!isDuplicate) {
          final updatedMessages = [sentMessage, ...currentState.messages];
          emit(currentState.copyWith(messages: updatedMessages, isSending: false));
          if (kDebugMode) debugPrint('[MessageBloc] ✓ Added sent message to UI');
        } else {
          emit(currentState.copyWith(isSending: false));
          if (kDebugMode) debugPrint('[MessageBloc] Duplicate sent message, skipping');
        }
      } else {
        if (kDebugMode) debugPrint('[MessageBloc] Warning: Could not find message data in response');
        emit(currentState.copyWith(isSending: false));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MessageBloc] Send direct message error: $e');
      emit(currentState.copyWith(isSending: false));
      emit(MessageErrorState(channelId: event.conversationId, error: 'Failed to send message'));
      emit(currentState);
    }
  }

  Future<void> _onSubscribeToChannel(SubscribeToChannelEvent event, Emitter<MessageState> emit) async {
    final key = '${event.channelType}.${event.channelId}';
    
    if (_subscriptions.containsKey(key)) {
      if (kDebugMode) debugPrint('[MessageBloc] Already subscribed to $key');
      return;
    }

    if (kDebugMode) debugPrint('[MessageBloc] Subscribing to ${event.channelType}.${event.channelId}');

    await _wsService.subscribeToChannel(event.channelType, event.channelId);
    
    final stream = _wsService.getChannelStream(event.channelType, event.channelId);
    if (stream != null) {
      if (kDebugMode) debugPrint('[MessageBloc] Got stream for ${event.channelType}.${event.channelId}');
      
      _subscriptions[key] = stream.listen(
        (messageData) {
          if (kDebugMode) debugPrint('[MessageBloc] Stream received data for $key: $messageData');
          add(ReceiveMessageEvent(
            channelType: event.channelType,
            channelId: event.channelId,
            messageData: messageData,
          ));
        },
        onError: (error) {
          if (kDebugMode) debugPrint('[MessageBloc] Stream error for $key: $error');
        },
        onDone: () {
          if (kDebugMode) debugPrint('[MessageBloc] Stream closed for $key');
        },
      );
    } else {
      if (kDebugMode) debugPrint('[MessageBloc] WARNING: No stream available for ${event.channelType}.${event.channelId}');
    }

    if (state is MessageLoadedState) {
      final currentState = state as MessageLoadedState;
      emit(currentState.copyWith(isConnected: true));
    }
  }

  Future<void> _onUnsubscribeFromChannel(UnsubscribeFromChannelEvent event, Emitter<MessageState> emit) async {
    final key = '${event.channelType}.${event.channelId}';
    
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);
    
    _wsService.unsubscribeFromChannel(event.channelType, event.channelId);
  }

  Future<void> _onReceiveMessage(ReceiveMessageEvent event, Emitter<MessageState> emit) async {
    if (kDebugMode) debugPrint('[MessageBloc] _onReceiveMessage called for ${event.channelType}.${event.channelId}');
    
    if (_currentUserId == null) {
      await _initializeUserId();
    }

    if (state is! MessageLoadedState) {
      if (kDebugMode) debugPrint('[MessageBloc] State is not MessageLoadedState, ignoring message');
      return;
    }
    
    final currentState = state as MessageLoadedState;
    if (kDebugMode) debugPrint('[MessageBloc] Current state channelId: ${currentState.channelId}, event channelId: ${event.channelId}');
    
    if (currentState.channelId != event.channelId) {
      if (kDebugMode) debugPrint('[MessageBloc] Channel ID mismatch, ignoring message');
      return;
    }

    try {
      if (kDebugMode) debugPrint('[MessageBloc] Event message data: ${event.messageData}');
      
      final messageJson = event.messageData['message'] as Map<String, dynamic>;
      if (kDebugMode) debugPrint('[MessageBloc] Parsed message JSON: $messageJson');
      
      final newMessage = Message.fromJson(messageJson, _currentUserId ?? '');
      if (kDebugMode) debugPrint('[MessageBloc] Created Message object: id=${newMessage.id}, body=${newMessage.body}, isFromMe=${newMessage.isFromMe}');
      
      final isDuplicate = currentState.messages.any((m) => m.id == newMessage.id);
      if (isDuplicate) {
        if (kDebugMode) debugPrint('[MessageBloc] Duplicate message detected, skipping');
        return;
      }

      final updatedMessages = [newMessage, ...currentState.messages];
      if (kDebugMode) debugPrint('[MessageBloc] Updating state with ${updatedMessages.length} messages');
      
      emit(currentState.copyWith(messages: updatedMessages));
      
      if (kDebugMode) debugPrint('[MessageBloc] ✓ Message added to UI: ${newMessage.body}');
      
      if (event.channelType == 'direct' && !newMessage.isFromMe) {
        add(MarkConversationAsReadEvent(conversationId: event.channelId));
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[MessageBloc] Receive message error: $e');
        debugPrint('[MessageBloc] Stack trace: $stackTrace');
      }
    }
  }

  Future<void> _onMarkConversationAsRead(MarkConversationAsReadEvent event, Emitter<MessageState> emit) async {
    try {
      await ApiService.markConversationAsRead(event.conversationId);
      if (kDebugMode) debugPrint('[MessageBloc] Marked conversation as read');
    } catch (e) {
      if (kDebugMode) debugPrint('[MessageBloc] Mark as read error: $e');
    }
  }

  Future<void> _onStartTyping(StartTypingEvent event, Emitter<MessageState> emit) async {
    // Typing indicators would require backend support for client events
    // For now, this is a placeholder for future enhancement
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      add(StopTypingEvent(channelType: event.channelType, channelId: event.channelId));
    });
  }

  Future<void> _onStopTyping(StopTypingEvent event, Emitter<MessageState> emit) async {
    _typingTimer?.cancel();
  }

  Future<void> _onUserTyping(UserTypingEvent event, Emitter<MessageState> emit) async {
    if (state is! MessageLoadedState) return;
    
    final currentState = state as MessageLoadedState;
    if (currentState.channelId != event.channelId) return;

    emit(currentState.copyWith(typingUser: event.userName));
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (state is MessageLoadedState) {
      final updatedState = state as MessageLoadedState;
      if (updatedState.typingUser == event.userName) {
        emit(updatedState.copyWith(typingUser: null));
      }
    }
  }

  Future<void> _onConnectionStatusChanged(ConnectionStatusChangedEvent event, Emitter<MessageState> emit) async {
    if (isClosed) return;
    if (state is MessageLoadedState) {
      final currentState = state as MessageLoadedState;
      emit(currentState.copyWith(isConnected: event.isConnected));
      // When connection established, retry subscription if we don't have one (e.g. was queued earlier)
      if (event.isConnected && !isClosed) {
        final key = '${currentState.channelType}.${currentState.channelId}';
        if (!_subscriptions.containsKey(key)) {
          if (kDebugMode) debugPrint('[MessageBloc] Connection established, retrying subscription for $key');
          add(SubscribeToChannelEvent(channelType: currentState.channelType, channelId: currentState.channelId));
        }
      }
    }
  }

  @override
  Future<void> close() {
    _typingTimer?.cancel();
    _statusSubscription?.cancel();
    _statusSubscription = null;
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }
}
