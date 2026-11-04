import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/scanora_logo.dart';
import '../../models/document_folder.dart';
import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../documents/documents_screen.dart';

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  Future<void> _createFolder(BuildContext context) async {
    final result = await CustomDialogs.showCreateFolderDialog(context: context);
    if (result != null) {
      final name = result['name'] as String;
      final color = result['color'] as int;
      final isLocked = result['isLocked'] as bool? ?? false;
      await StorageService().createFolder(
        name,
        colorValue: color,
        isLocked: isLocked,
      );
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

  Future<void> _toggleFolderLock(BuildContext context, DocumentFolder folder) async {
    final authenticated = await BiometricService().authenticate(
      reason: folder.isLocked
          ? 'Authenticate to unlock folder "${folder.name}"'
          : 'Authenticate to protect folder "${folder.name}" as a Biometric Vault',
    );

    if (authenticated) {
      await StorageService().toggleFolderLock(folder.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              folder.isLocked
                  ? 'Vault lock removed from "${folder.name}"'
                  : 'Folder "${folder.name}" is now a Biometric Vault!',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteFolder(BuildContext context, DocumentFolder folder) async {
    final confirm = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Delete Folder?',
      message:
          'Are you sure you want to delete "${folder.name}"? Documents in this folder will remain safe in your library.',
      confirmLabel: 'Delete Folder',
    );

    if (confirm) {
      await StorageService().deleteFolder(folder.id);
    }
  }

  Future<void> _openFolderDocuments(BuildContext context, DocumentFolder folder) async {
    if (folder.isLocked) {
      final authenticated = await BiometricService().authenticate(
        reason: 'Authenticate to open Vault folder "${folder.name}"',
      );
      if (!authenticated) return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  folder.isLocked ? Icons.folder_special_rounded : Icons.folder,
                  color: Color(folder.colorValue),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(folder.name),
                if (folder.isLocked) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_rounded, size: 16, color: AppColors.primaryBlue),
                ],
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
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScanoraLogo(size: 24, hasShadow: false),
                SizedBox(width: 8),
                Text('Folders', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  message:
                      'Create folders or Biometric Vaults to categorize and protect your scanned documents.',
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
                              Stack(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Color(folder.colorValue).withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      folder.isLocked
                                          ? Icons.folder_special_rounded
                                          : Icons.folder,
                                      color: Color(folder.colorValue),
                                      size: 28,
                                    ),
                                  ),
                                  if (folder.isLocked)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lock_rounded,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            folder.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (folder.isLocked) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withAlpha(25),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'VAULT',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                  if (val == 'lock') {
                                    _toggleFolderLock(context, folder);
                                  } else if (val == 'rename') {
                                    _renameFolder(context, folder);
                                  } else if (val == 'delete') {
                                    _deleteFolder(context, folder);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'lock',
                                    child: Row(
                                      children: [
                                        Icon(
                                          folder.isLocked
                                              ? Icons.lock_open_rounded
                                              : Icons.fingerprint_rounded,
                                          size: 20,
                                          color: AppColors.primaryBlue,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          folder.isLocked
                                              ? 'Remove Vault Lock'
                                              : 'Protect as Vault Folder',
                                        ),
                                      ],
                                    ),
                                  ),
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
