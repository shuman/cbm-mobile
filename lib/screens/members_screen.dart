import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_exceptions.dart';
import 'widgets/app_drawer.dart';
import 'widgets/empty_state.dart';
import 'widgets/member_detail_sheet.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<dynamic> members = [];
  bool isLoading = true;
  String? error;
  bool isPermissionError = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
      isPermissionError = false;
    });

    try {
      final response = await ApiService.fetchMembers();
      if (!mounted) return;
      setState(() {
        members = response['items'] ?? [];
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
        title: const Text('Members'),
      ),
      drawer: const AppDrawer(currentRoute: '/members'),
      body: RefreshIndicator(
        onRefresh: _loadMembers,
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
                          isPermissionError ? 'Access Denied' : 'Failed to load members',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        if (!isPermissionError)
                          ElevatedButton(
                            onPressed: _loadMembers,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  )
                : members.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No Members',
                        message: 'No members in this project yet',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return _buildMemberCard(member);
                        },
                      ),
      ),
    );
  }

  Widget _buildMemberCard(dynamic member) {
    final name = member['user']?['name']?.toString() ?? member['invited_name']?.toString() ?? 'Unknown';
    final email = member['user']?['email']?.toString() ?? member['invited_email']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'Member';
    final invitationStatus = member['invitation_status']?.toString();
    final isActive = member['is_active'] == true || member['is_active'] == 1;
    final joinedAt = member['joined_at']?.toString() ?? member['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(email, style: AppTextStyles.caption),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (!isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'INACTIVE',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textDisabled,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (invitationStatus != null && invitationStatus != 'accepted') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      invitationStatus.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: _getRoleColor(role),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (joinedAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Joined ${_formatDate(joinedAt)}',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        onTap: () {
          _showMemberDetail(member);
        },
      ),
    );
  }

  String? _extractMemberId(dynamic member) {
    final directId = member['id']?.toString();
    if (directId != null && directId.isNotEmpty) return directId;

    final userId = member['user_id']?.toString();
    if (userId != null && userId.isNotEmpty) return userId;

    final nestedUserId = member['user']?['id']?.toString();
    if (nestedUserId != null && nestedUserId.isNotEmpty) return nestedUserId;

    return null;
  }

  Color _getRoleColor(String role) {
    final lowerRole = role.toLowerCase();
    if (lowerRole.contains('admin') || lowerRole.contains('owner')) return AppColors.error;
    if (lowerRole.contains('manager')) return AppColors.primary;
    if (lowerRole.contains('lead')) return AppColors.info;
    return AppColors.success;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showMemberDetail(dynamic member) {
    final memberId = _extractMemberId(member);
    final name = member['user']?['name']?.toString() ?? member['invited_name']?.toString() ?? 'Unknown';
    final email = member['user']?['email']?.toString() ?? member['invited_email']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'Member';
    final phone = member['user']?['phone']?.toString() ?? member['invited_phone']?.toString() ?? '';
    final address = member['user']?['address']?.toString() ?? member['invited_address']?.toString() ?? '';
    final invitationStatus = member['invitation_status']?.toString();
    final isActive = member['is_active'] == true || member['is_active'] == 1;
    final memberCode = member['member_code']?.toString();
    final joinedAt = member['joined_at']?.toString() ?? member['created_at']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberDetailSheet(
        memberId: memberId,
        name: name,
        email: email,
        phone: phone,
        address: address,
        role: role,
        memberCode: memberCode,
        joinedAt: joinedAt,
        isActive: isActive,
        invitationStatus: invitationStatus,
      ),
    );
  }
}
