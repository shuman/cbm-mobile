import 'package:equatable/equatable.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();

  @override
  List<Object?> get props => [];
}

class ConnectWebSocketEvent extends MessageEvent {
  const ConnectWebSocketEvent();
}

class DisconnectWebSocketEvent extends MessageEvent {
  const DisconnectWebSocketEvent();
}

class LoadChannelMessagesEvent extends MessageEvent {
  final String channelId;
  final bool loadMore;

  const LoadChannelMessagesEvent({
    required this.channelId,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [channelId, loadMore];
}

class LoadDirectMessagesEvent extends MessageEvent {
  final String conversationId;
  final bool loadMore;

  const LoadDirectMessagesEvent({
    required this.conversationId,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [conversationId, loadMore];
}

class SendChannelMessageEvent extends MessageEvent {
  final String channelId;
  final String body;

  const SendChannelMessageEvent({
    required this.channelId,
    required this.body,
  });

  @override
  List<Object?> get props => [channelId, body];
}

class SendDirectMessageEvent extends MessageEvent {
  final String conversationId;
  final String body;

  const SendDirectMessageEvent({
    required this.conversationId,
    required this.body,
  });

  @override
  List<Object?> get props => [conversationId, body];
}

class SubscribeToChannelEvent extends MessageEvent {
  final String channelType;
  final String channelId;

  const SubscribeToChannelEvent({
    required this.channelType,
    required this.channelId,
  });

  @override
  List<Object?> get props => [channelType, channelId];
}

class UnsubscribeFromChannelEvent extends MessageEvent {
  final String channelType;
  final String channelId;

  const UnsubscribeFromChannelEvent({
    required this.channelType,
    required this.channelId,
  });

  @override
  List<Object?> get props => [channelType, channelId];
}

class ReceiveMessageEvent extends MessageEvent {
  final String channelType;
  final String channelId;
  final Map<String, dynamic> messageData;

  const ReceiveMessageEvent({
    required this.channelType,
    required this.channelId,
    required this.messageData,
  });

  @override
  List<Object?> get props => [channelType, channelId, messageData];
}

class MarkConversationAsReadEvent extends MessageEvent {
  final String conversationId;

  const MarkConversationAsReadEvent({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

class StartTypingEvent extends MessageEvent {
  final String channelType;
  final String channelId;

  const StartTypingEvent({
    required this.channelType,
    required this.channelId,
  });

  @override
  List<Object?> get props => [channelType, channelId];
}

class StopTypingEvent extends MessageEvent {
  final String channelType;
  final String channelId;

  const StopTypingEvent({
    required this.channelType,
    required this.channelId,
  });

  @override
  List<Object?> get props => [channelType, channelId];
}

class UserTypingEvent extends MessageEvent {
  final String channelType;
  final String channelId;
  final String userName;

  const UserTypingEvent({
    required this.channelType,
    required this.channelId,
    required this.userName,
  });

  @override
  List<Object?> get props => [channelType, channelId, userName];
}

class ConnectionStatusChangedEvent extends MessageEvent {
  final bool isConnected;

  const ConnectionStatusChangedEvent({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}
