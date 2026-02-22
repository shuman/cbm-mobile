import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
    });

    try {
      final response = await ApiService.fetchDecisions();
      if (!mounted) return;
      setState(() {
        decisions = response['items'] ?? [];
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
                        Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load decisions', style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadDecisions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : decisions.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'No Decisions',
                        message: 'No decisions have been created yet',
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _showDecisionDetail(decision);
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
        return AppColors.warning;
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

  void _showDecisionDetail(dynamic decision) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      decision['title']?.toString() ?? 'Untitled Decision',
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Status', decision['status']?.toString() ?? 'pending'),
                    const SizedBox(height: 12),
                    _buildDetailRow('Created', _formatDate(decision['created_at']?.toString() ?? '')),
                    const SizedBox(height: 12),
                    if (decision['deadline'] != null)
                      _buildDetailRow('Deadline', _formatDate(decision['deadline']?.toString() ?? '')),
                    const Divider(height: 32),
                    if (decision['description'] != null) ...[
                      Text('Description', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text(
                        decision['description']?.toString() ?? '',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AppTextStyles.bodySecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
