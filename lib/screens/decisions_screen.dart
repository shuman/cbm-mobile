import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_exceptions.dart';
import 'widgets/app_drawer.dart';
import 'widgets/empty_state.dart';

class DecisionsScreen extends StatefulWidget {
  const DecisionsScreen({super.key});

  @override
  State<DecisionsScreen> createState() => _DecisionsScreenState();
}

class _DecisionsScreenState extends State<DecisionsScreen> {
  List<dynamic> decisions = [];
  bool isLoading = true;
  String? error;
  bool isPermissionError = false;

  @override
  void initState() {
    super.initState();
    _loadDecisions();
  }

  Future<void> _loadDecisions() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
      isPermissionError = false;
    });

    try {
      final response = await ApiService.fetchDecisions(
        sortBy: 'created_at',
        sortDir: 'desc',
        perPage: 15,
        page: 1,
      );
      final payload = response['data'];
      final rawList = payload is Map<String, dynamic>
          ? payload['data']
          : response['items'];

      final allItems = rawList is List ? rawList : <dynamic>[];
      final decisionItems = allItems
          .whereType<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;
      setState(() {
        decisions = decisionItems;
        isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decisions'),
      ),
      drawer: const AppDrawer(currentRoute: '/decisions'),
      body: RefreshIndicator(
        onRefresh: _loadDecisions,
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
                          isPermissionError ? 'Access Denied' : 'Failed to load decisions',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        if (!isPermissionError)
                          ElevatedButton(
                            onPressed: _loadDecisions,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  )
                : decisions.isEmpty
                    ? const EmptyState(
                        icon: Icons.ballot_outlined,
                        title: 'No Decisions',
                        message: 'No discussions, polls, or voting items found',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: decisions.length,
                        itemBuilder: (context, index) {
                          final decision = decisions[index];
                          return _buildDecisionCard(decision);
                        },
                      ),
      ),
    );
  }

  Widget _buildDecisionCard(dynamic decision) {
    final status = decision['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final createdAt = decision['created_at']?.toString() ?? '';
    final creatorName = decision['creator']?['name']?.toString() ?? 'Unknown';
    final committeeName = decision['current_committee']?['name']?.toString() ??
        decision['committee']?['name']?.toString() ??
        'N/A';
    final typeLabel = decision['type_label']?.toString() ?? 'Discussion';
    final typeColor = _getTypeColor(decision['type']?.toString().toLowerCase() ?? 'discussion');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final decisionId = decision['id']?.toString();
          final title = decision['title']?.toString() ?? 'Decision';
          if (decisionId != null) {
            context.push('/decisions/$decisionId', extra: {'title': title});
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      decision['title']?.toString() ?? 'Untitled Decision',
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      typeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (decision['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  decision['description']?.toString() ?? '',
                  style: AppTextStyles.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: AppTextStyles.caption,
                  ),
                  if (decision['votes_count'] != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.how_to_vote, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${decision['votes_count']} votes',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      committeeName,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      creatorName,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      case 'discussion':
      case 'voting':
      case 'forwarded':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'discussion':
        return AppColors.info;
      case 'poll':
        return Color(0xFF8b5cf6);
      case 'voting':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
