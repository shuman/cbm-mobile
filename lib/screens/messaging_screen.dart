import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/message_notification_manager.dart';
import '../theme/app_theme.dart';
import '../utils/app_exceptions.dart';
import 'widgets/app_drawer.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> channels = [];
  List<Map<String, dynamic>> directConversations = [];
  bool isLoading = true;
  String? error;
  bool isPermissionError = false;
  late AnimationController _animationController;

  final MessageNotificationManager _manager = MessageNotificationManager();
  StreamSubscription<Map<String, dynamic>>? _uiSubscription;
  StreamSubscription<Map<String, dynamic>>? _channelAddedSubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  bool _wsConnected = false;

  // For FAB menu
  bool _isFabMenuOpen = false;

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
      isPermissionError = false;
    });

    try {
      final channelsResponse = await ApiService.fetchChannels();
      final directResponse = await ApiService.fetchDirectConversations();

      if (!mounted) return;
      setState(() {
        channels = List<Map<String, dynamic>>.from(
          (channelsResponse['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        directConversations = List<Map<String, dynamic>>.from(
          (directResponse['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        isLoading = false;
      });
      _animationController.forward();
    } on PermissionException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        isPermissionError = true;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isPermissionError = false;
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
        channels[i]['unread_count'] = ((channels[i]['unread_count'] as int?) ?? 0) + 1;
        if (i > 0) {
          final ch = channels.removeAt(i);
          channels.insert(0, ch);
        }
        return;
      }
    }
  }

  void _updateDirectConversationWithNewMessage(String conversationId, String body) {
    for (var i = 0; i < directConversations.length; i++) {
      if (directConversations[i]['id']?.toString() == conversationId) {
        directConversations[i] = Map<String, dynamic>.from(directConversations[i]);
        directConversations[i]['last_message'] = {'body': body};
        directConversations[i]['unread_count'] = ((directConversations[i]['unread_count'] as int?) ?? 0) + 1;
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabMenuOpen) ...[
            FloatingActionButton.extended(
              heroTag: 'create_channel',
              onPressed: () {
                setState(() => _isFabMenuOpen = false);
                _showCreateChannelDialog();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.tag),
              label: const Text('Create Channel'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'start_dm',
              onPressed: () {
                setState(() => _isFabMenuOpen = false);
                _showStartDirectMessageDialog();
              },
              backgroundColor: AppColors.info,
              icon: const Icon(Icons.person),
              label: const Text('Direct Message'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            onPressed: () {
              setState(() => _isFabMenuOpen = !_isFabMenuOpen);
            },
            backgroundColor: AppColors.primary,
            child: Icon(_isFabMenuOpen ? Icons.close : Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPermissionError ? Icons.lock_outline : Icons.error_outline,
                          size: 64,
                          color: isPermissionError ? AppColors.warning : AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isPermissionError ? 'Access Denied' : 'Failed to load messages',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/home'),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Go Home'),
                        ),
                      ],
                    ),
                  )
                : channels.isEmpty && directConversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 24),
                            Text('No Messages Yet', style: AppTextStyles.h2.copyWith(color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Text('Create a channel or start a direct message',
                                style: AppTextStyles.caption.copyWith(color: Colors.grey[500])),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showCreateChannelDialog,
                              icon: const Icon(Icons.tag),
                              label: const Text('Create Channel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _showStartDirectMessageDialog,
                              icon: const Icon(Icons.person),
                              label: const Text('Start Direct Message'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.info,
                                side: const BorderSide(color: AppColors.info),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (channels.isNotEmpty) ...[
                            Text('Channels', style: AppTextStyles.h3),
                            const SizedBox(height: 12),
                            ...channels.map((channel) => _buildChannelItem(channel)),
                            const SizedBox(height: 24),
                          ],
                          if (directConversations.isNotEmpty) ...[
                            Text('Direct Messages', style: AppTextStyles.h3),
                            const SizedBox(height: 12),
                            ...directConversations.map((conv) => _buildConversationItem(conv)),
                          ],
                        ],
                      ),
      ),
    );
  }

  void _showCreateChannelDialog() {
    final rootContext = context;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    List<dynamic> selectedMemberIds = [];
    List<Map<String, dynamic>> projectUsers = [];
    bool isLoadingUsers = true;
    bool isCreating = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load users when dialog opens
            if (isLoadingUsers && projectUsers.isEmpty) {
              ApiService.fetchProjectUsers().then((response) {
                if (response['items'] != null) {
                  final items = response['items'];
                  if (items is Map && items['data'] != null) {
                    projectUsers = List<Map<String, dynamic>>.from(
                      (items['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
                    );
                  } else if (items is List) {
                    projectUsers = List<Map<String, dynamic>>.from(
                      items.map((e) => Map<String, dynamic>.from(e as Map)),
                    );
                  }
                }
                setDialogState(() => isLoadingUsers = false);
              }).catchError((e) {
                setDialogState(() {
                  isLoadingUsers = false;
                  dialogError = 'Failed to load users';
                });
              });
            }

            return AlertDialog(
              title: const Text('Create Channel'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Channel Name *',
                        hintText: 'e.g., general, announcements',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'What is this channel about?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text('Add Members *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (isLoadingUsers)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (projectUsers.isEmpty)
                      Text('No users available', style: TextStyle(color: Colors.grey[600]))
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: projectUsers.length,
                          itemBuilder: (context, index) {
                            final projectUser = projectUsers[index];
                            final user = projectUser['user'] as Map<String, dynamic>?;
                            if (user == null) return const SizedBox();

                            final userId = user['id'];
                            final userName = user['name'] ?? 'Unknown';
                            final userEmail = user['email'] ?? '';
                            final isActive = projectUser['is_active'] == true;

                            if (!isActive) return const SizedBox();

                            return CheckboxListTile(
                              value: selectedMemberIds.contains(userId),
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selectedMemberIds.add(userId);
                                  } else {
                                    selectedMemberIds.remove(userId);
                                  }
                                });
                              },
                              title: Text(userName),
                              subtitle: Text(userEmail, style: const TextStyle(fontSize: 12)),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(dialogError!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final description = descriptionController.text.trim();

                          if (name.isEmpty) {
                            setDialogState(() => dialogError = 'Channel name is required');
                            return;
                          }

                          if (selectedMemberIds.isEmpty) {
                            setDialogState(() => dialogError = 'Please select at least one member');
                            return;
                          }

                          setDialogState(() {
                            isCreating = true;
                            dialogError = null;
                          });

                          try {
                            debugPrint('[CreateChannel] Starting channel creation...');
                            debugPrint('[CreateChannel] Name: $name, Members: ${selectedMemberIds.length}');

                            final result = await ApiService.createChannel(
                              name: name,
                              description: description.isEmpty ? null : description,
                              memberIds: selectedMemberIds,
                            );

                            debugPrint('[CreateChannel] API Response: $result');
                            debugPrint('[CreateChannel] Success value: ${result['success']}');
                            debugPrint('[CreateChannel] Items type: ${result['items'].runtimeType}');
                            debugPrint('[CreateChannel] Items value: ${result['items']}');

                            final success = result['success'] == true || result['success'] == 1;
                            if (!success) {
                              debugPrint('[CreateChannel] Success is not true/1, error');
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isCreating = false;
                                dialogError = 'Failed to create channel';
                              });
                              return;
                            }

                            final channelData = result['items'] as Map<String, dynamic>?;
                            debugPrint('[CreateChannel] Channel data: $channelData');
                            final channelId = channelData?['id']?.toString();
                            debugPrint('[CreateChannel] Extracted channel ID: $channelId');

                            if (channelId == null) {
                              debugPrint('[CreateChannel] Channel ID is null, error');
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isCreating = false;
                                dialogError = 'Invalid response: missing channel ID';
                              });
                              return;
                            }

                            debugPrint('[CreateChannel] Valid channel ID, closing dialog');
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();

                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text('Channel #$name created!'),
                                backgroundColor: AppColors.success,
                              ),
                            );

                            debugPrint('[CreateChannel] Starting background refresh...');
                            _loadData();

                            if (mounted) {
                              debugPrint('[CreateChannel] Waiting before navigation...');
                              await Future.delayed(const Duration(milliseconds: 300));
                              debugPrint('[CreateChannel] Navigating to channel: $channelId');
                              rootContext.push('/channel/$channelId', extra: {
                                'channelName': name,
                              });
                            }
                          } catch (e) {
                            debugPrint('[CreateChannel] Exception caught: $e');
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isCreating = false;
                              dialogError = 'Error: ${e.toString()}';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStartDirectMessageDialog() {
    final rootContext = context;
    dynamic selectedUserId;
    List<Map<String, dynamic>> projectUsers = [];
    bool isLoadingUsers = true;
    bool isCreating = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load users when dialog opens
            if (isLoadingUsers && projectUsers.isEmpty) {
              ApiService.fetchProjectUsers().then((response) {
                if (response['items'] != null) {
                  final items = response['items'];
                  if (items is Map && items['data'] != null) {
                    projectUsers = List<Map<String, dynamic>>.from(
                      (items['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
                    );
                  } else if (items is List) {
                    projectUsers = List<Map<String, dynamic>>.from(
                      items.map((e) => Map<String, dynamic>.from(e as Map)),
                    );
                  }
                }
                setDialogState(() => isLoadingUsers = false);
              }).catchError((e) {
                setDialogState(() {
                  isLoadingUsers = false;
                  dialogError = 'Failed to load users';
                });
              });
            }

            return AlertDialog(
              title: const Text('Start Direct Message'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a user to start messaging'),
                    const SizedBox(height: 16),
                    if (isLoadingUsers)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (projectUsers.isEmpty)
                      Text('No users available', style: TextStyle(color: Colors.grey[600]))
                    else
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: projectUsers.length,
                          itemBuilder: (context, index) {
                            final projectUser = projectUsers[index];
                            final user = projectUser['user'] as Map<String, dynamic>?;
                            if (user == null) return const SizedBox();

                            final userId = user['id'];
                            final userName = user['name'] ?? 'Unknown';
                            final userEmail = user['email'] ?? '';
                            final isActive = projectUser['is_active'] == true;

                            if (!isActive) return const SizedBox();

                            return RadioListTile<dynamic>(
                              value: userId,
                              groupValue: selectedUserId,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedUserId = value;
                                });
                              },
                              title: Text(userName),
                              subtitle: Text(userEmail, style: const TextStyle(fontSize: 12)),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(dialogError!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (selectedUserId == null) {
                            setDialogState(() => dialogError = 'Please select a user');
                            return;
                          }

                          setDialogState(() {
                            isCreating = true;
                            dialogError = null;
                          });

                          try {
                            debugPrint('[CreateDirectConversation] Starting conversation creation...');
                            debugPrint('[CreateDirectConversation] Selected user: $selectedUserId');

                            final result = await ApiService.startDirectConversation(selectedUserId!);

                            debugPrint('[CreateDirectConversation] API Response: $result');
                            debugPrint('[CreateDirectConversation] Success value: ${result['success']}');
                            debugPrint('[CreateDirectConversation] Items type: ${result['items'].runtimeType}');
                            debugPrint('[CreateDirectConversation] Items value: ${result['items']}');

                            final success = result['success'] == true || result['success'] == 1;
                            if (!success) {
                              debugPrint('[CreateDirectConversation] Success is not true/1, error');
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isCreating = false;
                                dialogError = 'Failed to start conversation';
                              });
                              return;
                            }

                            final conversationData = result['items'] as Map<String, dynamic>?;
                            debugPrint('[CreateDirectConversation] Conversation data: $conversationData');
                            final conversationId = conversationData?['id']?.toString();
                            final otherUser = conversationData?['other_user'] as Map<String, dynamic>?;
                            final userName = otherUser?['name']?.toString() ?? 'Unknown User';
                            debugPrint('[CreateDirectConversation] Extracted conversation ID: $conversationId, user: $userName');

                            if (conversationId == null) {
                              debugPrint('[CreateDirectConversation] Conversation ID is null, error');
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isCreating = false;
                                dialogError = 'Invalid response: missing conversation ID';
                              });
                              return;
                            }

                            debugPrint('[CreateDirectConversation] Valid conversation ID, closing dialog');
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();

                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text('Started conversation with $userName!'),
                                backgroundColor: AppColors.success,
                              ),
                            );

                            debugPrint('[CreateDirectConversation] Starting background refresh...');
                            _loadData();

                            if (mounted) {
                              debugPrint('[CreateDirectConversation] Waiting before navigation...');
                              await Future.delayed(const Duration(milliseconds: 300));
                              debugPrint('[CreateDirectConversation] Navigating to conversation: $conversationId');
                              rootContext.push('/direct/$conversationId', extra: {
                                'recipientName': userName,
                              });
                            }
                          } catch (e) {
                            debugPrint('[CreateDirectConversation] Exception caught: $e');
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isCreating = false;
                              dialogError = 'Error: ${e.toString()}';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Start'),
                ),
              ],
            );
          },
        );
      },
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor:
                  unreadCount > 0 ? AppColors.primary.withOpacity(0.15) : AppColors.primary.withOpacity(0.08),
              child: Icon(Icons.tag, color: AppColors.primary, size: 20),
            ),
            title: Text(
              name,
              style: AppTextStyles.body.copyWith(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: (lastMessageText ?? description) != null
                ? Text(
                    lastMessageText ?? description ?? '',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: unreadCount > 0
                ? _buildUnreadBadge(unreadCount)
                : Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
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
    final name = conversation['name']?.toString() ?? conversation['other_user']?['name']?.toString() ?? 'Unknown User';

    final lastMessage = conversation['last_message'];
    String? lastMessageText;

    if (lastMessage != null) {
      if (lastMessage is String) {
        lastMessageText = lastMessage;
      } else if (lastMessage is Map) {
        lastMessageText =
            lastMessage['body']?.toString() ?? lastMessage['content']?.toString() ?? lastMessage['text']?.toString();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: unreadCount > 0 ? AppColors.info.withOpacity(0.15) : AppColors.info.withOpacity(0.08),
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
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: lastMessageText != null
                ? Text(
                    lastMessageText,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: unreadCount > 0
                ? _buildUnreadBadge(unreadCount)
                : Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
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
