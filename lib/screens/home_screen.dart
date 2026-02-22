import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/storage_util.dart';
import 'widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: StorageUtil.getProjectName(),
          builder: (context, snapshot) {
            final projectName = snapshot.data;
            return Text(projectName ?? 'Dashboard');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Project',
            onPressed: () async {
              await StorageUtil.clearProjectId();
              if (context.mounted) {
                context.go('/project-selection');
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/home'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Navigation', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildQuickNavCard(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Messaging',
                  color: AppColors.info,
                  onTap: () => context.go('/messaging'),
                ),
                _buildQuickNavCard(
                  context,
                  icon: Icons.check_circle_outline,
                  label: 'Decisions',
                  color: AppColors.success,
                  onTap: () => context.go('/decisions'),
                ),
                _buildQuickNavCard(
                  context,
                  icon: Icons.campaign,
                  label: 'Notice Board',
                  color: AppColors.warning,
                  onTap: () => context.go('/notices'),
                ),
                _buildQuickNavCard(
                  context,
                  icon: Icons.folder_outlined,
                  label: 'Files',
                  color: Color(0xFF8b5cf6),
                  onTap: () => context.go('/files'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Management', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              icon: Icons.people_outline,
              title: 'Members',
              subtitle: 'Manage project members',
              onTap: () => context.go('/members'),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Deposits',
              subtitle: 'View and add deposits',
              onTap: () => context.go('/deposits'),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'Expenses',
              subtitle: 'Track project expenses',
              onTap: () => context.go('/expenses'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNavCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
