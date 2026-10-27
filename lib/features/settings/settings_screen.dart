import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../services/file_service.dart';
import '../../services/storage_service.dart';

import '../chat/services/document_text_extraction_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _totalStorageBytes = 0;
  int _tempStorageBytes = 0;
  bool _isLoadingStorage = true;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    final fileService = FileService();
    final total = await fileService.getTotalStorageBytes();
    final temp = await fileService.getTempStorageBytes();

    if (mounted) {
      setState(() {
        _totalStorageBytes = total;
        _tempStorageBytes = temp;
        _isLoadingStorage = false;
      });
    }
  }

  Future<void> _clearCache() async {
    await FileService().clearTempFiles();
    await DocumentTextExtractionService().clearAllCache();
    await _loadStorageStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary cache and extracted text cleared')),
      );
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Scanora',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 30),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'Scanora is an ad-free, local-first document scanner designed for clean document digitization, quick camera captures, and effortless PDF generation.',
        ),
        SizedBox(height: 12),
        Text(
          'Privacy Principle: All scanned pages, images, and PDF documents are strictly saved on your local device. No data is ever transmitted to remote servers.',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StorageService(),
      builder: (context, _) {
        final storage = StorageService();
        final currentTheme = storage.settings.themeMode;
        final currentPageSize = storage.settings.defaultPageSize;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Appearance Section
              _buildSectionHeader('Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theme Mode',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto, size: 18),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode, size: 18),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode, size: 18),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {currentTheme},
                        onSelectionChanged: (set) {
                          storage.updateThemeMode(set.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Scanning & PDF Section
              _buildSectionHeader('PDF & Scanning Defaults'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default Page Format',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Standard page dimensions for exported PDF files.',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'A4', label: Text('A4 (210 × 297 mm)')),
                          ButtonSegment(value: 'Letter', label: Text('US Letter')),
                        ],
                        selected: {currentPageSize},
                        onSelectionChanged: (set) {
                          storage.updateDefaultPageSize(set.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Storage & Privacy Section
              _buildSectionHeader('Device Storage & Privacy'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Documents & PDFs Storage',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _isLoadingStorage
                                ? '...'
                                : FileUtils.formatFileSize(_totalStorageBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Temporary Processing Cache',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _isLoadingStorage
                                ? '...'
                                : FileUtils.formatFileSize(_tempStorageBytes),
                            style: const TextStyle(color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Clear temporary cache safely without affecting saved documents.',
                              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _clearCache,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Clear Cache'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // About Section
              _buildSectionHeader('About Scanora'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.security_outlined, color: AppColors.primaryBlue),
                      title: const Text('Privacy Principle'),
                      subtitle: const Text('100% on-device, zero data collection'),
                      trailing: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: AppColors.primaryBlue),
                      title: const Text('About Scanora'),
                      subtitle: const Text('Version 1.0.0 • Local Document Scanner'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showAboutDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryText,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
