import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/scan_page.dart';
import '../../services/image_service.dart';
import '../documents/pdf_viewer_screen.dart';
import 'capture_service.dart';
import 'crop_screen.dart';
import 'filter_screen.dart';
import 'save_dialog.dart';

class PageReviewScreen extends StatefulWidget {
  final List<ScanPage> initialPages;

  const PageReviewScreen({
    super.key,
    required this.initialPages,
  });

  @override
  State<PageReviewScreen> createState() => _PageReviewScreenState();
}

class _PageReviewScreenState extends State<PageReviewScreen> {
  late List<ScanPage> _pages;
  int _currentPageIndex = 0;
  bool _isProcessing = false;
  String _processingMessage = 'Applying filter...';
  bool _applyFilterToAll = false;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _pages = List<ScanPage>.from(widget.initialPages);
  }

  Future<bool> _onWillPop() async {
    if (_hasSaved) return true;
    final confirmed = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Discard Scan?',
      message: 'You have unsaved scanned pages. Are you sure you want to discard them?',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
    return confirmed;
  }

  Future<void> _addPages() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryBlue),
              title: const Text('Capture with Camera'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final newPage = await CaptureService.captureFromCamera(context);
                if (newPage != null) {
                  setState(() {
                    _pages.add(newPage);
                    _currentPageIndex = _pages.length - 1;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryBlue),
              title: const Text('Import from Gallery'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final newPages = await CaptureService.importFromGallery(context);
                if (newPages.isNotEmpty) {
                  setState(() {
                    _pages.addAll(newPages);
                    _currentPageIndex = _pages.length - 1;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rotateCurrentPage() async {
    if (_pages.isEmpty) return;
    setState(() {
      _isProcessing = true;
    });

    final page = _pages[_currentPageIndex];
    page.rotationAngle = (page.rotationAngle + 90) % 360;

    try {
      final processed = await ImageService().processPage(page);
      page.processedImagePath = processed;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _cropCurrentPage() async {
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];
    final updated = await Navigator.of(context).push<ScanPage>(
      MaterialPageRoute(
        builder: (_) => CropScreen(page: page, isSingleStep: true),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _pages[_currentPageIndex] = updated;
      });
    }
  }

  Future<void> _filterCurrentPage() async {
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];
    final result = await Navigator.of(context).push<FilterScreenResult>(
      MaterialPageRoute(
        builder: (_) => FilterScreen(
          page: page,
          totalPages: _pages.length,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _pages[_currentPageIndex] = result.updatedPage;
        _hasSaved = false;
      });
      if (result.applyToAllPages && _pages.length > 1) {
        await _applyFilterToAllPages(result.updatedPage.filter);
      }
    }
  }

  Future<void> _applyFilterToAllPages(FilterType filter) async {
    if (_pages.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _hasSaved = false;
      _processingMessage = 'Applying ${filter.displayName} to all ${_pages.length} pages...';
    });

    try {
      for (int i = 0; i < _pages.length; i++) {
        if (!mounted) break;
        final p = _pages[i];
        setState(() {
          _processingMessage =
              'Applying ${filter.displayName} (${i + 1} of ${_pages.length})...';
        });
        if (p.filter != filter) {
          p.filter = filter;
          final processed = await ImageService().processPage(p);
          p.processedImagePath = processed;
        }
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Applied "${filter.displayName}" filter to all ${_pages.length} pages',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch filter error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingMessage = 'Applying filter...';
        });
      }
    }
  }

  Future<void> _applyDirectFilter(FilterType filter) async {
    if (_pages.isEmpty) return;

    if (_applyFilterToAll && _pages.length > 1) {
      await _applyFilterToAllPages(filter);
      return;
    }

    final page = _pages[_currentPageIndex];
    if (page.filter == filter) return;

    setState(() {
      _isProcessing = true;
      _hasSaved = false;
      _processingMessage = 'Applying ${filter.displayName}...';
    });

    page.filter = filter;

    try {
      final processed = await ImageService().processPage(page);
      if (mounted) {
        setState(() {
          page.processedImagePath = processed;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Filter error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingMessage = 'Applying filter...';
        });
      }
    }
  }

  Future<void> _deleteCurrentPage() async {
    if (_pages.isEmpty) return;

    if (_pages.length == 1) {
      final confirm = await CustomDialogs.showConfirmDialog(
        context: context,
        title: 'Delete Page?',
        message: 'This is the only page in your scan. Deleting it will cancel this scan session.',
        confirmLabel: 'Delete & Exit',
      );
      if (confirm && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final confirm = await CustomDialogs.showConfirmDialog(
      context: context,
      title: 'Delete Page?',
      message: 'Are you sure you want to delete page ${_currentPageIndex + 1}?',
      confirmLabel: 'Delete',
    );

    if (confirm && mounted) {
      setState(() {
        _pages.removeAt(_currentPageIndex);
        if (_currentPageIndex >= _pages.length) {
          _currentPageIndex = _pages.length - 1;
        }
      });
    }
  }

  Future<void> _saveDocument() async {
    if (_pages.isEmpty) return;

    final savedDoc = await SaveDialog.show(
      context: context,
      pages: _pages,
    );

    if (savedDoc != null && mounted) {
      setState(() {
        _hasSaved = true;
      });
      // Show success sheet and give user option to view PDF or return home
      SaveDialog.showSuccessSheet(
        context: context,
        document: savedDoc,
        onOpenPdf: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(document: savedDoc),
            ),
          );
        },
        onDone: () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No pages captured')),
      );
    }

    final currentPage = _pages[_currentPageIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101216),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101216),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Page ${_currentPageIndex + 1} of ${_pages.length}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
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
                  onPressed: _saveDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save PDF'),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Main Page Preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(currentPage.processedImagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Multi-page thumbnail carousel
                if (_pages.length > 1)
                  Container(
                    height: 76,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _pages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentPageIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentPageIndex = index;
                            });
                          },
                          child: Container(
                            width: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryBlue : Colors.white24,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(_pages[index].processedImagePath),
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Direct Realtime Filter Selection Chips (Original, Enhance, Grayscale, B&W)
                _buildFilterPills(currentPage),

                // Bottom Page Editing Toolbar
                Container(
                  color: const Color(0xFF181B22),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionItem(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Add Page',
                          onTap: _addPages,
                        ),
                        _buildActionItem(
                          icon: Icons.crop_rotate_rounded,
                          label: 'Crop',
                          onTap: _cropCurrentPage,
                        ),
                        _buildActionItem(
                          icon: Icons.tune_rounded,
                          label: 'Filters',
                          onTap: _filterCurrentPage,
                        ),
                        _buildActionItem(
                          icon: Icons.rotate_right_rounded,
                          label: 'Rotate',
                          onTap: _rotateCurrentPage,
                        ),
                        _buildActionItem(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onTap: _deleteCurrentPage,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isProcessing)
              LoadingOverlay(message: _processingMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills(ScanPage currentPage) {
    final allSameFilter = _pages.length > 1 &&
        _pages.every((p) => p.filter == currentPage.filter);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF14171E),
        border: Border(
          top: BorderSide(color: Color(0xFF222734), width: 1),
          bottom: BorderSide(color: Color(0xFF222734), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pages.length > 1) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7, left: 2, right: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _applyFilterToAll = !_applyFilterToAll;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _applyFilterToAll,
                            activeColor: AppColors.primaryBlue,
                            side: const BorderSide(color: Colors.white54, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _applyFilterToAll = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Apply filter to all ${_pages.length} pages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: (_isProcessing || allSameFilter)
                        ? null
                        : () => _applyFilterToAllPages(currentPage.filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: allSameFilter
                            ? Colors.white.withAlpha(15)
                            : AppColors.primaryBlue.withAlpha(38),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: allSameFilter
                              ? Colors.white24
                              : AppColors.primaryBlue.withAlpha(140),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allSameFilter
                                ? Icons.done_all_rounded
                                : Icons.library_add_check_rounded,
                            size: 13,
                            color: allSameFilter ? Colors.white54 : AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            allSameFilter
                                ? 'Applied to all'
                                : 'Apply "${currentPage.filter.displayName}" to all',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: allSameFilter ? Colors.white54 : AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: FilterType.values.map((filter) {
              final isSelected = currentPage.filter == filter;
              IconData icon;
              switch (filter) {
                case FilterType.original:
                  icon = Icons.photo_outlined;
                  break;
                case FilterType.enhance:
                  icon = Icons.auto_fix_high_rounded;
                  break;
                case FilterType.grayscale:
                  icon = Icons.tonality_rounded;
                  break;
                case FilterType.blackAndWhite:
                  icon = Icons.contrast_rounded;
                  break;
              }

              return InkWell(
                onTap: _isProcessing ? null : () => _applyDirectFilter(filter),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryBlue : const Color(0xFF1E232E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryBlue : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        filter.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
