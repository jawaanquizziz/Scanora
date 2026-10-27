import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../core/widgets/document_thumbnail_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/scanora_logo.dart';
import '../../models/scanned_document.dart';
import '../../services/storage_service.dart';
import '../chat/screens/document_chat_screen.dart';
import '../documents/pdf_viewer_screen.dart';
import '../scanner/capture_service.dart';
import '../scanner/mlkit_scanner_service.dart';
import '../scanner/page_review_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToDocuments;
  final VoidCallback? onNavigateToFolders;

  const HomeScreen({
    super.key,
    required this.onNavigateToDocuments,
    this.onNavigateToFolders,
  });

  Future<void> _startCameraScan(BuildContext context) async {
    final doc = await MlKitScannerService.startScan(context: context);
    if (doc != null && context.mounted) {
      // Immediately display in Scanora's unified Scans screen
      onNavigateToDocuments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          backgroundColor: const Color(0xFF1E222D),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lensOrange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.lensOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Document "${doc.title}" saved to library!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Open',
            textColor: AppColors.lensOrange,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(document: doc),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _startGalleryImport(BuildContext context) async {
    final pages = await CaptureService.importFromGallery(context);
    if (pages.isNotEmpty && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PageReviewScreen(initialPages: pages),
        ),
      );
    }
  }

  void _openDocument(BuildContext context, ScannedDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(document: doc),
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
        final allDocs = storage.documents;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            title: const ScanoraBrand(
              logoSize: 30,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await storage.init();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // Primary Quick Actions (Orange Scan Document & Import Images)
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildPrimaryActionCard(
                        context: context,
                        title: 'Scan Document',
                        subtitle: 'Camera capture',
                        icon: Icons.camera_alt_rounded,
                        gradient: AppColors.primaryGradientVertical,
                        foregroundColor: Colors.white,
                        onTap: () => _startCameraScan(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: _buildPrimaryActionCard(
                        context: context,
                        title: 'Import Images',
                        subtitle: 'From gallery',
                        icon: Icons.photo_library_rounded,
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
                        foregroundColor: isDark ? Colors.white : AppColors.navy,
                        hasBorder: true,
                        onTap: () => _startGalleryImport(context),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recent Scans Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Scans',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    if (allDocs.isNotEmpty)
                      Text(
                        '${allDocs.length} ${allDocs.length == 1 ? 'scan' : 'scans'}',
                        style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (allDocs.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      child: EmptyState(
                        customIcon: ScanoraLogo(size: 60, hasShadow: false),
                        title: 'No Documents Yet',
                        message: 'Tap "Scan Document" above to capture your first document or receipt.',
                      ),
                    ),
                  )
                else
                  ...allDocs.map((doc) => _buildRecentDocItem(context, doc, isDark)),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    Color? backgroundColor,
    Gradient? gradient,
    required Color foregroundColor,
    required VoidCallback onTap,
    bool hasBorder = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gradient == null ? (backgroundColor ?? Colors.transparent) : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            border: hasBorder
                ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.border)
                : (gradient != null
                    ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2)
                    : null),
            boxShadow: gradient != null
                ? [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: foregroundColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: foregroundColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: foregroundColor.withAlpha(200),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDocItem(BuildContext context, ScannedDocument doc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          onTap: () => _openDocument(context, doc),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildThumbnail(context, doc),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormatter.formatDisplay(doc.createdAt)} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FileUtils.formatFileSize(doc.fileSizeBytes),
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
                  onSelected: (val) {
                    if (val == 'ask_ai') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentChatScreen(document: doc),
                        ),
                      );
                    } else if (val == 'open') {
                      _openDocument(context, doc);
                    } else if (val == 'share') {
                      SharePlus.instance.share(
                        ShareParams(files: [XFile(doc.filePath)], text: doc.title),
                      );
                    } else if (val == 'rename') {
                      _renameDocument(context, doc);
                    } else if (val == 'move') {
                      _moveToFolder(context, doc);
                    } else if (val == 'delete') {
                      _deleteDocument(context, doc);
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ScannedDocument doc) {
    return DocumentThumbnailView(
      doc: doc,
      width: 52,
      height: 68,
      borderRadius: BorderRadius.circular(8),
      showBadge: true,
    );
  }

  Future<void> _renameDocument(BuildContext context, ScannedDocument doc) async {
    final newName = await CustomDialogs.showInputDialog(
      context: context,
      title: 'Rename Document',
      initialValue: doc.title,
      hintText: 'Enter document name',
      confirmLabel: 'Rename',
    );

    if (newName != null && newName.trim().isNotEmpty && newName.trim() != doc.title) {
      final sanitized = FileUtils.sanitizeFileName(newName.trim());
      await StorageService().renameDocument(doc.id, sanitized);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document renamed to "$sanitized"')),
        );
      }
    }
  }

  Future<void> _moveToFolder(BuildContext context, ScannedDocument doc) async {
    final storage = StorageService();
    final selectedFolder = await CustomDialogs.showFolderSelectionSheet(
      context: context,
      folders: storage.folders,
      currentFolderId: doc.folderId,
    );

    if (selectedFolder != null) {
      final targetFolderId = selectedFolder == '__ROOT__' ? null : selectedFolder;
      await storage.moveDocumentToFolder(doc.id, targetFolderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moved successfully')),
        );
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context, ScannedDocument doc) async {
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
}
