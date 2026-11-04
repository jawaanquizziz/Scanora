import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../core/widgets/document_thumbnail_view.dart';
import '../../core/widgets/download_progress_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pdf_document_icon.dart';
import '../../core/widgets/scanora_logo.dart';
import '../../models/scanned_document.dart';
import '../../services/google_drive_service.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';
import '../chat/screens/document_chat_screen.dart';
import 'pdf_viewer_screen.dart';

enum DocumentSort { newest, oldest, nameAsc }

class DocumentsScreen extends StatefulWidget {
  final String? initialFolderId;

  const DocumentsScreen({
    super.key,
    this.initialFolderId,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  DocumentSort _currentSort = DocumentSort.newest;
  bool _isGridView = true;
  String _activeFilter = 'all'; // 'all', 'favorites', or folderId

  @override
  void initState() {
    super.initState();
    if (widget.initialFolderId != null) {
      _activeFilter = widget.initialFolderId!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScannedDocument> _filterAndSort(List<ScannedDocument> docs) {
    var result = List<ScannedDocument>.from(docs);

    if (_activeFilter == 'favorites') {
      result = result.where((d) => d.isFavorite).toList();
    } else if (_activeFilter != 'all') {
      result = result.where((d) => d.folderId == _activeFilter).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((d) => d.title.toLowerCase().contains(query)).toList();
    }

    switch (_currentSort) {
      case DocumentSort.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case DocumentSort.oldest:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case DocumentSort.nameAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return result;
  }

  void _openDocument(ScannedDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(document: doc),
      ),
    );
  }

  void _openDocumentWithDownload(ScannedDocument doc) {
    DownloadProgressDialog.show(
      context: context,
      documentTitle: doc.title,
      onComplete: () {
        _openDocument(doc);
      },
    );
  }

  Future<void> _protectDocument(ScannedDocument doc) async {
    final config = await CustomDialogs.showProtectDocumentSheet(
      context: context,
      document: doc,
    );
    if (config == null || !mounted) return;

    final bool enablePassword = config['enablePassword'] as bool? ?? false;
    final String? newPassword = config['password'] as String?;
    final bool newVaultLock = config['isVaultLocked'] as bool? ?? false;
    final String? newWatermark = config['watermarkText'] as String?;

    try {
      await PdfService().applySecurityOrWatermarkToPdf(
        pdfPath: doc.filePath,
        watermarkText: newWatermark,
        password: enablePassword ? newPassword : null,
        currentPassword: doc.password,
      );

      final updatedFile = File(doc.filePath);
      final newSize = await updatedFile.length();

      final updatedDoc = doc.copyWith(
        isEncrypted: enablePassword && newPassword != null && newPassword.isNotEmpty,
        password: enablePassword ? newPassword : null,
        clearPassword: !enablePassword,
        isVaultLocked: newVaultLock,
        watermarkText: newWatermark ?? doc.watermarkText,
        fileSizeBytes: newSize,
        modifiedAt: DateTime.now(),
      );

      await StorageService().updateDocument(updatedDoc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document security & watermark updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update security: $e')),
        );
      }
    }
  }

  Future<void> _syncDocToDrive(ScannedDocument doc) async {
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
        SnackBar(
          content: Text('Uploading "${doc.title}.pdf" to Google Drive...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final driveId = await drive.uploadDocument(doc);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driveId != null
                ? 'Saved "${doc.title}.pdf" to Google Drive!'
                : (drive.lastError ?? 'Failed to upload to Google Drive'),
          ),
        ),
      );
    }
  }

  Future<void> _renameDocument(ScannedDocument doc) async {
    final newName = await CustomDialogs.showInputDialog(
      context: context,
      title: 'Rename Document',
      initialValue: doc.title,
      hintText: 'Enter document name',
    );

    if (newName != null && newName.isNotEmpty && newName != doc.title) {
      final sanitized = FileUtils.sanitizeFileName(newName);
      await StorageService().renameDocument(doc.id, sanitized);
    }
  }

  Future<void> _moveToFolder(ScannedDocument doc) async {
    final storage = StorageService();
    final selectedFolder = await CustomDialogs.showFolderSelectionSheet(
      context: context,
      folders: storage.folders,
      currentFolderId: doc.folderId,
    );

    if (selectedFolder != null) {
      final targetFolderId = selectedFolder == '__ROOT__' ? null : selectedFolder;
      await storage.moveDocumentToFolder(doc.id, targetFolderId);
    }
  }

  Future<void> _deleteDocument(ScannedDocument doc) async {
    final confirm = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Delete Document?',
      message: 'Are you sure you want to delete "${doc.title}"?',
      confirmLabel: 'Delete',
    );

