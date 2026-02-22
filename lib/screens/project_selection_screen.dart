import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../utils/storage_util.dart';
import '../theme/app_theme.dart';

class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen> {
  List<dynamic> projects = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      if (kDebugMode) debugPrint('[ProjectSelection] Loading projects...');
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await ApiService.fetchProjects()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Request timed out');
      });
      
      if (kDebugMode) debugPrint('[ProjectSelection] Got ${response['items']?.length ?? 0} projects');
      
      if (response['items'] != null) {
        setState(() {
          projects = response['items'] as List<dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'No projects found';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load projects: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _selectProject(dynamic project) async {
    try {
      final projectId = project['id'].toString();
      final projectName = project['name']?.toString() ?? 
                         project['slug']?.toString() ?? 
                         'Project #$projectId';
      
      await StorageUtil.setProjectId(projectId);
      await StorageUtil.setProjectName(projectName);
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select project: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Project'),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: AppTextStyles.body.copyWith(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadProjects,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : projects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_off_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Projects Assigned',
                              style: AppTextStyles.h3,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You don\'t have access to any projects yet. Please contact your administrator to be added to a project.',
                              style: AppTextStyles.bodySecondary,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final projectName = project['name']?.toString() ?? project['slug']?.toString() ?? 'Unnamed Project';
                        final projectDescription = project['description']?.toString();
                        final membersCount = project['members_count'] ?? 0;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              projectName,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (projectDescription != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      projectDescription,
                                      style: AppTextStyles.caption,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Members: $membersCount',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            onTap: () => _selectProject(project),
                          ),
                        );
                      },
                    ),
    );
  }
}
