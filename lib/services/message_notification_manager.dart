import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';
import 'websocket_service.dart';
import 'notification_service.dart';
import '../utils/storage_util.dart';
import '../router/app_router.dart' show rootNavigatorKey;

/// Runs at the app level to deliver notifications from any screen.
/// Connects WebSocket, subscribes to all channels/conversations,
/// and shows both in-app overlay + native notifications.
class MessageNotificationManager {
  static final MessageNotificationManager _instance =
      MessageNotificationManager._internal();
  factory MessageNotificationManager() => _instance;
  MessageNotificationManager._internal();

  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;

  String? _currentUserId;
  bool _active = false;
  bool _wsConnected = false;

  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _conversations = [];

  // MessagingScreen listens to this for live message-list updates
  final StreamController<Map<String, dynamic>> _uiUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get uiUpdateStream => _uiUpdateController.stream;

  // MessagingScreen listens to this to refresh when user is added to a new channel
  final StreamController<Map<String, dynamic>> _channelAddedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get channelAddedStream => _channelAddedController.stream;

  bool get isConnected => _wsConnected;
  Stream<ConnectionStatus> get connectionStatusStream => _wsService.statusStream;

  Future<void> start() async {
    if (_active) return;
    _active = true;

    final user = await StorageUtil.getUser();
    _currentUserId = user?['id']?.toString();

    if (kDebugMode) debugPrint('[NotifManager] Starting (userId=$_currentUserId)');

    _messageSubscription =
        _wsService.globalMessageStream.listen(_handleIncomingMessage);

    _statusSubscription = _wsService.statusStream.listen((status) {
      final connected = status == ConnectionStatus.connected;
      if (connected && !_wsConnected) {
        _wsConnected = true;
        _subscribeToAll();
      } else if (!connected) {
        _wsConnected = false;
      }
    });

    _wsService.resetReconnection();
    await _wsService.connect();

    // Sync _wsConnected — connect() returns early if already connected,
    // so the status listener may never fire. Capture the current state here.
    _wsConnected = _wsService.status == ConnectionStatus.connected;

    await _fetchAndSubscribe();

    // Subscribe to personal channel for "added to channel" events
    if (_currentUserId != null) {
      _wsService.subscribeToPersonalChannel('App.Models.User.$_currentUserId');
    }
  }

