import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../models/scanned_document.dart';
import '../../services/biometric_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';
import '../chat/screens/document_chat_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final ScannedDocument document;

  const PdfViewerScreen({
    super.key,
    required this.document,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late ScannedDocument _doc;
  bool _isVaultUnlocked = false;
  bool _isPasswordUnlocked = false;
  Uint8List? _decryptedBytes;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _passwordError;
  bool _isUpdatingSecurity = false;

  @override
  void initState() {
    super.initState();
    _doc = StorageService().getDocument(widget.document.id) ?? widget.document;
    _initSecurityCheck();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initSecurityCheck() async {
    if (_doc.isVaultLocked) {
      final authenticated = await BiometricService().authenticate(
        reason: 'Authenticate to unlock vault document "${_doc.title}"',
      );
      if (mounted) {
        setState(() {
          _isVaultUnlocked = authenticated;
        });
      }
    } else {
      _isVaultUnlocked = true;
    }

    if (!_doc.isEncrypted) {
      if (mounted) {
        setState(() {
          _isPasswordUnlocked = true;
        });
      }
    }
  }

  Future<void> _unlockWithPassword() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      setState(() {
        _passwordError = 'Please enter the document password';
      });
      return;
    }

    final file = File(_doc.filePath);
    if (!await file.exists()) {
      setState(() {
        _passwordError = 'PDF file not found on device';
      });
      return;
    }

    final unlockedBytes = await PdfService().unlockPdf(
      filePath: _doc.filePath,
      enteredPassword: pwd,
      expectedPassword: _doc.password,
    );

    if (unlockedBytes != null) {
      if (_doc.password == null || _doc.password!.isEmpty) {
        final updated = _doc.copyWith(password: pwd);
        await StorageService().updateDocument(updated);
        _doc = updated;
      }

      if (mounted) {
        setState(() {
          _decryptedBytes = unlockedBytes;
          _isPasswordUnlocked = true;
          _passwordError = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _passwordError = 'Incorrect password. Please try again.';
        });
      }
    }
  }

  Future<void> _openSecurityAndWatermarkSheet() async {
    final config = await CustomDialogs.showProtectDocumentSheet(
      context: context,
      document: _doc,
    );

    if (config == null || !mounted) return;

    final bool enablePassword = config['enablePassword'] as bool? ?? false;
    final String? newPassword = config['password'] as String?;
    final bool newVaultLock = config['isVaultLocked'] as bool? ?? false;
    final String? newWatermark = config['watermarkText'] as String?;

    setState(() {
      _isUpdatingSecurity = true;
    });

    try {
      await PdfService().applySecurityOrWatermarkToPdf(
        pdfPath: _doc.filePath,
        watermarkText: newWatermark,
        password: enablePassword ? newPassword : null,
        currentPassword: _doc.password,
      );

      final updatedFile = File(_doc.filePath);
      final newSize = await updatedFile.length();

      Uint8List? updatedPreviewBytes;
      if (enablePassword && newPassword != null && newPassword.isNotEmpty) {
        updatedPreviewBytes = await PdfService().unlockPdf(
          filePath: _doc.filePath,
          enteredPassword: newPassword,
          expectedPassword: newPassword,
        );
      }

      final updatedDoc = _doc.copyWith(
        isEncrypted: enablePassword && newPassword != null && newPassword.isNotEmpty,
        password: enablePassword ? newPassword : null,
        clearPassword: !enablePassword,
        isVaultLocked: newVaultLock,
        watermarkText: newWatermark ?? _doc.watermarkText,
        fileSizeBytes: newSize,
        modifiedAt: DateTime.now(),
      );

      await StorageService().updateDocument(updatedDoc);

      if (mounted) {
        setState(() {
          _doc = updatedDoc;
          _decryptedBytes = updatedPreviewBytes;
          _isPasswordUnlocked = true;
          _isVaultUnlocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document security & watermark updated!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update security: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingSecurity = false;
        });
      }
    }
  }

  Future<void> _syncToGoogleDrive() async {
    final drive = GoogleDriveService();
    if (!drive.isSignedIn) {
      final signedIn = await drive.signIn();
      if (!signedIn) {
        if (mounted && drive.lastError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(drive.lastError!)),
          );
        }
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading PDF to Google Drive ("Scanora Documents")...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final driveId = await drive.uploadDocument(_doc);
    final refreshed = StorageService().getDocument(_doc.id);
    if (refreshed != null && mounted) {
      setState(() {
        _doc = refreshed;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driveId != null
                ? 'Backed up "${_doc.title}.pdf" to Google Drive!'
                : (drive.lastError ?? 'Failed to upload to Google Drive'),
          ),
        ),
      );
    }
  }

  Future<void> _shareDocument() async {
    final file = File(_doc.filePath);
    if (await file.exists()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(_doc.filePath)], text: _doc.title),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not exist')),
        );
      }
    }
  }

  Future<void> _printDocument() async {
    final file = File(_doc.filePath);
    if (await file.exists()) {
      await Printing.layoutPdf(
        onLayout: (format) async => _decryptedBytes ?? await file.readAsBytes(),
        name: '${_doc.title}.pdf',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not exist')),
        );
      }
    }
  }

  Future<void> _renameDocument() async {
    final newName = await CustomDialogs.showInputDialog(
      context: context,
      title: 'Rename Document',
      initialValue: _doc.title,
      hintText: 'Enter document name',
    );

    if (newName != null && newName.trim().isNotEmpty && newName.trim() != _doc.title) {
      final sanitized = FileUtils.sanitizeFileName(newName.trim());
      await StorageService().renameDocument(_doc.id, sanitized);
      final refreshed = StorageService().getDocument(_doc.id);
      if (mounted) {
        setState(() {
          _doc = refreshed ?? _doc.copyWith(title: sanitized, modifiedAt: DateTime.now());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document renamed to "$sanitized"')),
        );
      }
    }
  }

  Future<void> _moveToFolder() async {
    final storage = StorageService();
    final selectedFolder = await CustomDialogs.showFolderSelectionSheet(
      context: context,
      folders: storage.folders,
      currentFolderId: _doc.folderId,
    );

    if (selectedFolder != null) {
      final targetFolderId = selectedFolder == '__ROOT__' ? null : selectedFolder;
      await storage.moveDocumentToFolder(_doc.id, targetFolderId);
      final refreshed = storage.getDocument(_doc.id);
      setState(() {
        _doc = refreshed ??
            _doc.copyWith(
              folderId: targetFolderId,
              clearFolder: targetFolderId == null,
            );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moved successfully')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    await StorageService().toggleFavorite(_doc.id);
    setState(() {
      _doc = _doc.copyWith(isFavorite: !_doc.isFavorite);
    });
  }

  Future<void> _toggleVaultLock() async {
    final authenticated = await BiometricService().authenticate(
      reason: _doc.isVaultLocked
          ? 'Authenticate to remove Vault protection'
          : 'Authenticate to lock document in Biometric Vault',
    );
    if (!authenticated) return;

    await StorageService().toggleDocumentVaultLock(_doc.id);
    if (mounted) {
      setState(() {
        _doc = _doc.copyWith(isVaultLocked: !_doc.isVaultLocked);
        _isVaultUnlocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _doc.isVaultLocked
                ? 'Document protected with Biometric Vault Lock'
                : 'Biometric Vault Lock removed',
          ),
        ),
      );
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Delete Document?',
      message: 'Are you sure you want to delete "${_doc.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirm && mounted) {
      await StorageService().deleteDocument(_doc.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showDocumentDetails() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Title', '${_doc.title}.pdf'),
              _buildDetailRow('Pages', '${_doc.pageCount}'),
              _buildDetailRow('Size', FileUtils.formatFileSize(_doc.fileSizeBytes)),
              _buildDetailRow(
                'Security',
                _doc.isEncrypted ? 'Password Protected (AES)' : 'Standard (Unencrypted)',
              ),
              _buildDetailRow(
                'Vault Lock',
                _doc.isVaultLocked ? 'Biometric Protected' : 'Off',
              ),
              if (_doc.watermarkText != null && _doc.watermarkText!.isNotEmpty)
                _buildDetailRow('Watermark', _doc.watermarkText!),
              _buildDetailRow(
                'Google Drive',
                _doc.isCloudSynced
                    ? 'Synced (${_doc.syncedAt != null ? DateFormatter.formatDisplay(_doc.syncedAt!) : 'Backed up'})'
                    : 'Local Only (Not synced)',
              ),
              _buildDetailRow('Created', DateFormatter.formatDisplay(_doc.createdAt)),
              _buildDetailRow('Modified', DateFormatter.formatDisplay(_doc.modifiedAt)),
              _buildDetailRow('Path', _doc.filePath),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(_doc.filePath);
    final fileExists = file.existsSync();
    final isLocked = !_isVaultUnlocked || !_isPasswordUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: isLocked ? null : _renameDocument,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_doc.isEncrypted || _doc.isVaultLocked) ...[
                  const Icon(Icons.lock_rounded, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    _doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: GoogleDriveService(),
            builder: (context, _) {
              final drive = GoogleDriveService();
              final isSyncing = drive.isDocSyncing(_doc.id);
              return IconButton(
                icon: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _doc.isCloudSynced
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_upload_outlined,
                        color: _doc.isCloudSynced ? AppColors.cloudBlue : null,
                      ),
                tooltip: _doc.isCloudSynced ? 'Synced to Google Drive' : 'Save to Google Drive',
                onPressed: isSyncing ? null : _syncToGoogleDrive,
              );
            },
          ),
          IconButton(
            icon: Icon(
              _doc.isEncrypted || _doc.isVaultLocked
                  ? Icons.security_rounded
                  : Icons.lock_open_rounded,
              color: (_doc.isEncrypted || _doc.isVaultLocked) ? AppColors.primaryBlue : null,
            ),
            tooltip: 'Security & Watermark',
            onPressed: isLocked ? null : _openSecurityAndWatermarkSheet,
          ),
          IconButton(
            icon: Icon(
              _doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _doc.isFavorite ? Colors.amber : null,
            ),
            tooltip: 'Favorite',
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              switch (val) {
                case 'ask_ai':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentChatScreen(document: _doc),
                    ),
                  );
                  break;
                case 'security':
                  _openSecurityAndWatermarkSheet();
                  break;
                case 'vault':
                  _toggleVaultLock();
                  break;
                case 'drive':
                  _syncToGoogleDrive();
                  break;
                case 'rename':
                  _renameDocument();
                  break;
                case 'move':
                  _moveToFolder();
                  break;
                case 'details':
                  _showDocumentDetails();
                  break;
                case 'delete':
                  _deleteDocument();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'ask_ai',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Ask AI',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'security',
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, size: 20, color: AppColors.primaryBlue),
                    SizedBox(width: 12),
                    Text('Lock PDF / Watermark'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'vault',
                child: Row(
                  children: [
                    Icon(
                      _doc.isVaultLocked ? Icons.lock_open_rounded : Icons.fingerprint_rounded,
                      size: 20,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Text(_doc.isVaultLocked ? 'Remove Vault Lock' : 'Lock in Biometric Vault'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'drive',
                child: Row(
                  children: [
                    Icon(
                      _doc.isCloudSynced ? Icons.cloud_done_rounded : Icons.add_to_drive_rounded,
                      size: 20,
                      color: AppColors.cloudBlue,
                    ),
                    const SizedBox(width: 12),
                    Text(_doc.isCloudSynced ? 'Update on Google Drive' : 'Save to Google Drive'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Move to Folder'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Details'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: !fileExists
          ? const Center(
              child: Text(
                'PDF file not found on device.',
                style: TextStyle(color: AppColors.error),
              ),
            )
          : _isUpdatingSecurity
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Applying PDF security & watermark...'),
                    ],
                  ),
                )
              : !_isVaultUnlocked
                  ? _buildVaultLockedView()
                  : !_isPasswordUnlocked
                      ? _buildPasswordPromptView()
                      : PdfPreview(
                          build: (format) async =>
                              _decryptedBytes ?? await file.readAsBytes(),
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          canDebug: false,
                          dynamicLayout: false,
                          useActions: false,
                          scrollViewDecoration: const BoxDecoration(
                            color: Color(0xFF1E2026),
                          ),
                        ),
      bottomNavigationBar: (fileExists && !isLocked) ? _buildBottomBar() : null,
      floatingActionButton: isLocked
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF388BFF), Color(0xFF176BFF), Color(0xFF0A47B8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF176BFF).withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentChatScreen(document: _doc),
                        ),
                      );
                    },
                    child: const Tooltip(
                      message: 'Ask AI',
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildVaultLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 44,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Biometric Vault Protected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This document is locked inside your private Scanora Vault. Authenticate with fingerprint, face, or device PIN to view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initSecurityCheck,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Authenticate to Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPromptView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 40,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Password Protected PDF',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the document password to decrypt and view this PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              onSubmitted: (_) => _unlockWithPassword(),
              decoration: InputDecoration(
                labelText: 'Document Password',
                errorText: _passwordError,
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _unlockWithPassword,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBarActionButton(
                icon: Icons.print_rounded,
                label: 'Print',
                onTap: _printDocument,
              ),
              Container(
                height: 24,
                width: 1,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              _buildBarActionButton(
                icon: Icons.security_rounded,
                label: 'Protect',
                onTap: _openSecurityAndWatermarkSheet,
              ),
              Container(
                height: 24,
                width: 1,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              _buildBarActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _shareDocument,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
