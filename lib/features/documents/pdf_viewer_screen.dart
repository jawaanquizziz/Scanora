import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../models/scanned_document.dart';
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

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
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
        onLayout: (format) => file.readAsBytes(),
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
      if (mounted) {
        setState(() {
          _doc = _doc.copyWith(title: sanitized, modifiedAt: DateTime.now());
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
      setState(() {
        _doc = _doc.copyWith(
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
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

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _renameDocument,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              _doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: _renameDocument,
          ),
          IconButton(
            icon: Icon(
              _doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _doc.isFavorite ? Colors.amber : null,
            ),
            tooltip: 'Favorite',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareDocument,
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
          : PdfPreview(
              build: (format) => file.readAsBytes(),
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              dynamicLayout: false,
              useActions: false,
              scrollViewDecoration: const BoxDecoration(
                color: Color(0xFF1E2026),
              ),
            ),
      bottomNavigationBar: fileExists ? _buildBottomBar() : null,
      floatingActionButton: Padding(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
