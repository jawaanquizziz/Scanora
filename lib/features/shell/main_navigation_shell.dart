import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../documents/documents_screen.dart';
import '../folders/folders_screen.dart';
import '../home/home_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
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
      ),
      const DocumentsScreen(),
      const FoldersScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomBar(),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.72),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
