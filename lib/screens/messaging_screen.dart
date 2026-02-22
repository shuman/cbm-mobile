import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/message_notification_manager.dart';
import '../theme/app_theme.dart';
import 'widgets/app_drawer.dart';
import 'widgets/empty_state.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> channels = [];
  List<Map<String, dynamic>> directConversations = [];
  bool isLoading = true;
  String? error;
  late AnimationController _animationController;

  final MessageNotificationManager _manager = MessageNotificationManager();
  StreamSubscription<Map<String, dynamic>>? _uiSubscription;
  StreamSubscription<Map<String, dynamic>>? _channelAddedSubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _wsConnected = _manager.isConnected;
    _loadData();

    // Listen for live message events from the global manager
    _uiSubscription = _manager.uiUpdateStream.listen(_handleUIUpdate);

    // Refresh the full list when current user is added to a new channel
    _channelAddedSubscription = _manager.channelAddedStream.listen((_) {
      if (mounted) _loadData();
    });
    _statusSubscription = _manager.connectionStatusStream.listen((status) {
      if (!mounted) return;
      final connected = status == ConnectionStatus.connected;
      if (connected != _wsConnected) {
        setState(() => _wsConnected = connected);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && !isLoading) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _uiSubscription?.cancel();
    _channelAddedSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final channelsResponse = await ApiService.fetchChannels();
      final directResponse = await ApiService.fetchDirectConversations();

      if (!mounted) return;
      setState(() {
        channels = List<Map<String, dynamic>>.from(
          (channelsResponse['items'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
              [],
        );
        directConversations = List<Map<String, dynamic>>.from(
          (directResponse['items'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
              [],
        );
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _handleUIUpdate(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type'] as String?;
    final id = event['id'] as String?;
    final body = event['body'] as String? ?? '';
    if (type == null || id == null) return;

    setState(() {
      if (type == 'channel') {
        _updateChannelWithNewMessage(id, body);
      } else if (type == 'direct') {
        _updateDirectConversationWithNewMessage(id, body);
      }
    });
  }

  void _updateChannelWithNewMessage(String channelId, String body) {
    for (var i = 0; i < channels.length; i++) {
      if (channels[i]['id']?.toString() == channelId) {
        channels[i] = Map<String, dynamic>.from(channels[i]);
        channels[i]['last_message'] = {'body': body};
        channels[i]['unread_count'] =
            ((channels[i]['unread_count'] as int?) ?? 0) + 1;
        if (i > 0) {
          final ch = channels.removeAt(i);
          channels.insert(0, ch);
        }
        return;
      }
    }
  }

  void _updateDirectConversationWithNewMessage(
      String conversationId, String body) {
    for (var i = 0; i < directConversations.length; i++) {
      if (directConversations[i]['id']?.toString() == conversationId) {
        directConversations[i] =
            Map<String, dynamic>.from(directConversations[i]);
        directConversations[i]['last_message'] = {'body': body};
        directConversations[i]['unread_count'] =
            ((directConversations[i]['unread_count'] as int?) ?? 0) + 1;
        if (i > 0) {
          final conv = directConversations.removeAt(i);
          directConversations.insert(0, conv);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _wsConnected
                ? Icon(Icons.circle, size: 10, color: AppColors.success)
                : SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/messaging'),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load messages',
                            style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(error!,
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Retry')),
                      ],
                    ),
                  )
                : channels.isEmpty && directConversations.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No Messages',
                        message: 'No channels or conversations yet',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (channels.isNotEmpty) ...[
                            Text('Channels', style: AppTextStyles.h3),
                            const SizedBox(height: 12),
                            ...channels.map(
                                (channel) => _buildChannelItem(channel)),
                            const SizedBox(height: 24),
                          ],
                          if (directConversations.isNotEmpty) ...[
                            Text('Direct Messages', style: AppTextStyles.h3),
                            const SizedBox(height: 12),
                            ...directConversations
                                .map((conv) => _buildConversationItem(conv)),
                          ],
                        ],
                      ),
      ),
    );
  }

  Widget _buildChannelItem(Map<String, dynamic> channel) {
    final name = channel['name']?.toString() ?? 'Unnamed Channel';
    final description = channel['description']?.toString();
    final lastMessage = channel['last_message'];
    String? lastMessageText;

    if (lastMessage != null && lastMessage is Map) {
      lastMessageText = lastMessage['body']?.toString();
    }

    final unreadCount = (channel['unread_count'] is int)
        ? channel['unread_count'] as int
        : int.tryParse(channel['unread_count']?.toString() ?? '') ?? 0;

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        )),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: unreadCount > 0 ? 3 : 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: unreadCount > 0
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.08),
              child:
                  Icon(Icons.tag, color: AppColors.primary, size: 20),
            ),
            title: Text(
              name,
              style: AppTextStyles.body.copyWith(
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: (lastMessageText ?? description) != null
                ? Text(
                    lastMessageText ?? description ?? '',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: unreadCount > 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: unreadCount > 0
                ? _buildUnreadBadge(unreadCount)
                : Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppColors.textSecondary),
            onTap: () async {
              final channelId = channel['id']?.toString();
              if (channelId != null) {
                await context.push('/channel/$channelId', extra: {
                  'channelName': name,
                });
                if (mounted) _loadData();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final name = conversation['name']?.toString() ??
        conversation['other_user']?['name']?.toString() ??
        'Unknown User';

    final lastMessage = conversation['last_message'];
    String? lastMessageText;

    if (lastMessage != null) {
      if (lastMessage is String) {
        lastMessageText = lastMessage;
      } else if (lastMessage is Map) {
        lastMessageText = lastMessage['body']?.toString() ??
            lastMessage['content']?.toString() ??
            lastMessage['text']?.toString();
      } else {
        lastMessageText = lastMessage.toString();
      }
    }

    final unreadCount = (conversation['unread_count'] is int)
        ? conversation['unread_count'] as int
        : int.tryParse(conversation['unread_count']?.toString() ?? '') ?? 0;

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        )),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: unreadCount > 0 ? 3 : 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: unreadCount > 0
                  ? AppColors.info.withOpacity(0.15)
                  : AppColors.info.withOpacity(0.08),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: AppTextStyles.body.copyWith(
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: lastMessageText != null
                ? Text(
                    lastMessageText,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: unreadCount > 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: unreadCount > 0
                ? _buildUnreadBadge(unreadCount)
                : Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppColors.textSecondary),
            onTap: () async {
              final conversationId = conversation['id']?.toString();
              if (conversationId != null) {
                await context.push('/direct/$conversationId', extra: {
                  'recipientName': name,
                });
                if (mounted) _loadData();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
