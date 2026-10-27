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

    // 1. Filter by category/folder
    if (_activeFilter == 'favorites') {
      result = result.where((d) => d.isFavorite).toList();
    } else if (_activeFilter != 'all') {
      result = result.where((d) => d.folderId == _activeFilter).toList();
    }

    // 2. Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((d) => d.title.toLowerCase().contains(query)).toList();
    }

    // 3. Sort
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
      listenable: StorageService(),
      builder: (context, _) {
        final storage = StorageService();
        final filteredDocs = _filterAndSort(storage.documents);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ScanoraLogo(size: 24, hasShadow: false),
                const SizedBox(width: 8),
                const Text('My Scans', style: TextStyle(fontWeight: FontWeight.w700)),
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
                          icon: Icons.folder,
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
    return Card(
      child: InkWell(
        onTap: () => _openDocument(doc),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              _buildThumbnail(
                doc,
                width: 56,
                height: 72,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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
                    Text(
                      FileUtils.formatFileSize(doc.fileSizeBytes),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // Favorite Star & Menu
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
        onTap: () => _openDocumentWithDownload(doc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Thumbnail area
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
                  // Cloud status icon in top-right corner matching Image 2
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.cloud_done_rounded,
                      color: AppColors.cloudBlue,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom title & info
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
