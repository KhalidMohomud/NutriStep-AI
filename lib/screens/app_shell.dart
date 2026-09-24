import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/pressable.dart';
import 'scan_screen.dart';

const _barHeight = 68.0;
const _scanSize = 66.0;

/// The three tabs. An indexed stack, so Home stays mounted behind Scan and Profile.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    // the scan tab is dark end to end; a white bar under it would look pasted on
    final dark = shell.currentIndex == 1;
    // tell the scan screen whether to run the camera — after this frame, since
    // listeners may rebuild
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scanTabActive.value = dark,
    );

    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);

    return Scaffold(
      // content runs under the floating bar; screens pad by MediaQuery's bottom
      extendBody: true,
      body: shell,
      bottomNavigationBar: _TabBar(
        index: shell.currentIndex,
        dark: dark,
        onTap: go,
      ),
    );
  }
}

/// A floating pill with Home and Profile, and Scan as a raised gradient button
/// in the middle — it's the one thing the app is for.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.dark, required this.onTap});

  final int index;
  final bool dark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = max(MediaQuery.paddingOf(context).bottom, 12.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
      child: SizedBox(
        height: _barHeight + _scanSize * 0.3,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _barHeight,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF14223F) : AppColors.card,
                borderRadius: BorderRadius.circular(_barHeight / 2),
                border: Border.all(
                  color: dark ? const Color(0xFF1E2F52) : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? const Color(0x66000000)
                        : const Color(0x1A02203E),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Tab(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: index == 0,
                      dark: dark,
                      onTap: () => onTap(0),
                    ),
                  ),
                  // room for the scan button
                  const SizedBox(width: _scanSize + 24),
                  Expanded(
                    child: _Tab(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                      selected: index == 2,
                      dark: dark,
                      onTap: () => onTap(2),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: _ScanButton(
                selected: index == 1,
                dark: dark,
                onTap: () => onTap(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = dark ? Colors.white : AppColors.brandGreen;
    final idle = dark ? const Color(0xFF7D89A3) : AppColors.iconInactive;

    return Pressable(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 16 : 10,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : AppColors.brandGreenTint)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 24,
                color: selected ? active : idle,
              ),
              // the label shows on the selected tab only — calmer, and roomier
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: active,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedOpacity: 0.8,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: _scanSize,
          height: _scanSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandLeaf,
                AppColors.brandGreen,
                AppColors.brandAzure,
                AppColors.brandBlue,
              ],
              stops: [0, 0.3, 0.7, 1],
            ),
            // a ring in the page colour, so the button sits "in" the bar
            border: Border.all(
              color: dark ? scanBackground : AppColors.background,
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4005A029),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.photo_camera_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
