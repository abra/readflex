import 'dart:async' show Stream, unawaited;

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:connectivity_service/connectivity_service.dart'
    show ConnectivityScope, ConnectivityStatus;
import 'package:library_feature/library_feature.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/highlight.dart';
import 'package:import_flow/import_flow.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/screens/first_import_screen.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex/app/screens/splash_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// Bump when the book import terms text changes so users are asked to accept
// the updated terms before importing another local book.
const _currentBookImportTermsVersion = 1;
const _readflexTermsUrl = 'https://abra.github.io/readflex/terms/';
const _readflexPrivacyUrl = 'https://abra.github.io/readflex/privacy/';

/// App route paths used by screens and route redirects.
abstract final class AppRoutes {
  static const root = '/';
  static const splash = '/splash';
  static const library = '/library';
  static const onboarding = '/onboarding';
  static const firstImport = '/first-import';
  static const readerPath = '/reader/:sourceId';

  static String reader(String sourceId) => '/reader/$sourceId';
}

/// Builds the app router and wires app-level dependencies into route surfaces.
///
/// This file is intentionally the navigation composition root: routes may pass
/// repositories/services into Screen or Sheet entry points, while Views stay
/// isolated behind feature BLoCs/Cubits.
GoRouter buildRouter({required DependenciesContainer deps}) {
  deps.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    // Route transition / redirect logs are noisy — keep them on only in dev
    // builds so production logs stay focused on actual errors.
    debugLogDiagnostics: deps.config.isDev,
    initialLocation: AppRoutes.root,
    redirect: (context, state) {
      final location = state.uri.path;

      // Only entry routes need async redirect logic (onboarding /
      // first-import guards). Every other path returns null synchronously
      // so GoRouter finalises the route in one pass without an
      // intermediate build-destroy-rebuild cycle.
      if (location == AppRoutes.root) {
        return _resolveEntryRoute(deps);
      }

      if (location == AppRoutes.library) {
        return _redirectMainIfNeeded(deps);
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
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) {
          final isOffline =
              ConnectivityScope.of(context) == ConnectivityStatus.offline;
          return LibraryScreen(
            bookRepository: deps.bookRepository,
            articleRepository: deps.articleRepository,
            collectionRepository: deps.collectionRepository,
            preferencesService: deps.preferencesService,
            isOffline: isOffline,
            onSourcePressed: (source, {onSourceOpened}) => context.push(
              AppRoutes.reader(source.id),
              extra: _ReaderRouteExtra(
                initialSourceType: source.sourceType,
                onSourceOpened: onSourceOpened,
              ),
            ),
            onAddPressed: () async {
              await showImportFlowSheet(
                context,
                isOffline: isOffline,
                isOfflineStream: _isOfflineStream(deps),
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
              preferencesService: deps.preferencesService,
              screenControlService: deps.screenControlService,
              onSourceOpened: _onSourceOpenedFromRoute(state),
              onArticleTitlePressed: (url, title) {
                unawaited(_openArticleUrl(url));
              },
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
        builder: (context, state) {
          final isOffline =
              ConnectivityScope.of(context) == ConnectivityStatus.offline;
          return FirstImportScreen(
            onAddPressed: () async {
              // Trust the sheet's own result instead of probing the
              // library afterwards. The result is the canonical signal
              // that an import succeeded, and checking repositories would
              // have to scan rows to answer the same question.
              final result = await showImportFlowSheet(
                context,
                isOffline: isOffline,
                isOfflineStream: _isOfflineStream(deps),
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
              context.go(AppRoutes.library);
            },
            onSkipPressed: () {
              deps.preferencesService.update(
                (p) => p.copyWith(hasCompletedSetup: true),
              );
              context.go(AppRoutes.library);
            },
          );
        },
      ),
    ],
  );
}

Stream<bool> _isOfflineStream(DependenciesContainer deps) {
  // Bottom sheets can stay open after their route builder ran. Feed them a
  // stream so network-dependent actions react while the sheet is visible.
  return deps.connectivityService.statusStream
      .map((status) => status == ConnectivityStatus.offline)
      .distinct();
}

Future<void> _openArticleUrl(String rawUrl) => _openExternalUrl(rawUrl);

Future<void> _openExternalUrl(String rawUrl) async {
  // External links are best-effort UI actions: malformed URLs or launcher
  // failures should never break navigation or reader state.
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;

  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Failed to open URL: $rawUrl ($error)');
  }
}

/// GoRouter payload for opening the reader with source type and a post-open
/// refresh callback from the previous screen.
class _ReaderRouteExtra {
  const _ReaderRouteExtra({
    this.initialSourceType = SourceType.book,
    this.onSourceOpened,
  });

  final SourceType initialSourceType;
  final VoidCallback? onSourceOpened;
}

Book? _initialReaderSourceFromRoute(GoRouterState state) {
  // Optional fast path for routes that already have the loaded Book. Ignore it
  // if the payload does not match the path id to avoid opening stale content.
  final sourceId = state.pathParameters['sourceId'];
  final extra = state.extra;
  if (sourceId == null) return null;

  final source = switch (extra) {
    Book source => source,
    _ => null,
  };
  if (source?.id != sourceId) return null;
  return source;
}

SourceType _initialReaderSourceTypeFromRoute(GoRouterState state) {
  // Source type lives in route metadata because ReaderScreen handles both books
  // and article-backed reader books through the same route.
  return switch (state.extra) {
    _ReaderRouteExtra(:final initialSourceType) => initialSourceType,
    _ => SourceType.book,
  };
}

VoidCallback? _onSourceOpenedFromRoute(GoRouterState state) {
  // Library passes this callback so it can refresh "recently opened" state only
  // after the reader records a real open event.
  return switch (state.extra) {
    _ReaderRouteExtra(:final onSourceOpened) => onSourceOpened,
    _ => null,
  };
}

Future<Article?> _importArticleUrl(
  DependenciesContainer deps,
  String url, {
  void Function(ImportFlowArticleStage stage)? onStage,
}) async {
  // Adapter between the import feature contract and app services: the sheet
  // knows about stages/errors, while extraction/storage stay app dependencies.
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
  // Root route is only a decision point; users should land on a real screen.
  final redirect = await _redirectMainIfNeeded(deps);
  return redirect ?? AppRoutes.library;
}

Future<String?> _redirectMainIfNeeded(DependenciesContainer deps) async {
  // Startup guard for first-run flow. It is intentionally narrow so normal
  // navigation does not re-check storage on every route transition.
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
      // Storage failure during redirect — fall through to Library where the
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
