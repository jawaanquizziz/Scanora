import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../services/biometric_service.dart';
import '../../services/file_service.dart';
import '../../services/google_drive_service.dart';
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

  Future<void> _handleGoogleSignIn() async {
    final drive = GoogleDriveService();
    final signedIn = await drive.signIn();
    if (!mounted) return;

    if (signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as ${drive.userEmail}. Google Drive backup ready!'),
        ),
      );
    } else if (drive.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(drive.lastError!)),
      );
    }
  }

  Future<void> _handleSyncAllToDrive() async {
    final drive = GoogleDriveService();
    final count = await drive.syncAllUnsyncedDocuments();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Successfully synced $count ${count == 1 ? 'document' : 'documents'} to Google Drive!'
              : (drive.lastError ?? 'All documents are already synced to Google Drive!'),
        ),
      ),
    );
  }

  Future<void> _editDefaultWatermark() async {
    final storage = StorageService();
    final updated = await CustomDialogs.showInputDialog(
      context: context,
      title: 'Default Anti-Fraud Watermark',
      initialValue: storage.settings.defaultWatermark,
      hintText: 'e.g. CONFIDENTIAL, FOR KYC ONLY',
      confirmLabel: 'Save Default',
    );
    if (updated != null && updated.trim().isNotEmpty) {
      await storage.updateDefaultWatermark(updated.trim());
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
          'Scanora is an intelligent, privacy-first mobile document scanner with on-device OCR, Gemini AI Rag-Lite Chat, AES PDF encryption, anti-fraud watermarking, and optional Google Drive synchronization.',
        ),
        SizedBox(height: 12),
        Text(
          'Privacy Principle: All scanned pages, images, and PDF documents are stored locally on your device, and only backed up to your personal Google Drive when you explicitly sign in.',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([StorageService(), GoogleDriveService()]),
      builder: (context, _) {
        final storage = StorageService();
        final drive = GoogleDriveService();
        final currentTheme = storage.settings.themeMode;
        final currentPageSize = storage.settings.defaultPageSize;
        final isBiometricEnabled = storage.settings.isBiometricLockEnabled;
        final autoSyncDrive = storage.settings.autoSyncToDrive;
        final syncedDocsCount = storage.documents.where((d) => d.isCloudSynced).length;
        final totalDocsCount = storage.documents.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings & Cloud Backup'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Google Drive Cloud Backup Section
              _buildSectionHeader('Cloud Backup (Google Drive)'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              drive.isSignedIn
                                  ? Icons.cloud_done_rounded
                                  : Icons.add_to_drive_rounded,
                              color: AppColors.primaryBlue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drive.isSignedIn
                                      ? (drive.userDisplayName ?? 'Google Account Connected')
                                      : 'Google Drive Sync',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  drive.isSignedIn
                                      ? '${drive.userEmail} • $syncedDocsCount of $totalDocsCount PDFs backed up'
                                      : 'Sign in with Google to back up your scanned PDFs to "Scanora Documents" in your Drive.',
                                  style: const TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (!drive.isSignedIn)
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: const Icon(Icons.login_rounded, size: 20),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      else ...[
                        const Divider(height: 20),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Auto-Backup New Scans to Drive',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Automatically upload newly scanned PDFs to your "Scanora Documents" folder',
                            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                          ),
                          value: autoSyncDrive,
                          onChanged: (val) => storage.updateAutoSyncToDrive(val),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: drive.isSyncing ? null : _handleSyncAllToDrive,
                                icon: drive.isSyncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_sync_rounded, size: 18),
                                label: Text(
                                  drive.isSyncing ? 'Syncing...' : 'Sync All Now',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await drive.signOut();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Signed out of Google Drive'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Security, Vault & Watermark Section
              _buildSectionHeader('Security & Anti-Fraud Defaults'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      secondary: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primaryBlue,
                      ),
                      title: const Text(
                        'Biometric App Lock',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: const Text(
                        'Require fingerprint, face, or PIN when opening Scanora',
                        style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                      value: isBiometricEnabled,
                      onChanged: (val) async {
                        final authenticated = await BiometricService().authenticate(
                          reason: val
                              ? 'Authenticate to enable Biometric App Lock'
                              : 'Authenticate to disable Biometric App Lock',
                        );
                        if (authenticated) {
                          await storage.toggleBiometricLock(val);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primaryBlue,
                      ),
                      title: const Text(
                        'Default Watermark Stamp',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Preset text: "${storage.settings.defaultWatermark}"',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: _editDefaultWatermark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Appearance Section
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

              // 4. Scanning & PDF Section
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

              // 5. Storage & Privacy Section
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

              // 6. About Section
              _buildSectionHeader('About Scanora'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.security_outlined, color: AppColors.primaryBlue),
                      title: Text('Privacy Principle'),
                      subtitle: Text('Local-first storage + User-owned Google Drive backup'),
                      trailing: Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: AppColors.primaryBlue),
                      title: const Text('About Scanora'),
                      subtitle: const Text('Version 1.0.0 • AI Document Scanner'),
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
