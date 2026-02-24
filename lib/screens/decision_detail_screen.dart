import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DecisionDetailScreen extends StatefulWidget {
  final String decisionId;
  final String title;

  const DecisionDetailScreen({
    required this.decisionId,
    required this.title,
    super.key,
  });

  @override
  State<DecisionDetailScreen> createState() => _DecisionDetailScreenState();
}

class _DecisionDetailScreenState extends State<DecisionDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? decisionData;
  List<dynamic> timeline = [];
  List<dynamic> comments = [];
  bool isLoading = true;
  String? error;
  String? selectedPollOptionId; // Track selected poll option

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDecisionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDecisionData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final detailResponse = await ApiService.fetchDecisionDetail(widget.decisionId);
      final timelineResponse = await ApiService.fetchDecisionTimeline(widget.decisionId);
      final commentsResponse = await ApiService.fetchDecisionComments(widget.decisionId);

      if (!mounted) return;

      final decision = detailResponse['data']['decision'] ?? {};
      final timelineData = timelineResponse['data']['data'] ?? [];
      final commentsList = commentsResponse['items'] ?? [];

      setState(() {
        decisionData = decision;
        timeline = timelineData;
        comments = commentsList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Comments'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Failed to load details', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadDecisionData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildCommentsTab(),
                    _buildTimelineTab(),
                  ],
                ),
    );
  }

  // ========== OVERVIEW TAB ==========
  Widget _buildOverviewTab() {
    if (decisionData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      decisionData!['title'] ?? 'Untitled',
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusBadge(decisionData!['status']),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Description (moved right after title)
          if (decisionData!['description'] != null) ...[
            Text('Description', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            Text(decisionData!['description'], style: AppTextStyles.body),
            const SizedBox(height: 24),
          ],

          // Voting Card (only for voting type in voting status)
          if (_isVotingTypeOnly() && _isVotingStatus()) ...[
            Text('Cast Your Vote', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            _buildVotingCard(),
            const SizedBox(height: 24),
          ],

          // Voting Progress (moved after voting card)
          if (_isVotingType() && _isVotingStatus() && decisionData!['voting_progress'] != null) ...[
            _buildVotingProgress(decisionData!['voting_progress']),
            const SizedBox(height: 24),
          ],

          // Requirements (moved after voting progress)
          if (_isVotingType() && decisionData!['type']?.toString().toLowerCase() == 'voting' && _isVotingStatus()) ...[
            _buildInfoSection('Requirements', [
              ('Approval %', '${decisionData!['required_approval_percentage'] ?? '0'}%'),
              ('Participation %', '${decisionData!['required_participation_percentage'] ?? '0'}%'),
            ]),
            const SizedBox(height: 24),
          ],

          // Forwarding Info (after description, before timeline)
          if (decisionData!['forwardings'] != null && (decisionData!['forwardings'] as List).isNotEmpty) ...[
            _buildForwardingInfo(decisionData!['forwardings']),
            const SizedBox(height: 24),
          ],

          // Poll Options (for poll type during voting)
          if (_isPollType() && _isVotingStatus() && decisionData!['options'] != null && (decisionData!['options'] as List).isNotEmpty) ...[
            _buildPollVotingOptions(decisionData!['options'] ?? []),
            const SizedBox(height: 24),
          ],

          // Timeline & Key Info
          _buildInfoSection('Timeline & Details', [
            ('Created', _formatDateTime(decisionData!['created_at'])),
            ('Discussion Starts', _formatDateTime(decisionData!['discussion_starts_at'])),
            ('Discussion Ends', _formatDateTime(decisionData!['discussion_ends_at'])),
            if (decisionData!['voting_starts_at'] != null)
              ('Voting Starts', _formatDateTime(decisionData!['voting_starts_at'])),
            if (decisionData!['voting_ends_at'] != null)
              ('Voting Ends', _formatDateTime(decisionData!['voting_ends_at'])),
            ('Category', decisionData!['category']?.toString().toUpperCase() ?? 'N/A'),
            ('Tier', decisionData!['tier']?.toString().toUpperCase() ?? 'N/A'),
            ('Priority', decisionData!['priority']?.toString().toUpperCase() ?? 'N/A'),
          ]),

          const SizedBox(height: 24),

          // Creator & Committees
          _buildCreatorInfo(),
        ],
      ),
    );
  }

  // ========== TIMELINE TAB ==========
  Widget _buildTimelineTab() {
    if (timeline.isEmpty) {
      return const Center(
        child: Text('No timeline events'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final event = timeline[index];
        return _buildTimelineEvent(event, index == timeline.length - 1);
      },
    );
  }

  Widget _buildTimelineEvent(dynamic event, bool isLast) {
    final eventType = event['event_type']?.toString() ?? 'unknown';
    final description = event['description']?.toString() ?? '';
    final triggeredBy = event['triggered_by_name']?.toString() ?? 'Unknown';
    final createdAt = _formatDateTime(event['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _getEventColor(eventType),
                child: Icon(
                  _getEventIcon(eventType),
                  size: 20,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: AppColors.divider,
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$triggeredBy • $createdAt',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'created':
        return AppColors.info;
      case 'discussion_started':
        return AppColors.warning;
      case 'voting_started':
        return AppColors.success;
      case 'forwarded':
        return AppColors.primary;
      case 'comment_added':
        return Color(0xFF8b5cf6);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'created':
        return Icons.add_circle_outline;
      case 'discussion_started':
        return Icons.forum;
      case 'voting_started':
        return Icons.how_to_vote;
      case 'forwarded':
        return Icons.arrow_forward;
      case 'comment_added':
        return Icons.comment;
      default:
        return Icons.info_outline;
    }
  }

  // ========== COMMENTS TAB ==========
  Widget _buildCommentsTab() {
    final commentsEnabled = decisionData?['comments_enabled'] != false;

    // Comments disabled message (e.g., for polls)
    if (!commentsEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Comments Not Available',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Discussion is not enabled for this poll. Participants can only vote on the available options.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (comments.isEmpty) {
      return const Center(
        child: Text('No comments yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildCommentCard(comment);
      },
    );
  }

  Widget _buildCommentCard(dynamic comment) {
    final author = comment['author'];
    final body = comment['body']?.toString() ?? '';
    final createdAt = _formatDateTime(comment['created_at']);
    final authorName = author?['name']?.toString() ?? 'Unknown';
    final committeeName = decisionData?['current_committee']?['name']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              authorName,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (committeeName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                committeeName,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(createdAt, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  // ========== HELPER WIDGETS ==========

  Widget _buildStatusBadge(dynamic status) {
    final statusStr = status?.toString().toLowerCase() ?? 'pending';
    Color color;
    switch (statusStr) {
      case 'approved':
        color = AppColors.success;
        break;
      case 'rejected':
        color = AppColors.error;
        break;
      case 'voting':
      case 'discussion':
      case 'forwarded':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        statusStr.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h3),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final isLast = entry.key == items.length - 1;
                final item = entry.value;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.$1,
                          style: AppTextStyles.bodySecondary,
                        ),
                        Text(
                          item.$2,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Divider(height: 1, color: AppColors.divider),
                      ),
                    if (!isLast) const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorInfo() {
    final creator = decisionData!['creator'];
    final committee = decisionData!['committee'];
    final currentCommittee = decisionData!['current_committee'];
    final votingWeight = decisionData!['voting_weight'];

    final items = <(String, String)>[];
    if (creator != null) {
      items.add(('Created By', creator['name']?.toString() ?? 'Unknown'));
    }
    if (committee != null) {
      items.add(('Original Committee', committee['name']?.toString() ?? 'N/A'));
    }
    if (currentCommittee != null) {
      items.add(('Current Committee', currentCommittee['name']?.toString() ?? 'N/A'));
    }
    if (votingWeight != null) {
      items.add(('Voting Weight', votingWeight.toString()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final isLast = entry.key == items.length - 1;
                final item = entry.value;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.$1,
                          style: AppTextStyles.bodySecondary,
                        ),
                        Text(
                          item.$2,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Divider(height: 1, color: AppColors.divider),
                      ),
                    if (!isLast) const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForwardingInfo(List<dynamic> forwardings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forwarding', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        ...forwardings.map((forwarding) {
          final fromCommittee = forwarding['from_committee']?['name'] ?? 'N/A';
          final toCommittee = forwarding['to_committee']?['name'] ?? 'N/A';
          final status = forwarding['status']?.toString() ?? 'unknown';
          final statusColor = status.toLowerCase() == 'pending' ? AppColors.warning : AppColors.success;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$fromCommittee → $toCommittee',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Forwarded ${_formatDateTime(forwarding['created_at'])}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildVotingProgress(dynamic votingProgress) {
    final approvePercent = double.tryParse(votingProgress['approve_percentage']?.toString() ?? '0') ?? 0;
    final rejectPercent = double.tryParse(votingProgress['reject_percentage']?.toString() ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voting Progress', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Approve', style: AppTextStyles.bodySecondary),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: approvePercent / 100,
                              minHeight: 8,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation(AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('${approvePercent.toStringAsFixed(1)}%', style: AppTextStyles.body),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reject', style: AppTextStyles.bodySecondary),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rejectPercent / 100,
                              minHeight: 8,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation(AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('${rejectPercent.toStringAsFixed(1)}%', style: AppTextStyles.body),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVotingCard() {
    final votingProgress = decisionData!['voting_progress'] ?? {};
    final approvePercent = double.tryParse(votingProgress['approve_percentage']?.toString() ?? '0') ?? 0;
    final rejectPercent = double.tryParse(votingProgress['reject_percentage']?.toString() ?? '0') ?? 0;
    final participation = double.tryParse(votingProgress['participation_percentage']?.toString() ?? '0') ?? 0;
    final requiredParticipation = double.tryParse(decisionData!['required_participation_percentage']?.toString() ?? '0') ?? 0;
    final currentVote = decisionData!['current_vote']; // 'approve', 'reject', 'abstain', or null

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Approve/Reject row with percentages
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check, color: AppColors.success, size: 16),
                          const SizedBox(width: 4),
                          Text('Approve: ${approvePercent.toStringAsFixed(1)}%',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: approvePercent / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation(AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.close, color: AppColors.error, size: 16),
                          const SizedBox(width: 4),
                          Text('Reject: ${rejectPercent.toStringAsFixed(1)}%',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rejectPercent / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation(AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Participation info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Participation: ${participation.toStringAsFixed(1)}%', style: AppTextStyles.bodySecondary),
                Text('Required: ${requiredParticipation.toStringAsFixed(1)}%', style: AppTextStyles.bodySecondary),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: participation / 100,
                minHeight: 6,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(AppColors.warning),
              ),
            ),
            if (participation < requiredParticipation) ...[
              const SizedBox(height: 8),
              Text(
                'Need ${(requiredParticipation - participation).toStringAsFixed(1)}% more participation',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 24),
            // Voting buttons
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement vote casting
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vote approve (not yet implemented)')),
                      );
                    },
                    icon: const Icon(Icons.thumb_up, color: Color(0xFF1B5E20)),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFC8E6C9),
                      foregroundColor: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement vote casting
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vote reject (not yet implemented)')),
                      );
                    },
                    icon: const Icon(Icons.thumb_down, color: Color(0xFFB71C1C)),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFCDD2),
                      foregroundColor: Color(0xFFB71C1C),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement vote casting
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vote abstain (not yet implemented)')),
                      );
                    },
                    icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFF424242)),
                    label: const Text('Abstain'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE0E0E0),
                      foregroundColor: Color(0xFF424242),
                    ),
                  ),
                ),
              ],
            ),
            if (currentVote != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You voted $currentVote. You can change your vote until voting ends.',
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPollVotingOptions(List<dynamic> options) {
    final timeRemaining = decisionData!['time_remaining'];
    final timeHuman = timeRemaining?['human']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with icon
        Row(
          children: [
            Icon(Icons.bar_chart, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Poll Options', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: 12),

        // Poll end time info
        if (timeHuman.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Poll ends in $timeHuman',
                    style: AppTextStyles.body.copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Poll options with radio buttons
        ...options.asMap().entries.map((entry) {
          final option = entry.value;

          if (option is! Map<String, dynamic>) return const SizedBox.shrink();

          final optionId = option['id']?.toString() ?? '';
          final optionTitle = option['title']?.toString() ?? 'Option';
          final optionDescription = option['description']?.toString() ?? '';
          final costEstimate = option['cost_estimate']?.toString();
          final votePercentage = double.tryParse(option['vote_percentage']?.toString() ?? '0') ?? 0;
          final voteCount = option['vote_count'] ?? 0;
          final proposer = option['proposer'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedPollOptionId = optionId;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Option title, description, and radio button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Radio<String>(
                          value: optionId,
                          groupValue: selectedPollOptionId,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedPollOptionId = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                optionTitle,
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (optionDescription.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  optionDescription,
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${votePercentage.toStringAsFixed(1)}%',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Vote progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: votePercentage / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Vote count and other info
                    Row(
                      children: [
                        Icon(Icons.how_to_vote, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$voteCount vote${voteCount != 1 ? 's' : ''}', style: AppTextStyles.caption),
                        if (costEstimate != null && costEstimate.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.attach_money, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('৳$costEstimate', style: AppTextStyles.caption),
                        ],
                        if (proposer != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'by ${proposer['name'] ?? 'Unknown'}',
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 16),

        // Submit Poll Vote button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: selectedPollOptionId != null
                ? () {
                    // TODO: Implement poll vote submission
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Submit vote for option ID: $selectedPollOptionId (not yet implemented)'),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Submit Poll Vote'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              disabledForegroundColor: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final date = DateTime.parse(dateTime.toString());
      return DateFormat('MMM d, yyyy (hh:mm a)').format(date);
    } catch (e) {
      return dateTime.toString();
    }
  }

  // Helper to check if decision type is voting
  bool _isVotingType() {
    final type = decisionData?['type']?.toString().toLowerCase() ?? '';
    return type == 'voting' || type == 'poll';
  }

  // Helper to check if decision type is ONLY voting (not poll)
  bool _isVotingTypeOnly() {
    final type = decisionData?['type']?.toString().toLowerCase() ?? '';
    return type == 'voting';
  }

  // Helper to check if decision type is poll
  bool _isPollType() {
    final type = decisionData?['type']?.toString().toLowerCase() ?? '';
    return type == 'poll';
  }

  // Helper to check if decision status is voting
  bool _isVotingStatus() {
    final status = decisionData?['status']?.toString().toLowerCase() ?? '';
    return status == 'voting';
  }
}
