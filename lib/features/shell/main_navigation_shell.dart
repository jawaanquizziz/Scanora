import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/scanora_logo.dart';
import '../../services/biometric_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/storage_service.dart';
import '../documents/documents_screen.dart';
import '../folders/folders_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isAppUnlocked = true;
  bool _isAuthenticating = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final storage = StorageService();
    if (storage.settings.isBiometricLockEnabled) {
      _isAppUnlocked = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateApp();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Ignore transient pauses caused by native Google Sign-In or Biometric dialogs
      if (!_isAuthenticating && !GoogleDriveService().isSigningIn) {
        _backgroundedAt = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      final storage = StorageService();
      if (storage.settings.isBiometricLockEnabled &&
          !_isAuthenticating &&
          !GoogleDriveService().isSigningIn &&
          _backgroundedAt != null) {
        final elapsed = DateTime.now().difference(_backgroundedAt!);
        _backgroundedAt = null;
        if (elapsed.inSeconds >= 5) {
          setState(() {
            _isAppUnlocked = false;
          });
          _authenticateApp();
        }
      }
    }
  }

  Future<void> _authenticateApp() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final success = await BiometricService().authenticate(
        reason: 'Scanora is locked. Authenticate to open your document library.',
      );
      if (mounted) {
        setState(() {
          _isAppUnlocked = success;
        });
      }
    } finally {
      _isAuthenticating = false;
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StorageService(),
      builder: (context, _) {
        final storage = StorageService();
        final isLockEnabled = storage.settings.isBiometricLockEnabled;
        final showLockOverlay = isLockEnabled && !_isAppUnlocked;

        final screens = [
          HomeScreen(
            onNavigateToDocuments: () {
              setState(() {
                _currentIndex = 1;
              });
            },
            onNavigateToFolders: () {
              setState(() {
                _currentIndex = 2;
              });
            },
            onNavigateToSettings: () {
              setState(() {
                _currentIndex = 3;
              });
            },
          ),
          const DocumentsScreen(),
          const FoldersScreen(),
          const SettingsScreen(),
        ];

        // Keep IndexedStack permanently mounted to avoid unmounting active dependents
        return Stack(
          children: [
            Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
              bottomNavigationBar: _buildBottomBar(),
            ),
            if (showLockOverlay)
              Positioned.fill(
                child: Material(
                  child: _buildAppLockedScreen(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAppLockedScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const ScanoraLogo(size: 64, hasShadow: true),
            const SizedBox(height: 24),
            Text(
              'Scanora',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 16, color: AppColors.primaryBlue),
                  SizedBox(width: 6),
                  Text(
                    'Biometric Privacy Guard Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF388BFF), Color(0xFF176BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF176BFF).withAlpha(80),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _authenticateApp,
                  child: const Center(
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Touch fingerprint sensor or use face/PIN to unlock',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _authenticateApp,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock Scanora'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final items = [
      (
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      ),
      (
        icon: Icons.document_scanner_outlined,
        selectedIcon: Icons.document_scanner_rounded,
        label: 'My Scans',
      ),
      (
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder_rounded,
        label: 'Folders',
      ),
      (
        icon: Icons.cloud_sync_outlined,
        selectedIcon: Icons.cloud_sync_rounded,
        label: 'Settings',
      ),
    ];

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _currentIndex == index;
              return _buildNavItem(
                icon: isSelected ? item.selectedIcon : item.icon,
                label: item.label,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
