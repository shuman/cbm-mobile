import 'package:equatable/equatable.dart';
import '../models/message.dart';

abstract class MessageState extends Equatable {
  const MessageState();

  @override
  List<Object?> get props => [];
}

class MessageInitialState extends MessageState {
  const MessageInitialState();
}

class MessageLoadingState extends MessageState {
  final String channelId;
  final bool isLoadingMore;

  const MessageLoadingState({
    required this.channelId,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [channelId, isLoadingMore];
}

class MessageLoadedState extends MessageState {
  final String channelId;
  final String channelType;
  final List<Message> messages;
  final bool hasMore;
  final int currentPage;
  final bool isConnected;
  final bool isSending;
  final String? typingUser;

  const MessageLoadedState({
    required this.channelId,
    required this.channelType,
    required this.messages,
    this.hasMore = false,
    this.currentPage = 1,
    this.isConnected = false,
    this.isSending = false,
    this.typingUser,
  });

  MessageLoadedState copyWith({
    String? channelId,
    String? channelType,
    List<Message>? messages,
    bool? hasMore,
    int? currentPage,
    bool? isConnected,
    bool? isSending,
    String? typingUser,
  }) {
    return MessageLoadedState(
      channelId: channelId ?? this.channelId,
      channelType: channelType ?? this.channelType,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isConnected: isConnected ?? this.isConnected,
      isSending: isSending ?? this.isSending,
      typingUser: typingUser,
    );
  }

  @override
  List<Object?> get props => [channelId, channelType, messages, hasMore, currentPage, isConnected, isSending, typingUser];
}

class MessageErrorState extends MessageState {
  final String channelId;
  final String error;

  const MessageErrorState({
    required this.channelId,
    required this.error,
  });

  @override
  List<Object?> get props => [channelId, error];
}

class MessageSentState extends MessageState {
  final String channelId;
  final Message message;

  const MessageSentState({
    required this.channelId,
    required this.message,
  });

  @override
  List<Object?> get props => [channelId, message];
}
