import 'package:article_parser/article_parser.dart';
import 'package:content_library/content_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:flashcard/flashcard.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/highlight.dart';
import 'package:home/home.dart';
import 'package:import_flow/import_flow.dart';
import 'package:onboarding/onboarding.dart';
import 'package:practice/practice.dart';
import 'package:profile/profile.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/design_system_screen.dart';
import 'package:readflex/app/first_import_screen.dart';
import 'package:readflex/app/tab_container_screen.dart';
import 'package:splash/splash.dart';
import 'package:subscription_paywall/subscription_paywall.dart';
import 'package:translate/translate.dart';

abstract final class AppRoutes {
  static const root = '/';
  static const splash = '/splash';
  static const home = '/home';
  static const library = '/library';
  static const dictionary = '/dictionary';
  static const practice = '/practice';
  static const profile = '/profile';
  static const onboarding = '/onboarding';
  static const firstImport = '/first-import';
  static const designSystem = '/design-system';
  static const readerPath = '/reader/:sourceId';

  static String reader(String sourceId) => '/reader/$sourceId';
}

GoRouter buildRouter({required DependenciesContainer deps}) {
  deps.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    // Route transition / redirect logs are noisy — keep them on only in dev
    // builds so production logs stay focused on actual errors.
    debugLogDiagnostics: deps.config.isDev,
    initialLocation: AppRoutes.root,
    redirect: (context, state) async {
      final location = state.uri.path;

      if (location == AppRoutes.root) {
        return _resolveEntryRoute(deps);
      }

      if (location == AppRoutes.home) {
        final redirect = await _redirectHomeIfNeeded(deps);
        if (redirect != null) {
          return redirect;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(
          onReady: () => context.go(AppRoutes.root),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => TabContainerScreen(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => HomeScreen(
                  bookRepository: deps.bookRepository,
                  articleRepository: deps.articleRepository,
                  highlightRepository: deps.highlightRepository,
                  fsrsRepository: deps.fsrsRepository,
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
                  bookRepository: deps.bookRepository,
                  articleRepository: deps.articleRepository,
                  preferencesService: deps.preferencesService,
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
                      onImportArticle: (url) => _importArticle(deps, url),
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
                  dictionaryRepository: deps.dictionaryRepository,
                  fsrsRepository: deps.fsrsRepository,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.practice,
                builder: (context, state) => PracticeScreen(
                  fsrsRepository: deps.fsrsRepository,
                  flashcardRepository: deps.flashcardRepository,
                  highlightRepository: deps.highlightRepository,
                  dictionaryRepository: deps.dictionaryRepository,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => ProfileScreen(
                  authService: deps.authService,
                  subscriptionService: deps.subscriptionService,
                  preferencesService: deps.preferencesService,
                  // TODO: navigate to sign in flow.
                  onSignInPressed: () {},
                  onDesignSystemPressed: () => context.push(
                    AppRoutes.designSystem,
                  ),
                  onPremiumPressed: () => showSubscriptionPaywallSheet(
                    context,
                    subscriptionService: deps.subscriptionService,
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
            bookRepository: deps.bookRepository,
            articleRepository: deps.articleRepository,
            highlightRepository: deps.highlightRepository,
            textActions: [
              HighlightAction(highlightRepository: deps.highlightRepository),
              FlashcardAction(flashcardRepository: deps.flashcardRepository),
              TranslateAction(
                translationService: deps.translationService,
                dictionaryRepository: deps.dictionaryRepository,
              ),
            ],
            onCheckDueItems: (sourceId) async {
              final items = await deps.fsrsRepository.getDueItemsBySource(
                sourceId,
              );
              return items.length;
            },
            onStartMiniReview: (context, sourceId) {
              showMiniReviewSheet(
                context,
                sourceId: sourceId,
                fsrsRepository: deps.fsrsRepository,
                flashcardRepository: deps.flashcardRepository,
                highlightRepository: deps.highlightRepository,
                dictionaryRepository: deps.dictionaryRepository,
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onComplete: () {
            deps.preferencesService.update(
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
              onImportArticle: (url) => _importArticle(deps, url),
            );

            final books = await deps.bookRepository.getBooks();
            final articles = await deps.articleRepository.getArticles();

            return books.isNotEmpty || articles.isNotEmpty;
          },
          onContentAdded: () {
            deps.preferencesService.update(
              (p) => p.copyWith(hasCompletedSetup: true),
            );
            context.go(AppRoutes.home);
          },
          onSkipPressed: () {
            deps.preferencesService.update(
              (p) => p.copyWith(hasCompletedSetup: true),
            );
            context.go(AppRoutes.home);
          },
        ),
      ),
      // TODO: remove or gate behind isDev before production release.
      GoRoute(
        path: AppRoutes.designSystem,
        builder: (context, state) => const DesignSystemScreen(),
      ),
    ],
  );
}

Future<String> _resolveEntryRoute(DependenciesContainer deps) async {
  final redirect = await _redirectHomeIfNeeded(deps);
  return redirect ?? AppRoutes.home;
}

Future<String?> _redirectHomeIfNeeded(DependenciesContainer deps) async {
  final prefs = deps.preferencesService.current;

  if (!prefs.onboardingCompleted) {
    return AppRoutes.onboarding;
  }

  if (!prefs.hasCompletedSetup) {
    final books = await deps.bookRepository.getBooks();
    final articles = await deps.articleRepository.getArticles();
    if (books.isEmpty && articles.isEmpty) {
      return AppRoutes.firstImport;
    }

    // User somehow has content already — mark setup as complete.
    await deps.preferencesService.update(
      (p) => p.copyWith(hasCompletedSetup: true),
    );
  }

  return null;
}

Future<ArticleImportOutcome> _importArticle(
  DependenciesContainer dependencies,
  String url,
) async {
  // This helper lives in routing as composition glue between the import
  // flow feature (user-facing, knows nothing about parser/repo) and the
  // infrastructure it drives. It also acts as the translation layer from
  // infrastructure exceptions to user-facing ArticleImportFailureReason
  // categories.
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return const ArticleImportOutcome.failure(
      ArticleImportFailureReason.invalidUrl,
    );
  }

  final ParsedArticle parsed;
  try {
    parsed = await dependencies.articleParser.parse(trimmed);
  } on ArticleParserException catch (e, st) {
    dependencies.logger.warn(
      'Article parse failed for $trimmed (${e.reason})',
      error: e,
      stackTrace: st,
    );
    return ArticleImportOutcome.failure(_mapParserFailure(e.reason));
  } catch (e, st) {
    dependencies.logger.warn(
      'Article parse threw unexpectedly for $trimmed',
      error: e,
      stackTrace: st,
    );
    return const ArticleImportOutcome.failure(
      ArticleImportFailureReason.unknown,
    );
  }

  // TODO: download inline <img> assets to app documents and rewrite src to
  // local paths before persisting, so articles remain readable offline and
  // survive source pages removing/rotating images. Should live alongside
  // addArticle (repo owns both DB row and file-system assets, like book
  // files), with matching cleanup on article deletion.
  try {
    await dependencies.articleRepository.addArticle(
      title: parsed.title,
      url: trimmed,
      content: parsed.cleanedHtml,
      siteName: parsed.siteName,
      byline: parsed.byline,
      excerpt: parsed.excerpt,
      publishedTime: parsed.publishedTime,
      lang: parsed.lang,
      coverImageUrl: parsed.coverImageUrl,
      textLength: parsed.textLength,
      estimatedWordCount: parsed.estimatedWordCount,
    );
  } catch (e, st) {
    // Parser already produced a ParsedArticle, so anything failing here is
    // local storage / file IO. Dedicated bucket lets the sheet show
    // "couldn't save" rather than blaming the network.
    dependencies.logger.warn(
      'Article persist failed for $trimmed',
      error: e,
      stackTrace: st,
    );
    return const ArticleImportOutcome.failure(
      ArticleImportFailureReason.storage,
    );
  }

  return const ArticleImportOutcome.success();
}

ArticleImportFailureReason _mapParserFailure(ArticleParserFailure reason) {
  return switch (reason) {
    ArticleParserFailure.invalidUrl => ArticleImportFailureReason.invalidUrl,
    ArticleParserFailure.network => ArticleImportFailureReason.network,
    ArticleParserFailure.httpStatus => ArticleImportFailureReason.httpError,
    ArticleParserFailure.noContent =>
      ArticleImportFailureReason.noReadableContent,
  };
}
