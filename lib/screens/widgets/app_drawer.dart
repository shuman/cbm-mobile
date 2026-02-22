import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_bloc.dart';
import '../../theme/app_theme.dart';
import '../../utils/storage_util.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          StorageUtil.getUser().then((value) => value ?? {}),
          StorageUtil.getProjectId(),
          StorageUtil.getProjectName(),
        ]),
        builder: (context, snapshot) {
          final user = snapshot.data?[0] as Map<String, dynamic>?;
          final projectId = snapshot.data?[1] as String?;
          final projectName = snapshot.data?[2] as String?;
          final userName = user?['name'] ?? 'User';
          
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user?['email'] != null)
                      Text(
                        user!['email'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    if (projectName != null && projectName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.business, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  projectName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildNavItem(
                context,
                icon: Icons.home,
                title: 'Home',
                route: '/home',
              ),
              const Divider(),
              _buildSectionHeader(context, 'Quick Navigation'),
              _buildNavItem(
                context,
                icon: Icons.chat_bubble_outline,
                title: 'Messaging',
                route: '/messaging',
              ),
              _buildNavItem(
                context,
                icon: Icons.check_circle_outline,
                title: 'Decisions',
                route: '/decisions',
              ),
              _buildNavItem(
                context,
                icon: Icons.campaign,
                title: 'Notice Board',
                route: '/notices',
              ),
              const Divider(),
              _buildSectionHeader(context, 'Management'),
              _buildNavItem(
                context,
                icon: Icons.folder_outlined,
                title: 'Files',
                route: '/files',
              ),
              _buildNavItem(
                context,
                icon: Icons.people_outline,
                title: 'Members',
                route: '/members',
              ),
              _buildNavItem(
                context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Deposits',
                route: '/deposits',
              ),
              _buildNavItem(
                context,
                icon: Icons.receipt_long_outlined,
                title: 'Expenses',
                route: '/expenses',
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
                title: const Text('Switch Project'),
                onTap: () async {
                  Navigator.pop(context);
                  await StorageUtil.clearProjectId();
                  context.go('/project-selection');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<AuthBloc>().add(LogoutEvent());
                  context.go('/login');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
