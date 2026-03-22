import 'package:dictionary_feature/dictionary_feature.dart';
import 'package:flashcard_editor/flashcard_editor.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_feature/highlight_feature.dart';
import 'package:home_feature/home_feature.dart';
import 'package:import_flow/import_flow.dart';
import 'package:library_feature/library_feature.dart';
import 'package:onboarding/onboarding.dart';
import 'package:paywall_feature/paywall_feature.dart';
import 'package:practice_feature/practice_feature.dart';
import 'package:profile_feature/profile_feature.dart';
import 'package:reader_feature/reader_feature.dart';
import 'package:readflex/app/bottom_navigation_bar.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:splash/splash.dart';
import 'package:translate_feature/translate_feature.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const library = '/library';
  static const dictionary = '/dictionary';
  static const practice = '/practice';
  static const profile = '/profile';
  static const onboarding = '/onboarding';

  static String reader(String sourceId) => '/reader/$sourceId';
}

GoRouter buildRouter({required DependenciesContainer dependencies}) {
  dependencies.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    debugLogDiagnostics: dependencies.config.isDev,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final location = state.uri.path;
      final isFirstLaunch =
          dependencies.preferencesService.current.isFirstLaunch;

      // After splash, redirect based on first launch state.
      if (location == AppRoutes.home && isFirstLaunch) {
        return AppRoutes.onboarding;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(
          onReady: () => context.go(AppRoutes.home),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) {
                  return HomeScreen(
                    bookRepository: dependencies.bookRepository,
                    highlightRepository: dependencies.highlightRepository,
                    flashcardRepository: dependencies.flashcardRepository,
                    onBookPressed: (book) => context.push(
                      AppRoutes.reader(book.id),
                    ),
                    onArticlePressed: (article) => context.push(
                      AppRoutes.reader(article.id),
                    ),
                    onPracticePressed: () => context.go(
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
                  return LibraryScreen(
                    bookRepository: dependencies.bookRepository,
                    onBookPressed: (book) => context.push(
                      AppRoutes.reader(book.id),
                    ),
                    onArticlePressed: (article) => context.push(
                      AppRoutes.reader(article.id),
                    ),
                    onAddPressed: () => showImportFlowSheet(
                      context,
                      articleParser: dependencies.articleParser,
                      bookRepository: dependencies.bookRepository,
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
                builder: (context, state) {
                  return DictionaryScreen(
                    dictionaryRepository: dependencies.dictionaryRepository,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.practice,
                builder: (context, state) {
                  return PracticeScreen(
                    flashcardRepository: dependencies.flashcardRepository,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) {
                  return ProfileScreen(
                    authService: dependencies.authService,
                    subscriptionService: dependencies.subscriptionService,
                    onSignInPressed: () {
                      // TODO: navigate to sign in flow
                    },
                    onPremiumPressed: () => showPaywallSheet(
                      context,
                      subscriptionService: dependencies.subscriptionService,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/reader/:sourceId',
        builder: (context, state) {
          final sourceId = state.pathParameters['sourceId']!;
          return ReaderScreen(
            sourceId: sourceId,
            bookRepository: dependencies.bookRepository,
            highlightRepository: dependencies.highlightRepository,
            textActions: [
              HighlightAction(
                highlightRepository: dependencies.highlightRepository,
              ),
              FlashcardEditorAction(
                flashcardRepository: dependencies.flashcardRepository,
              ),
              TranslateAction(
                translationService: dependencies.translationService,
                dictionaryRepository: dependencies.dictionaryRepository,
              ),
            ],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onComplete: () {
            dependencies.preferencesService.update(
              (p) => p.copyWith(isFirstLaunch: false),
            );
            context.go(AppRoutes.home);
          },
        ),
      ),
    ],
  );
}
