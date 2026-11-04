import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../models/document_folder.dart';
import '../../models/scanned_document.dart';
import '../../services/google_drive_service.dart';
import '../../services/storage_service.dart';

class PdfSaveConfig {
  final String title;
  final String? watermarkText;
  final String? password;
  final bool syncToDrive;

  const PdfSaveConfig({
    required this.title,
    this.watermarkText,
    this.password,
    this.syncToDrive = true,
  });
}

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
          decoration: InputDecoration(
            hintText: hintText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.of(ctx).pop(null);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                FocusScope.of(ctx).unfocus();
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

  /// Enhanced PDF Naming + Security/Watermark/Cloud Save Dialog for ML Kit Scanner
  static Future<PdfSaveConfig?> showPdfSaveConfigDialog({
    required BuildContext context,
    required String defaultName,
    int pageCount = 1,
  }) async {
    final titleController = TextEditingController(text: defaultName);
    final storage = StorageService();
    final driveService = GoogleDriveService();
    final defaultWatermark = storage.settings.defaultWatermark.isNotEmpty
        ? storage.settings.defaultWatermark
        : 'CONFIDENTIAL';

    final watermarkController = TextEditingController(text: defaultWatermark);
    final passwordController = TextEditingController();

    bool enableWatermark = false;
    String selectedPreset = ['CONFIDENTIAL', 'FOR KYC ONLY', 'DO NOT COPY', 'DRAFT']
            .contains(defaultWatermark.toUpperCase())
        ? defaultWatermark.toUpperCase()
        : 'CONFIDENTIAL';
    bool enablePassword = false;
    bool obscurePassword = true;
    bool syncToDrive = driveService.isSignedIn && storage.settings.autoSyncToDrive;

    return showDialog<PdfSaveConfig?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lensOrangeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.lensOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Save Scanned PDF',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$pageCount ${pageCount == 1 ? 'page' : 'pages'} ready to save',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Document Name',
                        hintText: 'Enter name',
                        prefixIcon: const Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.lensOrange,
                        ),
                        suffixText: '.pdf',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Security & Watermark Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B222E) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryBlue),
                              SizedBox(width: 6),
                              Text(
                                'Security & Protection',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Watermark Switch
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Anti-Fraud Watermark',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      'Diagonal protective text stamp',
                                      style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: enableWatermark,
                                onChanged: (val) => setState(() => enableWatermark = val),
                              ),
                            ],
                          ),
                          if (enableWatermark) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: ['CONFIDENTIAL', 'FOR KYC ONLY', 'DO NOT COPY', 'DRAFT', 'Custom']
                                  .map((preset) {
                                final isSelected = selectedPreset == preset;
                                return ChoiceChip(
                                  label: Text(preset, style: const TextStyle(fontSize: 10.5)),
                                  selected: isSelected,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(() => selectedPreset = preset);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            if (selectedPreset == 'Custom') ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: watermarkController,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Custom text (e.g. FOR BANK USE)',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                ),
                              ),
                            ],
                          ],

                          const Divider(height: 16),

                          // Password Switch
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lock PDF with Password',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      'Encrypts PDF against unauthorized opening',
                                      style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: enablePassword,
                                onChanged: (val) => setState(() => enablePassword = val),
                              ),
                            ],
                          ),
                          if (enablePassword) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter PDF password',
                                isDense: true,
                                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => obscurePassword = !obscurePassword),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              ),
                            ),
                          ],

                          if (driveService.isSignedIn) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_to_drive_rounded,
                                          size: 18, color: AppColors.primaryBlue),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Backup to Google Drive',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(ctx).unfocus();
                    Navigator.of(ctx).pop(null);
                  },
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
                      if (enablePassword && passwordController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a password or turn off Lock PDF'),
                          ),
                        );
                        return;
                      }

                      final text = titleController.text.trim();
                      final finalTitle = text.isNotEmpty ? text : defaultName;
                      final wm = enableWatermark
                          ? (selectedPreset == 'Custom'
                              ? watermarkController.text.trim()
                              : selectedPreset)
                          : null;
                      final pwd = enablePassword && passwordController.text.trim().isNotEmpty
                          ? passwordController.text.trim()
                          : null;

                      FocusScope.of(ctx).unfocus();
                      Navigator.of(ctx).pop(
                        PdfSaveConfig(
                          title: finalTitle,
                          watermarkText: (wm != null && wm.isNotEmpty) ? wm : null,
                          password: pwd,
                          syncToDrive: syncToDrive,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog to add/edit password protection or watermark on any existing PDF document
  static Future<Map<String, dynamic>?> showProtectDocumentSheet({
    required BuildContext context,
    required ScannedDocument document,
  }) async {
    bool enablePassword = document.isEncrypted;
    final passwordController = TextEditingController(text: document.password ?? '');
    bool obscurePassword = true;

    bool enableWatermark = false;
    String selectedPreset = 'CONFIDENTIAL';
    final watermarkController = TextEditingController(
      text: document.watermarkText ?? StorageService().settings.defaultWatermark,
    );

    bool isVaultLocked = document.isVaultLocked;

    return showModalBottomSheet<Map<String, dynamic>?>(
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
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Security & Watermark',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              document.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
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

                  // 1. Password Lock
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B222E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Password Lock (PDF Encryption)',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Require a password to view or share this PDF',
                                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: enablePassword,
                              onChanged: (val) => setState(() => enablePassword = val),
                            ),
                          ],
                        ),
                        if (enablePassword) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'PDF Password',
                              hintText: 'Enter password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Biometric Vault Lock
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B222E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Vault Guard',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Require fingerprint / face / PIN to open in Scanora',
                                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isVaultLocked,
                          onChanged: (val) => setState(() => isVaultLocked = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Anti-Fraud Watermark Stamp
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B222E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stamp Diagonal Watermark',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    document.watermarkText != null
                                        ? 'Current watermark: "${document.watermarkText}"'
                                        : 'Overlay anti-fraud text across all pages',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: enableWatermark,
                              onChanged: (val) => setState(() => enableWatermark = val),
                            ),
                          ],
                        ),
                        if (enableWatermark) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              'CONFIDENTIAL',
                              'FOR KYC ONLY',
                              'DO NOT COPY',
                              'DRAFT',
                              'Custom'
                            ].map((preset) {
                              final isSelected = selectedPreset == preset;
                              return ChoiceChip(
                                label: Text(preset, style: const TextStyle(fontSize: 11)),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => selectedPreset = preset);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          if (selectedPreset == 'Custom') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: watermarkController,
                              decoration: const InputDecoration(
                                hintText: 'Enter custom watermark text',
                                isDense: true,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified_user_rounded, size: 20),
                      label: const Text(
                        'Apply Security Settings',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      onPressed: () {
                        if (enablePassword && passwordController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a password or turn off Password Lock'),
                            ),
                          );
                          return;
                        }
                        final wm = enableWatermark
                            ? (selectedPreset == 'Custom'
                                ? watermarkController.text.trim()
                                : selectedPreset)
                            : null;

                        FocusScope.of(ctx).unfocus();
                        Navigator.of(ctx).pop({
                          'enablePassword': enablePassword,
                          'password': enablePassword ? passwordController.text.trim() : null,
                          'isVaultLocked': isVaultLocked,
                          'watermarkText': (wm != null && wm.isNotEmpty) ? wm : null,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<Map<String, dynamic>?> showCreateFolderDialog({
    required BuildContext context,
  }) async {
    final controller = TextEditingController();
    int selectedColor = AppColors.folderColors[0].toARGB32();
    bool isVaultLocked = false;

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
                decoration: const InputDecoration(
                  hintText: 'Folder name (e.g., Receipts, Vault, Work)',
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
              const SizedBox(height: 16),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Biometric Vault Folder',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Require fingerprint/PIN to open folder',
                  style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                ),
                value: isVaultLocked,
                onChanged: (val) {
                  setState(() {
                    isVaultLocked = val;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(ctx).unfocus();
                Navigator.of(ctx).pop(null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  FocusScope.of(ctx).unfocus();
                  Navigator.of(ctx).pop({
                    'name': text,
                    'color': selectedColor,
                    'isLocked': isVaultLocked,
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
                      folder.isLocked ? Icons.folder_special_rounded : Icons.folder,
                      color: Color(folder.colorValue),
                    ),
                    title: Row(
                      children: [
                        Text(folder.name),
                        if (folder.isLocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_rounded, size: 14, color: AppColors.primaryBlue),
                        ],
                      ],
                    ),
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
