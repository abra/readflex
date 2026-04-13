import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell scaffold with bottom navigation for the main tabs.
class TabContainerScreen extends StatelessWidget {
  const TabContainerScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugPrint(
        '[SCREEN] build TabContainerScreen(index: ${navigationShell.currentIndex})',
      );
      return true;
    }());

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.library),
            selectedIcon: Icon(AppIcons.library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.dictionary),
            selectedIcon: Icon(AppIcons.dictionary),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.practice),
            selectedIcon: Icon(AppIcons.practice),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.profile),
            selectedIcon: Icon(AppIcons.profile),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
