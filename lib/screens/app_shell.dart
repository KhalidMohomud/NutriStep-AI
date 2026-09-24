import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'scan_screen.dart';

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

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark ? const Color(0xFF14223F) : AppColors.divider,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: dark ? scanBackground : AppColors.background,
          selectedItemColor: dark ? AppColors.brandLeaf : AppColors.brandGreen,
          unselectedItemColor: dark
              ? const Color(0xFF6B7690)
              : AppColors.iconInactive,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_camera_outlined),
              activeIcon: Icon(Icons.photo_camera),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
