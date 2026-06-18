import 'dart:async' show unawaited;

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:library_feature/library_feature.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/highlight.dart';
import 'package:home/home.dart';
import 'package:import_flow/import_flow.dart';
import 'package:profile/profile.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/screens/first_import_screen.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex/app/screens/splash_screen.dart';
import 'package:readflex/app/screens/tab_container_screen.dart';
import 'package:source_details/source_details.dart';
import 'package:subscription_paywall/subscription_paywall.dart';
import 'package:url_launcher/url_launcher.dart';

const _currentBookImportTermsVersion = 1;
const _readflexTermsUrl = 'https://abra.github.io/readflex/terms/';
const _readflexPrivacyUrl = 'https://abra.github.io/readflex/privacy/';

abstract final class AppRoutes {
  static const root = '/';
  static const splash = '/splash';
  static const home = '/home';
  static const library = '/library';
  static const profile = '/profile';
  static const onboarding = '/onboarding';
  static const firstImport = '/first-import';
  static const sourceDetailsPath = '/source/:sourceId';
  static const readerPath = '/reader/:sourceId';

  static String sourceDetails(String sourceId) => '/source/$sourceId';
  static String reader(String sourceId) => '/reader/$sourceId';
}

GoRouter buildRouter({required DependenciesContainer deps}) {
  deps.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    // Route transition / redirect logs are noisy — keep them on only in dev
    // builds so production logs stay focused on actual errors.
    debugLogDiagnostics: deps.config.isDev,
    initialLocation: AppRoutes.root,
    redirect: (context, state) {
      final location = state.uri.path;

      // Only `/` and `/home` need async redirect logic (onboarding /
      // first-import guards). Every other path returns null synchronously
      // so GoRouter finalises the route in one pass without an
      // intermediate build-destroy-rebuild cycle.
      if (location == AppRoutes.root) {
        return _resolveEntryRoute(deps);
      }

      if (location == AppRoutes.home) {
        return _redirectHomeIfNeeded(deps);
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
                  highlightRepository: deps.highlightRepository,
                  fsrsRepository: deps.fsrsRepository,
                  onBookPressed: (book) => context.push(
                    AppRoutes.sourceDetails(book.id),
                    extra: LibrarySource.fromBook(book),
                  ),
                  // Practice is frozen at the app shell for now. Home keeps
                  // the callback contract because its dashboard is still a
                  // placeholder and may re-enable this surface later.
                  onPracticePressed: () {},
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => LibraryScreen(
                  bookRepository: deps.bookRepository,
                  articleRepository: deps.articleRepository,
                  collectionRepository: deps.collectionRepository,
                  preferencesService: deps.preferencesService,
                  onSourcePressed: (source, {onSourceOpened}) => context.push(
                    AppRoutes.sourceDetails(source.id),
                    extra: _SourceDetailsRouteExtra(
                      initialSource: source,
                      onSourceOpened: onSourceOpened,
                    ),
                  ),
                  onAddPressed: () async {
                    await showImportFlowSheet(
                      context,
                      onPickBookFile: pickBookFile,
                      onImportBook: (file, {onProgress}) => importBookFile(
                        sourceFile: file,
                        bookRepository: deps.bookRepository,
                        readerServerPort: deps.readerServer.port,
                        logger: deps.logger,
                        onProgress: onProgress,
                      ),
                      onImportArticle: (url, {onStage}) => _importArticleUrl(
                        deps,
                        url,
                        onStage: onStage,
                      ),
                      isBookImportTermsAccepted: () =>
                          deps.preferencesService.hasAcceptedBookImportTerms(
                            _currentBookImportTermsVersion,
                          ),
                      acceptBookImportTerms: () =>
                          deps.preferencesService.acceptBookImportTerms(
                            _currentBookImportTermsVersion,
                          ),
                      onOpenTerms: () => _openExternalUrl(_readflexTermsUrl),
                      onOpenPrivacy: () => _openExternalUrl(
                        _readflexPrivacyUrl,
                      ),
                    );
                  },
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
                  // Auth is still backed by NoopAuthService in composition;
                  // keep this stub until a real sign-in route or sheet exists.
                  onSignInPressed: () {},
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
        path: AppRoutes.sourceDetailsPath,
        builder: (context, state) {
          final sourceId = state.pathParameters['sourceId']!;
          final initialSource = _initialSourceFromRoute(state);
          final onSourceOpened = _onSourceOpenedFromRoute(state);
          return SourceDetailsScreen(
            sourceId: sourceId,
            initialSource: initialSource,
            bookRepository: deps.bookRepository,
            articleRepository: deps.articleRepository,
            highlightRepository: deps.highlightRepository,
            flashcardRepository: deps.flashcardRepository,
            dictionaryRepository: deps.dictionaryRepository,
            onReadPressed: (source, sourceType) async {
              await context.push(
                AppRoutes.reader(source.id),
                extra: _ReaderRouteExtra(
                  initialSource: source,
                  initialSourceType: sourceType,
                  onSourceOpened: onSourceOpened,
                ),
              );
            },
            onArticleTitlePressed: (url, title) {
              unawaited(_openArticleUrl(url));
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.readerPath,
        // fullscreenDialog: true disables the iOS left-edge back-swipe
        // gesture (CupertinoPageTransition gates that gesture on
        // !fullscreenDialog). Without this the gesture conflicts with
        // foliate-js page-turn swipes — a swipe at the left edge would
        // pop the reader instead of turning the page.
        pageBuilder: (context, state) {
          final sourceId = state.pathParameters['sourceId']!;
          final initialSource = _initialReaderSourceFromRoute(state);
          return MaterialPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: ReaderScreen(
              sourceId: sourceId,
              initialSource: initialSource,
              initialSourceType: _initialReaderSourceTypeFromRoute(state),
              serverPort: deps.readerServer.port,
              bookRepository: deps.bookRepository,
              articleRepository: deps.articleRepository,
              highlightRepository: deps.highlightRepository,
              dictionaryRepository: deps.dictionaryRepository,
              preferencesService: deps.preferencesService,
              screenControlService: deps.screenControlService,
              onSourceOpened: _onSourceOpenedFromRoute(state),
              initialSearchHistory:
                  deps.preferencesService.current.readerSearchHistory,
              onSearchHistoryChanged: (queries) {
                unawaited(
                  deps.preferencesService.update(
                    (prefs) => prefs.copyWith(readerSearchHistory: queries),
                  ),
                );
              },
              textActions: [
                HighlightAction(
                  highlightRepository: deps.highlightRepository,
                  fsrsRepository: deps.fsrsRepository,
                ),
              ],
            ),
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
            // Trust the sheet's own result instead of probing the
            // library afterwards. The result is the canonical signal
            // that an import succeeded, and checking repositories would
            // have to scan rows to answer the same question.
            final result = await showImportFlowSheet(
              context,
              onPickBookFile: pickBookFile,
              onImportBook: (file, {onProgress}) => importBookFile(
                sourceFile: file,
                bookRepository: deps.bookRepository,
                readerServerPort: deps.readerServer.port,
                logger: deps.logger,
                onProgress: onProgress,
              ),
              onImportArticle: (url, {onStage}) => _importArticleUrl(
                deps,
                url,
                onStage: onStage,
              ),
              isBookImportTermsAccepted: () =>
                  deps.preferencesService.hasAcceptedBookImportTerms(
                    _currentBookImportTermsVersion,
                  ),
              acceptBookImportTerms: () =>
                  deps.preferencesService.acceptBookImportTerms(
                    _currentBookImportTermsVersion,
                  ),
              onOpenTerms: () => _openExternalUrl(_readflexTermsUrl),
              onOpenPrivacy: () => _openExternalUrl(
                _readflexPrivacyUrl,
              ),
            );
            return result == ImportFlowResult.bookImported ||
                result == ImportFlowResult.articleImported;
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
    ],
  );
}

/// GoRouter payload for opening source details without reloading the source
/// before the first frame.
class _SourceDetailsRouteExtra {
  const _SourceDetailsRouteExtra({
    this.initialSource,
    this.onSourceOpened,
  });

  final LibrarySource? initialSource;
  final VoidCallback? onSourceOpened;
}

Future<void> _openArticleUrl(String rawUrl) => _openExternalUrl(rawUrl);

Future<void> _openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;

  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Failed to open URL: $rawUrl ($error)');
  }
}

/// GoRouter payload for opening the reader with a warm source and a post-open
/// refresh callback from the previous screen.
class _ReaderRouteExtra {
  const _ReaderRouteExtra({
    this.initialSource,
    this.initialSourceType = SourceType.book,
    this.onSourceOpened,
  });

  final Book? initialSource;
  final SourceType initialSourceType;
  final VoidCallback? onSourceOpened;
}

LibrarySource? _initialSourceFromRoute(GoRouterState state) {
  final sourceId = state.pathParameters['sourceId'];
  final extra = state.extra;
  if (sourceId == null) {
    return null;
  }

  final source = switch (extra) {
    LibrarySource source => source,
    Book source => LibrarySource.fromBook(source),
    Article source => LibrarySource.fromArticle(source),
    _SourceDetailsRouteExtra(:final initialSource) => initialSource,
    _ => null,
  };
  if (source?.id != sourceId) {
    return null;
  }
  return source;
}

Book? _initialReaderSourceFromRoute(GoRouterState state) {
  final sourceId = state.pathParameters['sourceId'];
  final extra = state.extra;
  if (sourceId == null) return null;

  final source = switch (extra) {
    Book source => source,
    _ReaderRouteExtra(:final initialSource) => initialSource,
    _ => null,
  };
  if (source?.id != sourceId) return null;
  return source;
}

SourceType _initialReaderSourceTypeFromRoute(GoRouterState state) {
  return switch (state.extra) {
    _ReaderRouteExtra(:final initialSourceType) => initialSourceType,
    _ => SourceType.book,
  };
}

VoidCallback? _onSourceOpenedFromRoute(GoRouterState state) {
  return switch (state.extra) {
    _SourceDetailsRouteExtra(:final onSourceOpened) => onSourceOpened,
    _ReaderRouteExtra(:final onSourceOpened) => onSourceOpened,
    _ => null,
  };
}

Future<Article?> _importArticleUrl(
  DependenciesContainer deps,
  String url, {
  void Function(ImportFlowArticleStage stage)? onStage,
}) async {
  final ExtractedArticle article;
  try {
    onStage?.call(ImportFlowArticleStage.fetching);
    article = await deps.articleExtractionService.extract(url);
  } on ArticleExtractionException catch (e) {
    throw ArticleImportException(e.message);
  }
  onStage?.call(ImportFlowArticleStage.saving);
  return deps.articleRepository.addExtractedArticle(article);
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
    try {
      final (books, articles) = await (
        deps.bookRepository.getBooks(),
        deps.articleRepository.getArticles(),
      ).wait;
      if (books.isEmpty && articles.isEmpty) {
        return AppRoutes.firstImport;
      }
    } catch (e, st) {
      // Storage failure during redirect — fall through to home where the
      // BLoC has its own error handling and can show a proper error state.
      deps.logger.warn(
        'redirect content check failed',
        error: e,
        stackTrace: st,
      );
      return null;
    }

    // User somehow has content already — mark setup as complete.
    await deps.preferencesService.update(
      (p) => p.copyWith(hasCompletedSetup: true),
    );
  }

  return null;
}
