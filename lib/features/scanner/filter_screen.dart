import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/scan_page.dart';
import '../../services/image_service.dart';

class FilterScreen extends StatefulWidget {
  final ScanPage page;

  const FilterScreen({
    super.key,
    required this.page,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late ScanPage _currentPage;
  late FilterType _selectedFilter;
  bool _isProcessing = false;
  String _previewImagePath = '';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page.copyWith();
    _selectedFilter = _currentPage.filter;
    _previewImagePath = _currentPage.processedImagePath;
  }

  Future<void> _selectFilter(FilterType filter) async {
    if (_selectedFilter == filter) return;

    setState(() {
      _selectedFilter = filter;
      _isProcessing = true;
    });

    _currentPage.filter = filter;

    try {
      final processed = await ImageService().processPage(_currentPage);
      if (!mounted) return;
      setState(() {
        _previewImagePath = processed;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply filter: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _applyAndDone() {
    _currentPage.processedImagePath = _previewImagePath;
    _currentPage.filter = _selectedFilter;
    Navigator.of(context).pop(_currentPage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101216),
        foregroundColor: Colors.white,
        title: const Text(
          'Document Filters',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonal(
              onPressed: _isProcessing ? null : _applyAndDone,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Main preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_previewImagePath.isNotEmpty ? _previewImagePath : _currentPage.processedImagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Filter Selector
              Container(
                color: const Color(0xFF181B22),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: FilterType.values.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return _buildFilterOption(filter, isSelected);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            const LoadingOverlay(message: 'Applying filter...'),
        ],
      ),
    );
  }

  Widget _buildFilterOption(FilterType filter, bool isSelected) {
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

    return GestureDetector(
      onTap: () => _selectFilter(filter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue.withAlpha(50)
                  : const Color(0xFF242A38),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.primaryBlue : Colors.white70,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filter.displayName,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
