import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../models/scan_page.dart';
import '../../models/scanned_document.dart';
import '../../services/google_drive_service.dart';
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
    final driveService = GoogleDriveService();
    final defaultWatermark = storage.settings.defaultWatermark.isNotEmpty
        ? storage.settings.defaultWatermark
        : 'CONFIDENTIAL';

    final watermarkController = TextEditingController(text: defaultWatermark);
    final passwordController = TextEditingController();

    String? selectedFolderId;
    String selectedPageSize = storage.settings.defaultPageSize;
    bool enableWatermark = false;
    String selectedWatermarkPreset =
        ['CONFIDENTIAL', 'FOR KYC ONLY', 'DO NOT COPY', 'DRAFT'].contains(defaultWatermark)
            ? defaultWatermark
            : 'CONFIDENTIAL';
    bool enablePassword = false;
    bool obscurePassword = true;
    bool syncToDrive = driveService.isSignedIn && storage.settings.autoSyncToDrive;
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
            child: SingleChildScrollView(
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
                        onPressed: () {
                          FocusScope.of(ctx).unfocus();
                          Navigator.of(ctx).pop(null);
                        },
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
                                  Icon(
                                    folder.isLocked ? Icons.folder_special_rounded : Icons.folder,
                                    size: 20,
                                    color: Color(folder.colorValue),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(folder.name),
                                  if (folder.isLocked) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '(Vault)',
                                      style: TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                                    ),
                                  ],
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
                  const SizedBox(height: 18),

                  // Security & Privacy Controls
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B222E) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security_rounded, size: 18, color: AppColors.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Security, Watermark & Cloud',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Anti-Fraud Watermark Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Anti-Fraud Watermark',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  'Stamp diagonal anti-misuse text',
                                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: enableWatermark,
                              onChanged: (val) {
                                setState(() {
                                  enableWatermark = val;
                                });
                              },
                            ),
                          ],
                        ),
                        if (enableWatermark) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: ['CONFIDENTIAL', 'FOR KYC ONLY', 'DO NOT COPY', 'DRAFT', 'Custom']
                                .map((preset) {
                              final isSelected = selectedWatermarkPreset == preset;
                              return ChoiceChip(
                                label: Text(preset, style: const TextStyle(fontSize: 11)),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      selectedWatermarkPreset = preset;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          if (selectedWatermarkPreset == 'Custom') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: watermarkController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Enter custom watermark (e.g. FOR BANK USE)',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ],

                        const Divider(height: 20),

                        // Password Encryption Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lock with Password',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  'Standard AES PDF password protection',
                                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: enablePassword,
                              onChanged: (val) {
                                setState(() {
                                  enablePassword = val;
                                });
                              },
                            ),
                          ],
                        ),
                        if (enablePassword) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Enter document password',
                              isDense: true,
                              prefixIcon: const Icon(Icons.lock_outline, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],

                        if (driveService.isSignedIn) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.add_to_drive_rounded, size: 18, color: AppColors.primaryBlue),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Backup to Google Drive',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        'Save to "Scanora Documents" folder',
                                        style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: syncToDrive,
                                onChanged: (val) => setState(() => syncToDrive = val),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                              if (enablePassword && passwordController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a password or disable lock'),
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                isGenerating = true;
                              });

                              try {
                                final sanitizedTitle = FileUtils.sanitizeFileName(
                                  titleController.text.trim(),
                                );

                                final imagePaths = pages.map((p) => p.processedImagePath).toList();

                                final watermarkText = enableWatermark
                                    ? (selectedWatermarkPreset == 'Custom'
                                        ? watermarkController.text.trim()
                                        : selectedWatermarkPreset)
                                    : null;

                                final password = enablePassword && passwordController.text.trim().isNotEmpty
                                    ? passwordController.text.trim()
                                    : null;

                                // 1. Generate PDF with security parameters
                                final pdfFile = await PdfService().generatePdf(
                                  imagePaths: imagePaths,
                                  title: sanitizedTitle,
                                  pageFormat: selectedPageSize,
                                  watermarkText: watermarkText,
                                  password: password,
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

                                // Check if destination folder is a locked vault folder
                                bool isVaultDoc = false;
                                if (selectedFolderId != null) {
                                  final folder = storage.folders
                                      .where((f) => f.id == selectedFolderId)
                                      .firstOrNull;
                                  if (folder != null && folder.isLocked) {
                                    isVaultDoc = true;
                                  }
                                }

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
                                  isEncrypted: password != null && password.isNotEmpty,
                                  password: password,
                                  watermarkText: watermarkText,
                                  isVaultLocked: isVaultDoc,
                                );

                                // 4. Save metadata
                                await storage.addDocument(doc);

                                // 5. Auto-Sync to Google Drive if enabled
                                if (syncToDrive && driveService.isSignedIn) {
                                  driveService.uploadDocument(doc);
                                }

                                if (!ctx.mounted) return;
                                FocusScope.of(ctx).unfocus();
                                Navigator.of(ctx).pop(doc);
                              } catch (e) {
                                if (ctx.mounted) {
                                  setState(() {
                                    isGenerating = false;
                                  });
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
    VoidCallback? onDone,
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
              if (document.isEncrypted || document.watermarkText != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (document.isEncrypted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryBlue.withAlpha(60)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 14, color: AppColors.primaryBlue),
                            SizedBox(width: 4),
                            Text(
                              'Password Protected',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (document.watermarkText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_outlined, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              'Watermarked: ${document.watermarkText}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
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
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onDone?.call();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
