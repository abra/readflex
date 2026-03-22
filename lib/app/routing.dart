import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_feature/home_feature.dart';
import 'package:import_flow/import_flow.dart';
import 'package:library_feature/library_feature.dart';
import 'package:onboarding/onboarding.dart';
import 'package:profile_feature/profile_feature.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:splash/splash.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const library = '/library';
  static const dictionary = '/dictionary';
  static const practice = '/practice';
  static const profile = '/profile';
  static const reader = '/reader/:sourceId';
  static const onboarding = '/onboarding';
}

GoRouter buildRouter({required DependenciesContainer dependencies}) {
  dependencies.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    debugLogDiagnostics: dependencies.config.isDev,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(
          onFirstLaunch: () => _router(context).go(AppRoutes.onboarding),
          onHome: () => _router(context).go(AppRoutes.home),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) {
                  final deps = DependenciesScope.of(context);
                  return HomeScreen(
                    bookRepository: deps.bookRepository,
                    highlightRepository: deps.highlightRepository,
                    flashcardRepository: deps.flashcardRepository,
                    onBookPressed: (book) => _router(context).go(
                      '/reader/${book.id}',
                    ),
                    onArticlePressed: (article) => _router(context).go(
                      '/reader/${article.id}',
                    ),
                    onPracticePressed: () => _router(context).go(
                      AppRoutes.practice,
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) {
                  final deps = DependenciesScope.of(context);
                  return LibraryScreen(
                    bookRepository: deps.bookRepository,
                    onBookPressed: (book) => _router(context).go(
                      '/reader/${book.id}',
                    ),
                    onArticlePressed: (article) => _router(context).go(
                      '/reader/${article.id}',
                    ),
                    onAddPressed: () => showImportFlowSheet(
                      context,
                      articleParser: deps.articleParser,
                      bookRepository: deps.bookRepository,
                      onBookFilePicked: () {
                        // TODO: integrate file_picker
                      },
                      onArticleImported: () {
                        // Library will refresh via BLoC
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dictionary,
                builder: (context, state) =>
                    const _PlaceholderTab(label: 'Dictionary'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.practice,
                builder: (context, state) =>
                    const _PlaceholderTab(label: 'Practice'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) {
                  final deps = DependenciesScope.of(context);
                  return ProfileScreen(
                    authService: deps.authService,
                    subscriptionService: deps.subscriptionService,
                    onSignInPressed: () {
                      // TODO: navigate to sign in flow
                    },
                    onPremiumPressed: () {
                      // TODO: show paywall
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.reader,
        builder: (context, state) {
          final sourceId = state.pathParameters['sourceId']!;
          return _PlaceholderTab(label: 'Reader: $sourceId');
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onComplete: () => _router(context).go(AppRoutes.home),
        ),
      ),
    ],
  );
}

GoRouter _router(BuildContext context) => GoRouter.of(context);

/// Shell scaffold with bottom navigation bar.
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Temporary placeholder screen for tabs not yet implemented.
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Text(label, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