  Future<void> _fetchAndSubscribe() async {
    try {
      final chResp = await ApiService.fetchChannels();
      final dmResp = await ApiService.fetchDirectConversations();
      _channels = List<Map<String, dynamic>>.from(
        (chResp['items'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            [],
      );
      _conversations = List<Map<String, dynamic>>.from(
        (dmResp['items'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            [],
      );
      if (_wsConnected) _subscribeToAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[NotifManager] Fetch error: $e');
    }
  }

  void _subscribeToAll() {
    if (kDebugMode) {
      debugPrint(
          '[NotifManager] Subscribing to ${_channels.length} channels + ${_conversations.length} DMs');
    }
    for (final ch in _channels) {
      final id = ch['id']?.toString();
      if (id != null) _wsService.subscribeToChannel('channel', id);
    }
    for (final conv in _conversations) {
      final id = conv['id']?.toString();
      if (id != null) _wsService.subscribeToChannel('direct', id);
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final eventType = data['event_type'] as String?;

    if (eventType == 'channel.member.added') {
      _handleChannelMemberAdded(data['data'] as Map<String, dynamic>? ?? {});
      return;
    }

    if (eventType != 'message.sent') return;

    final channel = data['channel'] as String?;
    final messageData = data['data'] as Map<String, dynamic>?;
    if (channel == null || messageData == null) return;

    // Parse: "private-messaging.channel.{id}" or "private-messaging.direct.{id}"
    final stripped = channel.replaceFirst('private-messaging.', '');
    final dotIndex = stripped.indexOf('.');
    if (dotIndex < 0) return;

    final type = stripped.substring(0, dotIndex);
    final id = stripped.substring(dotIndex + 1);

    final msgInfo = messageData['message'] as Map<String, dynamic>?;
    if (msgInfo == null) return;

    // Support both field naming conventions:
    //   Channel messages: user_id / user
    //   Direct messages:  sender_id / sender
    final senderId = msgInfo['sender_id']?.toString() ??
        msgInfo['user_id']?.toString() ??
        (msgInfo['sender'] as Map?)?['id']?.toString() ??
        (msgInfo['user'] as Map?)?['id']?.toString();

    final senderName =
        (msgInfo['sender'] as Map?)?['name']?.toString() ??
        (msgInfo['user'] as Map?)?['name']?.toString() ??
        'Someone';

    final body = msgInfo['body']?.toString() ?? '';

    // Don't notify for own messages
    if (senderId == _currentUserId) return;

    if (kDebugMode) {
      debugPrint('[NotifManager] New message from $senderName on $type.$id');
    }

    // Forward to MessagingScreen for list counter/preview updates
    _uiUpdateController.add({
      'type': type,
      'id': id,
      'senderName': senderName,
      'body': body,
    });

    final displayName = _getDisplayName(type, id);
    final title = type == 'channel' ? '#$displayName - $senderName' : senderName;

    _showInAppNotification(title, body, type, id, displayName, senderName);

    NotificationService().showNativeNotification(
      title: title,
      body: body,
      payload: '$type:$id',
    );
  }

  void _handleChannelMemberAdded(Map<String, dynamic> data) {
    final channelId = data['channel_id']?.toString() ?? '';
    final channelName = data['channel_name']?.toString() ?? 'Channel';
    final addedByName = data['added_by_name']?.toString() ?? 'Someone';

    if (kDebugMode) {
      debugPrint('[NotifManager] Added to channel #$channelName by $addedByName');
    }

    // Signal MessagingScreen to refresh its channel list
    _channelAddedController.add({
      'channel_id': channelId,
      'channel_name': channelName,
    });

    // Re-fetch channel list so the new channel is subscribed too
    _fetchAndSubscribe();

    // In-app notification
    const title = 'New Channel';
    final body = '$addedByName added you to #$channelName';
    _showInAppNotification(title, body, 'channel', channelId, channelName, addedByName);

    // Native notification
    NotificationService().showNativeNotification(
      title: title,
      body: body,
      payload: 'channel:$channelId',
    );
  }

  void _showInAppNotification(
    String title,
    String body,
    String type,
    String id,
    String displayName,
    String senderName,
  ) {
    final navigatorState = rootNavigatorKey.currentState;
    final overlay = navigatorState?.overlay;
    if (overlay == null) {
      if (kDebugMode) debugPrint('[NotifManager] overlay is null, skipping in-app notification');
      return;
    }

    NotificationService.showInAppNotification(
      overlay,
      title: title,
      body: body,
      onTap: () {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        if (type == 'channel') {
          GoRouter.of(context).push('/channel/$id', extra: {'channelName': displayName});
        } else {
          GoRouter.of(context).push('/direct/$id', extra: {'recipientName': senderName});
        }
      },
    );
  }

  String _getDisplayName(String type, String id) {
    if (type == 'channel') {
      for (final ch in _channels) {
        if (ch['id']?.toString() == id) {
          return ch['name']?.toString() ?? 'Channel';
        }
      }
      return 'Channel';
    } else {
      for (final conv in _conversations) {
        if (conv['id']?.toString() == id) {
          return conv['name']?.toString() ??
              conv['other_user']?['name']?.toString() ??
              'User';
        }
      }
      return 'User';
    }
  }

  void stop() {
    if (kDebugMode) debugPrint('[NotifManager] Stopping');
    _active = false;
    _wsConnected = false;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _channels.clear();
    _conversations.clear();
    _wsService.disconnect();
  }

  void dispose() {
    stop();
    _uiUpdateController.close();
    _channelAddedController.close();
  }
}
