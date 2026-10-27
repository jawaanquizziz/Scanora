import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../models/document_folder.dart';

class CustomDialogs {
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool isDestructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    String hintText = 'Enter name',
    String confirmLabel = 'Save',
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop(text);
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result;
  }

  static Future<String?> showPdfNamingDialog({
    required BuildContext context,
    required String defaultName,
    int pageCount = 1,
  }) async {
    final controller = TextEditingController(text: defaultName);

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lensOrangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.lensOrange, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Name Your PDF',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a name for your $pageCount ${pageCount == 1 ? 'page' : 'pages'} document before generating the PDF:',
                style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'Enter name',
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.lensOrange),
                  suffixText: '.pdf',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (val) {
                  final text = val.trim();
                  Navigator.of(ctx).pop(text.isNotEmpty ? text : defaultName);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final text = controller.text.trim();
                  Navigator.of(ctx).pop(text.isNotEmpty ? text : defaultName);
                },
              ),
            ),
          ],
        );
      },
    );
    return result;
  }

  static Future<Map<String, dynamic>?> showCreateFolderDialog({
    required BuildContext context,
  }) async {
    final controller = TextEditingController();
    int selectedColor = AppColors.folderColors[0].toARGB32();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Folder name (e.g., Receipts, Work)',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Folder Color',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: AppColors.folderColors.map((color) {
                  final isSelected = selectedColor == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = color.toARGB32();
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withAlpha(120),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop({
                    'name': text,
                    'color': selectedColor,
                  });
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  static Future<String?> showFolderSelectionSheet({
    required BuildContext context,
    required List<DocumentFolder> folders,
    String? currentFolderId,
  }) async {
    return showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Move to Folder',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('No Folder (Root)'),
                trailing: currentFolderId == null
                    ? const Icon(Icons.check, color: AppColors.primaryBlue)
                    : null,
                onTap: () => Navigator.of(ctx).pop('__ROOT__'),
              ),
              if (folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No custom folders created yet.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                )
              else
                ...folders.map(
                  (folder) => ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: Color(folder.colorValue),
                    ),
                    title: Text(folder.name),
                    trailing: currentFolderId == folder.id
                        ? const Icon(Icons.check, color: AppColors.primaryBlue)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(folder.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
