import 'package:content_library/content_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:flashcard_actions/flashcard_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_actions/highlight_actions.dart';
import 'package:home/home.dart';
import 'package:import_flow/import_flow.dart';
import 'package:onboarding/onboarding.dart';
import 'package:practice/practice.dart';
import 'package:profile/profile.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/bottom_navigation_bar.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/first_import_screen.dart';
import 'package:splash/splash.dart';
import 'package:subscription_paywall/subscription_paywall.dart';
import 'package:translate_text/translate_text.dart';

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
        builder: (context, state, navigationShell) => BottomNavigationShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => HomeScreen(
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
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => ContentLibraryScreen(
                  bookRepository: dependencies.bookRepository,
                  articleRepository: dependencies.articleRepository,
                  onBookPressed: (book) => context.push(
                    AppRoutes.reader(book.id),
                  ),
                  onArticlePressed: (article) => context.push(
                    AppRoutes.reader(article.id),
                  ),
                  onAddPressed: () async {
                    await showImportFlowSheet(
                      context,
                      onImportBook: () async {
                        // TODO: integrate file_picker + book import.
                        // Return false until the flow can confirm a book was
                        // actually added, not just that the picker was opened.
                        return false;
                      },
                      onImportArticle: (url) =>
                          _importArticle(dependencies, url),
                    );
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dictionary,
                builder: (context, state) => DictionaryScreen(
                  dictionaryRepository: dependencies.dictionaryRepository,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.practice,
                builder: (context, state) => PracticeScreen(
                  flashcardRepository: dependencies.flashcardRepository,
                  highlightRepository: dependencies.highlightRepository,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => ProfileScreen(
                  authService: dependencies.authService,
                  subscriptionService: dependencies.subscriptionService,
                  // TODO: navigate to sign in flow.
                  onSignInPressed: () {},
                  onPremiumPressed: () => showSubscriptionPaywallSheet(
                    context,
                    subscriptionService: dependencies.subscriptionService,
                  ),
                ),
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
          onAddPressed: () async {
            await showImportFlowSheet(
              context,
              onImportBook: () async {
                // TODO: integrate file_picker + book import.
                // Return false until the flow can confirm a book was actually
                // added to the repository.
                return false;
              },
              onImportArticle: (url) => _importArticle(dependencies, url),
            );

            final books = await dependencies.bookRepository.getBooks();
            final articles = await dependencies.articleRepository.getArticles();

            return books.isNotEmpty || articles.isNotEmpty;
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

Future<bool> _importArticle(
  DependenciesContainer dependencies,
  String url,
) async {
  // This helper lives in routing as composition glue for the reusable import
  // flow and keeps the flow itself free from app-specific dependencies.
  // TODO: replace the current parser stub when the real article import
  // pipeline is connected.
  if (url.trim().isEmpty) {
    return false;
  }

  try {
    final parsed = await dependencies.articleParser.parse(url.trim());

    await dependencies.articleRepository.addArticle(
      title: parsed.title,
      url: url.trim(),
      cleanedHtml: parsed.cleanedHtml,
      siteName: parsed.siteName,
      coverImageUrl: parsed.coverImageUrl,
      estimatedWordCount: parsed.estimatedWordCount,
    );

    return true;
  } catch (_) {
    return false;
  }
}
