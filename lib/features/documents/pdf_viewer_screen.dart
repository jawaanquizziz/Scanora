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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondaryText),
              ],
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
              scrollViewDecoration: const BoxDecoration(
                color: Color(0xFF1E2026),
              ),
            ),
    );
  }
}
