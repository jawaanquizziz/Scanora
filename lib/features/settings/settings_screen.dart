import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../core/widgets/google_drive_icon.dart';
import '../../core/widgets/scanora_logo.dart';
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
      final restored = drive.lastRestoredCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored > 0
                ? 'Signed in as ${drive.userEmail}. Restored $restored ${restored == 1 ? 'PDF' : 'PDFs'} from Google Drive!'
                : 'Signed in as ${drive.userEmail}. Google Drive backup & restore active!',
          ),
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

    final restored = drive.lastRestoredCount;
    String message;
    if (restored > 0 && count > restored) {
      message =
          'Restored $restored and uploaded ${count - restored} PDFs with Google Drive!';
    } else if (restored > 0) {
      message =
          'Restored $restored ${restored == 1 ? 'document' : 'documents'} from Google Drive!';
    } else if (count > 0) {
      message =
          'Successfully synced $count ${count == 1 ? 'document' : 'documents'} to Google Drive!';
    } else {
      message = drive.lastError ?? 'All documents are synced and up to date with Google Drive!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
      applicationIcon: const ScanoraLogo(size: 46),
      children: const [
        SizedBox(height: 12),
        Text(
          'Scanora is a privacy-first AI document scanner with 100% on-device OCR, offline GGUF LLM document Q&A, AES-128 PDF password encryption, anti-fraud watermarking, and personal Google Drive backup & restore.',
        ),
        SizedBox(height: 12),
        Text(
          'Privacy Guarantee: Your documents are processed locally on your phone and are only backed up to your personal Google Drive account when you sign in.',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        final syncProgress = totalDocsCount > 0
            ? (syncedDocsCount / totalDocsCount).clamp(0.0, 1.0)
            : 1.0;

        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: const Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // 1. Account & Google Drive Cloud Backup Card
              _buildSectionHeader('Account & Cloud Backup'),
              _buildGroupContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (drive.isSignedIn)
                          GoogleAccountAvatar(
                            photoUrl: drive.userPhotoUrl,
                            displayName: drive.userDisplayName,
                            email: drive.userEmail,
                            radius: 27,
                            showDriveBadge: true,
                          )
                        else
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E2638)
                                  : const Color(0xFFF0F7FF),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2E3C56)
                                    : const Color(0xFFDBEAFE),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const GoogleDriveLogo(size: 27),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      drive.isSignedIn
                                          ? (drive.userDisplayName?.isNotEmpty == true
                                              ? drive.userDisplayName!
                                              : 'Google Account')
                                          : 'Google Drive Backup',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (drive.isSignedIn) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withAlpha(26),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.success.withAlpha(90),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: AppColors.success,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                drive.isSignedIn
                                    ? (drive.userEmail ?? '')
                                    : 'Sign in with Google to back up & restore your PDFs across reinstalls.',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12.5,
                                  height: 1.35,
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
                        height: 48,
                        child: OutlinedButton(
                          onPressed: drive.isSigningIn ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF1F2633)
                                : Colors.white,
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFDADCE0),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (drive.isSigningIn)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                const GoogleGLogo(size: 19),
                              const SizedBox(width: 12),
                              Text(
                                drive.isSigningIn ? 'Connecting...' : 'Continue with Google',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // Cloud Sync Status Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF131822)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF242D3F)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const GoogleDriveLogo(size: 16),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Folder: "Scanora Documents"',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$syncedDocsCount / $totalDocsCount synced',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: syncProgress,
                                minHeight: 5,
                                backgroundColor: isDark
                                    ? const Color(0xFF262F42)
                                    : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildIconBadge(
                            icon: Icons.cloud_upload_outlined,
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-Backup New Scans',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Automatically upload new PDFs to Drive',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: autoSyncDrive,
                            activeTrackColor: AppColors.primaryBlue,
                            onChanged: (val) => storage.updateAutoSyncToDrive(val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: drive.isSyncing ? null : _handleSyncAllToDrive,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                                icon: drive.isSyncing
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded, size: 18),
                                label: Text(
                                  drive.isRestoring
                                      ? 'Restoring...'
                                      : (drive.isSyncing ? 'Syncing...' : 'Sync & Restore'),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton.icon(
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
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                                icon: const Icon(Icons.logout_rounded, size: 16),
                                label: const Text(
                                  'Sign Out',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 2. Security & Anti-Fraud Defaults
              _buildSectionHeader('Security & Anti-Fraud'),
              _buildGroupContainer(
                isDark: isDark,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _buildIconBadge(
                            icon: Icons.fingerprint_rounded,
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biometric App Lock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Require fingerprint, face, or PIN on launch',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isBiometricEnabled,
                            activeTrackColor: AppColors.primaryBlue,
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
                        ],
                      ),
                    ),
                    _buildDivider(isDark),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                      onTap: _editDefaultWatermark,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            _buildIconBadge(
                              icon: Icons.verified_user_outlined,
                              color: const Color(0xFFF59E0B),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Default Watermark Stamp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Preset: "${storage.settings.defaultWatermark}"',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2633)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryBlue),
                                  SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 3. Appearance & Document Preferences
              _buildSectionHeader('Preferences & Defaults'),
              _buildGroupContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildIconBadge(
                          icon: Icons.palette_outlined,
                          color: const Color(0xFFEC4899),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Appearance',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                              Text(
                                'Choose light, dark, or system theme',
                                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded, size: 16),
                            label: Text('System', style: TextStyle(fontSize: 12.5)),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded, size: 16),
                            label: Text('Light', style: TextStyle(fontSize: 12.5)),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded, size: 16),
                            label: Text('Dark', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                        selected: {currentTheme},
                        onSelectionChanged: (set) {
                          storage.updateThemeMode(set.first);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        _buildIconBadge(
                          icon: Icons.description_outlined,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Default PDF Page Size',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                              Text(
                                'Standard paper dimensions for exported scans',
                                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'A4',
                            icon: Icon(Icons.crop_portrait_rounded, size: 16),
                            label: Text('A4 (210 × 297 mm)', style: TextStyle(fontSize: 12.5)),
                          ),
                          ButtonSegment(
                            value: 'Letter',
                            icon: Icon(Icons.article_outlined, size: 16),
                            label: Text('US Letter', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                        selected: {currentPageSize},
                        onSelectionChanged: (set) {
                          storage.updateDefaultPageSize(set.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 4. Storage & Cache Management
              _buildSectionHeader('Storage & Cache'),
              _buildGroupContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildIconBadge(
                          icon: Icons.folder_zip_outlined,
                          color: const Color(0xFF0EA5E9),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saved PDFs & Thumbnails',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                'Local encrypted & standard documents',
                                style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _isLoadingStorage
                              ? '...'
                              : FileUtils.formatFileSize(_totalStorageBytes),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildIconBadge(
                          icon: Icons.cleaning_services_outlined,
                          color: const Color(0xFF64748B),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Temporary OCR & Image Cache',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                _isLoadingStorage
                                    ? 'Calculating...'
                                    : '${FileUtils.formatFileSize(_tempStorageBytes)} used • Safe to clear',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _clearCache,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Clear Cache',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 5. About Scanora
              _buildSectionHeader('About'),
              _buildGroupContainer(
                isDark: isDark,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          _buildIconBadge(
                            icon: Icons.shield_outlined,
                            color: AppColors.success,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '100% On-Device Privacy',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                Text(
                                  'Offline OCR & LLM • Personal Google Drive sync',
                                  style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        ],
                      ),
                    ),
                    _buildDivider(isDark),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                      onTap: _showAboutDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            _buildIconBadge(
                              icon: Icons.info_outline_rounded,
                              color: AppColors.primaryBlue,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'About Scanora',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  Text(
                                    'Version 1.0.0 • Architecture & Licenses',
                                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupContainer({
    required bool isDark,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 36 : 24),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: isDark ? const Color(0xFF242C3D) : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryText,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
