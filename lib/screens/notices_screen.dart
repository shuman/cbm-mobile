import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_exceptions.dart';
import 'widgets/app_drawer.dart';
import 'widgets/empty_state.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<dynamic> notices = [];
  bool isLoading = true;
  String? error;
  bool isPermissionError = false;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
      isPermissionError = false;
    });

    try {
      final response = await ApiService.fetchNotices();
      if (!mounted) return;
      setState(() {
        notices = response['items'] ?? [];
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
    final pinnedNotices = notices.where((n) => n['is_pinned'] == true).toList();
    final regularNotices = notices.where((n) => n['is_pinned'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board'),
      ),
      drawer: const AppDrawer(currentRoute: '/notices'),
      body: RefreshIndicator(
        onRefresh: _loadNotices,
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
                          isPermissionError ? 'Access Denied' : 'Failed to load notices',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        if (!isPermissionError)
                          ElevatedButton(
                            onPressed: _loadNotices,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  )
                : notices.isEmpty
                    ? const EmptyState(
                        icon: Icons.campaign,
                        title: 'No Notices',
                        message: 'No notices have been posted yet',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (pinnedNotices.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('Pinned', style: AppTextStyles.h3),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...pinnedNotices.map((notice) => _buildNoticeCard(notice, isPinned: true)),
                            const SizedBox(height: 24),
                          ],
                          if (regularNotices.isNotEmpty) ...[
                            if (pinnedNotices.isNotEmpty)
                              Text('Recent', style: AppTextStyles.h3),
                            if (pinnedNotices.isNotEmpty) const SizedBox(height: 12),
                            ...regularNotices.map((notice) => _buildNoticeCard(notice)),
                          ],
                        ],
                      ),
      ),
    );
  }

  Widget _buildNoticeCard(dynamic notice, {bool isPinned = false}) {
    final title = notice['title']?.toString() ?? 'Untitled Notice';
    final content = notice['content']?.toString();
    final importance = notice['importance']?.toString() ?? '';
    final creatorName = notice['creator']?['name']?.toString();
    final createdAt = notice['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPinned ? 2 : 1,
      child: InkWell(
        onTap: () {
          _showNoticeDetail(notice);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (content != null && content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content,
                  style: AppTextStyles.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (importance.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getImportanceColor(importance).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    importance.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: _getImportanceColor(importance),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
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
                  if (creatorName != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      creatorName,
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

  Color _getImportanceColor(String importance) {
    final lowerImportance = importance.toLowerCase();
    if (lowerImportance.contains('high') || lowerImportance.contains('urgent')) {
      return AppColors.error;
    }
    if (lowerImportance.contains('medium') || lowerImportance.contains('normal')) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showNoticeDetail(dynamic notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                    if (notice['is_pinned'] == true)
                      Row(
                        children: [
                          Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'PINNED',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (notice['is_pinned'] == true) const SizedBox(height: 12),
                    Text(
                      notice['title'] ?? 'Untitled Notice',
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(notice['created_at'] ?? ''),
                          style: AppTextStyles.caption,
                        ),
                        if (notice['author']?['name'] != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            notice['author']['name'],
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 32),
                    if (notice['importance'] != null) ...[
                      Row(
                        children: [
                          Text('Importance: ', style: AppTextStyles.bodySecondary),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getImportanceColor(notice['importance']?.toString() ?? '').withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notice['importance']?.toString().toUpperCase() ?? '',
                              style: TextStyle(
                                color: _getImportanceColor(notice['importance']?.toString() ?? ''),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (notice['content'] != null) ...[
                      Text('Content', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text(
                        notice['content']?.toString() ?? '',
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
}
