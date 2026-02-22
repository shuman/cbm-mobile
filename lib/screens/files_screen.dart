import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'widgets/app_drawer.dart';
import 'widgets/empty_state.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<dynamic> files = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await ApiService.fetchFiles();
      if (!mounted) return;
      setState(() {
        files = response['items'] ?? [];
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
        title: const Text('Files'),
      ),
      drawer: const AppDrawer(currentRoute: '/files'),
      body: RefreshIndicator(
        onRefresh: _loadFiles,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load files', style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(error!, style: AppTextStyles.caption, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadFiles,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : files.isEmpty
                    ? const EmptyState(
                        icon: Icons.folder_outlined,
                        title: 'No Files',
                        message: 'No files have been uploaded yet',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          return _buildFileCard(file);
                        },
                      ),
      ),
    );
  }

  Widget _buildFileCard(dynamic file) {
    final fileName = file['name']?.toString() ?? file['original_name']?.toString() ?? 'Untitled File';
    final mimeType = file['mime_type']?.toString() ?? file['type']?.toString() ?? 'unknown';
    final fileSize = file['size'] is int ? file['size'] : (int.tryParse(file['size']?.toString() ?? '0') ?? 0);
    final uploadedAt = file['updated_at']?.toString() ?? file['created_at']?.toString() ?? '';
    final isDirectory = file['is_directory'] == true || file['is_directory'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDirectory 
              ? AppColors.warning.withOpacity(0.1)
              : _getFileColor(mimeType).withOpacity(0.1),
          child: Icon(
            isDirectory ? Icons.folder : _getFileIcon(mimeType),
            color: isDirectory ? AppColors.warning : _getFileColor(mimeType),
            size: 24,
          ),
        ),
        title: Text(
          fileName,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${_formatFileSize(fileSize)} • ${_formatDate(uploadedAt)}',
              style: AppTextStyles.caption,
            ),
            if (file['uploader']?['name'] != null || file['creator']?['name'] != null)
              Text(
                'Uploaded by ${file['uploader']?['name']?.toString() ?? file['creator']?['name']?.toString() ?? ''}',
                style: AppTextStyles.caption,
              ),
          ],
        ),
        trailing: Icon(Icons.download, size: 20, color: AppColors.textSecondary),
        onTap: () {
          _showFileDetail(file);
        },
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    final lowerType = fileType.toLowerCase();
    if (lowerType.contains('pdf')) return Icons.picture_as_pdf;
    if (lowerType.contains('image') || lowerType.contains('png') || lowerType.contains('jpg') || lowerType.contains('jpeg')) {
      return Icons.image;
    }
    if (lowerType.contains('video')) return Icons.video_file;
    if (lowerType.contains('word') || lowerType.contains('doc')) return Icons.description;
    if (lowerType.contains('excel') || lowerType.contains('sheet')) return Icons.table_chart;
    if (lowerType.contains('zip') || lowerType.contains('archive')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileType) {
    final lowerType = fileType.toLowerCase();
    if (lowerType.contains('pdf')) return AppColors.error;
    if (lowerType.contains('image')) return AppColors.success;
    if (lowerType.contains('video')) return Color(0xFF8b5cf6);
    if (lowerType.contains('word') || lowerType.contains('doc')) return AppColors.info;
    if (lowerType.contains('excel') || lowerType.contains('sheet')) return AppColors.success;
    return AppColors.textSecondary;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  void _showFileDetail(dynamic file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
                    Center(
                      child: Icon(
                        _getFileIcon(file['type'] ?? ''),
                        size: 64,
                        color: _getFileColor(file['type'] ?? ''),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      file['name']?.toString() ?? 'Untitled File',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 32),
                    if (!file['is_directory']) ...[
                      _buildDetailRow('Size', _formatFileSize(file['size'] is int ? file['size'] : (int.tryParse(file['size']?.toString() ?? '0') ?? 0))),
                      const SizedBox(height: 12),
                    ],
                    _buildDetailRow('Type', file['is_directory'] ? 'Folder' : (file['mime_type']?.toString() ?? file['type']?.toString() ?? 'Unknown')),
                    const SizedBox(height: 12),
                    _buildDetailRow('Updated', _formatDate(file['updated_at']?.toString() ?? file['created_at']?.toString() ?? '')),
                    if (file['uploader']?['name'] != null || file['creator']?['name'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow('By', file['uploader']?['name']?.toString() ?? file['creator']?['name']?.toString() ?? ''),
                    ],
                    if (file['path'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow('Path', file['path']?.toString() ?? ''),
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
