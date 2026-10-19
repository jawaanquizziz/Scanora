import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../models/scan_page.dart';
import '../../models/scanned_document.dart';
import '../../services/image_service.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';

class SaveDialog {
  static Future<ScannedDocument?> show({
    required BuildContext context,
    required List<ScanPage> pages,
  }) async {
    final titleController = TextEditingController(
      text: DateFormatter.generateDefaultDocName(),
    );

    final storage = StorageService();
    String? selectedFolderId;
    String selectedPageSize = storage.settings.defaultPageSize;
    bool isGenerating = false;

    final result = await showModalBottomSheet<ScannedDocument?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Save Document',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title Input
                const Text(
                  'Document Name',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.description_outlined, color: AppColors.primaryBlue),
                    hintText: 'Enter document name',
                  ),
                ),
                const SizedBox(height: 16),

                // Folder Selection
                const Text(
                  'Destination Folder',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: selectedFolderId,
                      hint: const Text('Root (No Folder)'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.folder_off_outlined, size: 20, color: AppColors.secondaryText),
                              SizedBox(width: 10),
                              Text('No Folder (Root)'),
                            ],
                          ),
                        ),
                        ...storage.folders.map(
                          (folder) => DropdownMenuItem<String?>(
                            value: folder.id,
                            child: Row(
                              children: [
                                Icon(Icons.folder, size: 20, color: Color(folder.colorValue)),
                                SizedBox(width: 10),
                                Text(folder.name),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          selectedFolderId = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Page Format Selector
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Page Size',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'A4', label: Text('A4')),
                              ButtonSegment(value: 'Letter', label: Text('Letter')),
                            ],
                            selected: {selectedPageSize},
                            onSelectionChanged: (set) {
                              setState(() {
                                selectedPageSize = set.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isGenerating
                        ? null
                        : () async {
                            setState(() {
                              isGenerating = true;
                            });

                            try {
                              final sanitizedTitle = FileUtils.sanitizeFileName(
                                titleController.text.trim(),
                              );

                              final imagePaths = pages.map((p) => p.processedImagePath).toList();

                              // 1. Generate PDF
                              final pdfFile = await PdfService().generatePdf(
                                imagePaths: imagePaths,
                                title: sanitizedTitle,
                                pageFormat: selectedPageSize,
                              );

                              final fileSize = await pdfFile.length();
                              final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';

                              // 2. Generate Thumbnail from first page
                              String? thumbPath;
                              try {
                                thumbPath = await ImageService().createThumbnail(
                                  pages.first.processedImagePath,
                                  docId,
                                );
                              } catch (_) {}

                              // 3. Create ScannedDocument
                              final doc = ScannedDocument(
                                id: docId,
                                title: sanitizedTitle,
                                filePath: pdfFile.path,
                                thumbnailPath: thumbPath,
                                createdAt: DateTime.now(),
                                modifiedAt: DateTime.now(),
                                pageCount: pages.length,
                                fileSizeBytes: fileSize,
                                folderId: selectedFolderId,
                              );

                              // 4. Save metadata
                              await storage.addDocument(doc);

                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop(doc);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Save error: $e')),
                                );
                              }
                            }
                          },
                    child: isGenerating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save as PDF',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return result;
  }

  static void showSuccessSheet({
    required BuildContext context,
    required ScannedDocument document,
    required VoidCallback onOpenPdf,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PDF Saved Successfully!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${document.title}.pdf (${document.pageCount} ${document.pageCount == 1 ? 'page' : 'pages'})',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        SharePlus.instance.share(
                          ShareParams(files: [XFile(document.filePath)], text: document.title),
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onOpenPdf();
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      label: const Text('Open PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