    if (confirm) {
      await StorageService().deleteDocument(doc.id);
    }
  }

  void _openChatWithDocument(ScannedDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentChatScreen(document: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([StorageService(), GoogleDriveService()]),
      builder: (context, _) {
        final storage = StorageService();
        final filteredDocs = _filterAndSort(storage.documents);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScanoraLogo(size: 24, hasShadow: false),
                SizedBox(width: 8),
                Text('My Scans', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                tooltip: _isGridView ? 'List View' : 'Grid View',
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              ),
              PopupMenuButton<DocumentSort>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort By',
                initialValue: _currentSort,
                onSelected: (sort) {
                  setState(() {
                    _currentSort = sort;
                  });
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: DocumentSort.newest,
                    child: Text('Newest First'),
                  ),
                  PopupMenuItem(
                    value: DocumentSort.oldest,
                    child: Text('Oldest First'),
                  ),
                  PopupMenuItem(
                    value: DocumentSort.nameAsc,
                    child: Text('Name (A-Z)'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All (${storage.documents.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'favorites',
                      'Favourites (${storage.favoriteDocuments.length})',
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber,
                    ),
                    ...storage.folders.map((folder) {
                      final count = storage.getDocumentCountInFolder(folder.id);
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildFilterChip(
                          folder.id,
                          '${folder.name} ($count)',
                          icon: folder.isLocked ? Icons.folder_special_rounded : Icons.folder,
                          iconColor: Color(folder.colorValue),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Documents View
              Expanded(
                child: filteredDocs.isEmpty
                    ? EmptyState(
                        icon: _searchController.text.isNotEmpty
                            ? Icons.search_off_rounded
                            : null,
                        customIcon: _searchController.text.isEmpty
                            ? const ScanoraLogo(size: 60, hasShadow: false)
                            : null,
                        title: _searchController.text.isNotEmpty
                            ? 'No Matching Documents'
                            : 'No Documents Yet',
                        message: _searchController.text.isNotEmpty
                            ? 'Try searching with a different filename.'
                            : 'Scanned files and imported PDFs will appear here.',
                      )
                    : _isGridView
                        ? _buildGridView(filteredDocs, isDark)
                        : _buildListView(filteredDocs, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String id, String label, {IconData? icon, Color? iconColor}) {
    final isSelected = _activeFilter == id;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: 18, color: iconColor) : null,
      onSelected: (_) {
        setState(() {
          _activeFilter = id;
        });
      },
      selectedColor: AppColors.primaryLight,
      checkmarkColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? AppColors.primaryBlue : null,
      ),
    );
  }

  Widget _buildListView(List<ScannedDocument> docs, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: docs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _buildDocumentListCard(doc, isDark);
      },
    );
  }

  Widget _buildGridView(List<ScannedDocument> docs, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _buildDocumentGridCard(doc, isDark);
      },
    );
  }

  Widget _buildDocumentListCard(ScannedDocument doc, bool isDark) {
    final drive = GoogleDriveService();
    final isSyncing = drive.isDocSyncing(doc.id);

    return Card(
      child: InkWell(
        onTap: () => _openDocument(doc),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(
                doc,
                width: 56,
                height: 72,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (doc.isEncrypted || doc.isVaultLocked) ...[
                          const Icon(Icons.lock_rounded, size: 14, color: AppColors.primaryBlue),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormatter.formatDisplay(doc.createdAt)} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          FileUtils.formatFileSize(doc.fileSizeBytes),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (doc.watermarkText != null && doc.watermarkText!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc.watermarkText!,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        if (isSyncing)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        else if (doc.isCloudSynced)
                          const Icon(
                            Icons.cloud_done_rounded,
                            size: 14,
                            color: AppColors.cloudBlue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: doc.isFavorite ? Colors.amber : AppColors.secondaryText,
                  size: 22,
                ),
                onPressed: () => StorageService().toggleFavorite(doc.id),
              ),
              _buildDocMenu(doc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentGridCard(ScannedDocument doc, bool isDark) {
    final drive = GoogleDriveService();
    final isSyncing = drive.isDocSyncing(doc.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openDocument(doc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(
                    doc,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => _syncDocToDrive(doc),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withAlpha(190),
                          shape: BoxShape.circle,
                        ),
                        child: isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.8),
                              )
                            : Icon(
                                doc.isCloudSynced
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_upload_outlined,
                                color: doc.isCloudSynced
                                    ? AppColors.cloudBlue
                                    : AppColors.secondaryText,
                                size: 16,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  const PdfDocumentIcon(size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ),
                  _buildDocMenu(doc, iconSize: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    ScannedDocument doc, {
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return DocumentThumbnailView(
      doc: doc,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      showBadge: true,
    );
  }

  Widget _buildDocMenu(ScannedDocument doc, {double iconSize = 22}) {
    return PopupMenuButton<String>(
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
      onSelected: (val) {
        switch (val) {
          case 'ask_ai':
            _openChatWithDocument(doc);
            break;
          case 'security':
            _protectDocument(doc);
            break;
          case 'drive':
            _syncDocToDrive(doc);
            break;
          case 'download':
            _openDocumentWithDownload(doc);
            break;
          case 'open':
            _openDocument(doc);
            break;
          case 'share':
            SharePlus.instance.share(
              ShareParams(files: [XFile(doc.filePath)], text: doc.title),
            );
            break;
          case 'rename':
            _renameDocument(doc);
            break;
          case 'move':
            _moveToFolder(doc);
            break;
          case 'delete':
            _deleteDocument(doc);
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'ask_ai',
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
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
          value: 'drive',
          child: Row(
            children: [
              Icon(
                doc.isCloudSynced ? Icons.cloud_done_rounded : Icons.add_to_drive_rounded,
                size: 20,
                color: AppColors.cloudBlue,
              ),
              const SizedBox(width: 12),
              Text(doc.isCloudSynced ? 'Update on Google Drive' : 'Save to Google Drive'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 20, color: AppColors.lensOrange),
              SizedBox(width: 12),
              Text('Download / Export'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 20),
              SizedBox(width: 12),
              Text('Open'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 20),
              SizedBox(width: 12),
              Text('Share'),
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
    );
  }
}
