import 'package:dictionary_feature/dictionary_feature.dart';
import 'package:flashcards/flashcards.dart';
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
import 'package:readflex/app/first_import_screen.dart';
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
  static const firstImport = '/first-import';
  static const readerPath = '/reader/:sourceId';

  static String reader(String sourceId) => '/reader/$sourceId';
}

GoRouter buildRouter({required DependenciesContainer dependencies}) {
  dependencies.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    debugLogDiagnostics: dependencies.config.isDev,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) async {
      final location = state.uri.path;
      final prefs = dependencies.preferencesService.current;

      if (location == AppRoutes.home && !prefs.onboardingCompleted) {
        return AppRoutes.onboarding;
      }

      if (location == AppRoutes.home && !prefs.hasCompletedSetup) {
        final books = await dependencies.bookRepository.getBooks();
        final articles = await dependencies.articleRepository.getArticles();
        if (books.isEmpty && articles.isEmpty) {
          return AppRoutes.firstImport;
        }
        // User somehow has books — mark setup as complete.
        await dependencies.preferencesService.update(
          (p) => p.copyWith(hasCompletedSetup: true),
        );
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
                    articleRepository: dependencies.articleRepository,
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
                    articleRepository: dependencies.articleRepository,
                    onBookPressed: (book) => context.push(
                      AppRoutes.reader(book.id),
                    ),
                    onArticlePressed: (article) => context.push(
                      AppRoutes.reader(article.id),
                    ),
                    onAddPressed: () => showImportFlowSheet(
                      context,
                      articleParser: dependencies.articleParser,
                      articleRepository: dependencies.articleRepository,
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
                    highlightRepository: dependencies.highlightRepository,
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
                    // TODO: navigate to sign in flow.
                    onSignInPressed: () {},
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
        path: AppRoutes.readerPath,
        builder: (context, state) {
          final sourceId = state.pathParameters['sourceId']!;
          return ReaderScreen(
            sourceId: sourceId,
            bookRepository: dependencies.bookRepository,
            articleRepository: dependencies.articleRepository,
            highlightRepository: dependencies.highlightRepository,
            textActions: [
              HighlightAction(
                highlightRepository: dependencies.highlightRepository,
              ),
              FlashcardAction(
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
              (p) => p.copyWith(onboardingCompleted: true),
            );
            context.go(AppRoutes.firstImport);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.firstImport,
        builder: (context, state) => FirstImportScreen(
          articleParser: dependencies.articleParser,
          articleRepository: dependencies.articleRepository,
          onBookFilePicked: () {
            // TODO: integrate file_picker
          },
          onContentAdded: () {
            dependencies.preferencesService.update(
              (p) => p.copyWith(hasCompletedSetup: true),
            );
            context.go(AppRoutes.home);
          },
        ),
      ),
    ],
  );
}
