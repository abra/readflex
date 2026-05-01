import 'package:component_library/component_library.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const int _kDestinationCount = 5;

/// Shell scaffold with bottom navigation for the main tabs.
///
/// The offline strip ([OfflineBanner]) is composed with the [NavigationBar]
/// via a [Column] so it sits flush above the bottom nav only on tab screens.
/// Full-screen routes (Reader, Onboarding, …) host their own scaffolds and
/// therefore don't show the strip — intentionally, since those flows don't
/// depend on connectivity.
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

    final offline = ConnectivityScope.of(context) == ConnectivityStatus.offline;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offline) const OfflineBanner(),
          _NavBarWithIndicator(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// [NavigationBar] wrapped in a [Stack] that overlays a thin active-tab
/// indicator line at the very top of the selected destination.
///
/// Flutter's [NavigationBar] distributes its destinations as equal-width
/// [Expanded] slots, so we can calculate each slot's center from the total
/// bar width and overlay a centered 20×2 pill per slot without touching
/// the bar's internal layout.
class _NavBarWithIndicator extends StatelessWidget {
  const _NavBarWithIndicator({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = context.colors.onSurface;

    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    return Stack(
      children: [
        NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
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
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: hairline,
          child: ColoredBox(color: context.appColors.divider),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / _kDestinationCount;
              final lineLeft = (selectedIndex + 0.5) * slotWidth - 10;
              return SizedBox(
                height: 2,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      top: 0,
                      left: lineLeft,
                      child: Container(
                        width: 20,
                        height: 2,
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
