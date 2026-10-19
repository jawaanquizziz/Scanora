import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/scanora_logo.dart';
import '../../models/document_folder.dart';
import '../../services/storage_service.dart';
import '../documents/documents_screen.dart';

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  Future<void> _createFolder(BuildContext context) async {
    final result = await CustomDialogs.showCreateFolderDialog(context: context);
    if (result != null) {
      final name = result['name'] as String;
      final color = result['color'] as int;
      await StorageService().createFolder(name, colorValue: color);
    }
  }

  Future<void> _renameFolder(BuildContext context, DocumentFolder folder) async {
    final newName = await CustomDialogs.showInputDialog(
      context: context,
      title: 'Rename Folder',
      initialValue: folder.name,
      hintText: 'Enter folder name',
    );

    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      await StorageService().renameFolder(folder.id, newName);
    }
  }

  Future<void> _deleteFolder(BuildContext context, DocumentFolder folder) async {
    final confirm = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Delete Folder?',
      message: 'Are you sure you want to delete "${folder.name}"? Documents in this folder will remain safe in your library.',
      confirmLabel: 'Delete Folder',
    );

    if (confirm) {
      await StorageService().deleteFolder(folder.id);
    }
  }

  void _openFolderDocuments(BuildContext context, DocumentFolder folder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.folder, color: Color(folder.colorValue), size: 24),
                const SizedBox(width: 10),
                Text(folder.name),
              ],
            ),
          ),
          body: DocumentsScreen(initialFolderId: folder.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StorageService(),
      builder: (context, _) {
        final storage = StorageService();
        final folders = storage.folders;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ScanoraLogo(size: 24, hasShadow: false),
                const SizedBox(width: 8),
                const Text('Folders', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'New Folder',
                onPressed: () => _createFolder(context),
              ),
            ],
          ),
          body: folders.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'No Folders Yet',
                  message: 'Create folders to categorize your scanned documents, receipts, and notes.',
                  actionLabel: 'Create First Folder',
                  onActionPressed: () => _createFolder(context),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final count = storage.getDocumentCountInFolder(folder.id);

                    return Card(
                      child: InkWell(
                        onTap: () => _openFolderDocuments(context, folder),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Color(folder.colorValue).withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.folder,
                                  color: Color(folder.colorValue),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      folder.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$count ${count == 1 ? 'document' : 'documents'} • Created ${DateFormatter.formatDisplay(folder.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
                                onSelected: (val) {
                                  if (val == 'rename') {
                                    _renameFolder(context, folder);
                                  } else if (val == 'delete') {
                                    _deleteFolder(context, folder);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 20),
                                        SizedBox(width: 12),
                                        Text('Rename Folder'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                        SizedBox(width: 12),
                                        Text('Delete Folder', style: TextStyle(color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
