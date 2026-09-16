import 'dart:async' show Stream, unawaited;

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:connectivity_service/connectivity_service.dart'
    show ConnectivityScope, ConnectivityStatus;
import 'package:library_feature/library_feature.dart';
import 'package:domain_models/domain_models.dart';
import 'package:dictionary/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/highlight.dart';
import 'package:import_flow/import_flow.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/app_system_ui_mode.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:translate/translate.dart';
import 'package:url_launcher/url_launcher.dart';

// Bump when the book import terms text changes so users are asked to accept
// the updated terms before importing another local book.
const _currentBookImportTermsVersion = 1;
const _readflexTermsUrl = 'https://abra.github.io/readflex/terms/';
const _readflexPrivacyUrl = 'https://abra.github.io/readflex/privacy/';

/// App route paths used by screens and route redirects.
abstract final class AppRoutes {
  static const root = '/';
  static const library = '/library';
  static const onboarding = '/onboarding';
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

      // Only entry routes need redirect logic. Every other path returns null
      // synchronously so GoRouter finalises the route in one pass without an
      // intermediate build-destroy-rebuild cycle.
      if (location == AppRoutes.root) {
        return _resolveEntryRoute(deps);
      }

      if (location == AppRoutes.library) {
        return _redirectLibraryIfNeeded(deps);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      _buildLibraryRoute(deps),
      _buildReaderRoute(deps),
      _buildOnboardingRoute(deps),
    ],
  );
}

GoRoute _buildLibraryRoute(DependenciesContainer deps) => GoRoute(
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
        extra: ReaderRouteArguments(onSourceOpened: onSourceOpened),
      ),
      onAddPressed: ({required onImported}) => _showImportSheet(
        context,
        deps,
        isOffline: isOffline,
        onImported: onImported,
      ),
    );
  },
);

GoRoute _buildReaderRoute(DependenciesContainer deps) => GoRoute(
  path: AppRoutes.readerPath,
  // fullscreenDialog: true disables the iOS left-edge back-swipe
  // gesture (CupertinoPageTransition gates that gesture on
  // !fullscreenDialog). Without this the gesture conflicts with
  // foliate-js page-turn swipes — a swipe at the left edge would
  // pop the reader instead of turning the page.
  pageBuilder: (context, state) {
    final sourceId = state.pathParameters['sourceId']!;
    final arguments = switch (state.extra) {
      ReaderRouteArguments arguments => arguments,
      _ => const ReaderRouteArguments(),
    };
    final initialSource = arguments.initialSource;
    final matchingSource = initialSource?.id == sourceId ? initialSource : null;
    return CustomTransitionPage(
      key: state.pageKey,
      fullscreenDialog: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, _, _, child) => child,
      child: _withReaderSystemNavigationBarMode(
        child: ReaderScreen(
          sourceId: sourceId,
          initialSource: matchingSource,
          serverBaseUri: deps.readerServer.baseUri,
          bookRepository: deps.bookRepository,
          articleRepository: deps.articleRepository,
          highlightRepository: deps.highlightRepository,
          preferencesService: deps.preferencesService,
          screenControlService: deps.screenControlService,
          onSourceOpened: arguments.onSourceOpened,
          onArticleTitlePressed: (url, title) {
            unawaited(_openExternalUrl(url));
          },
          onExternalLink: (url) {
            unawaited(_openExternalUrl(url));
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
            CopyTextAction(),
            TranslateAction(
              translationService: deps.contextualTranslationService,
              preferencesService: deps.preferencesService,
            ),
            DictionaryAction(
              systemDictionaryService: deps.systemDictionaryService,
              dictionaryLookupService: deps.dictionaryLookupService,
            ),
          ],
        ),
      ),
    );
  },
);

GoRoute _buildOnboardingRoute(DependenciesContainer deps) => GoRoute(
  path: AppRoutes.onboarding,
  builder: (context, state) => OnboardingScreen(
    onComplete: () {
      deps.preferencesService.update(
        (p) => p.copyWith(onboardingCompleted: true),
      );
      context.go(AppRoutes.library);
    },
  ),
);

Future<void> _showImportSheet(
  BuildContext context,
  DependenciesContainer deps, {
  required bool isOffline,
  required VoidCallback onImported,
}) async {
  await showImportFlowSheet(
    context,
    isOffline: isOffline,
    isOfflineStream: _isOfflineStream(deps),
    onPickBookFile: pickBookFile,
    onImportBook: (file, {onProgress}) async {
      final grant = await deps.readerServer.grantTemporaryBookAccess(file);
      try {
        final book = await importBookFile(
          sourceFile: file,
          bookRepository: deps.bookRepository,
          readerServerBaseUri: deps.readerServer.baseUri,
          logger: deps.logger,
          onProgress: onProgress,
        );
        if (book != null) onImported();
        return book;
      } finally {
        grant.revoke();
      }
    },
    onImportArticle: (url, {onStage}) async {
      final article = await _importArticleUrl(
        deps,
        url,
        onStage: onStage,
      );
      onImported();
      return article;
    },
    isBookImportTermsAccepted: () =>
        deps.preferencesService.hasAcceptedBookImportTerms(
          _currentBookImportTermsVersion,
        ),
    acceptBookImportTerms: () => deps.preferencesService.acceptBookImportTerms(
      _currentBookImportTermsVersion,
    ),
    onOpenTerms: () => _openExternalUrl(_readflexTermsUrl),
    onOpenPrivacy: () => _openExternalUrl(
      _readflexPrivacyUrl,
    ),
  );
}

/// Returns an offline flag stream for sheets that can outlive their route
/// builder and must react while they remain visible.
Stream<bool> _isOfflineStream(DependenciesContainer deps) {
  return deps.connectivityService.statusStream
      .map((status) => status == ConnectivityStatus.offline)
      .distinct();
}

/// Reader uses the full screen for content. On Android devices configured with
/// three-button navigation, hiding only the bottom system overlay keeps those
/// buttons from covering the reading area while leaving the app status bar
/// policy unchanged.
Widget _withReaderSystemNavigationBarMode({required Widget child}) {
  if (defaultTargetPlatform != TargetPlatform.android) return child;
  return AppBottomSystemOverlayVisibility(visible: false, child: child);
}

/// Opens an external HTTP(S) URL without letting launcher failures affect app
/// navigation or reader state.
Future<void> _openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;

  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Failed to open URL: $rawUrl ($error)');
  }
}

/// Optional reader arguments. The path ID remains authoritative, including
/// when opening a deep link without any payload.
class ReaderRouteArguments {
  const ReaderRouteArguments({this.initialSource, this.onSourceOpened});

  final Book? initialSource;
  final VoidCallback? onSourceOpened;
}

/// Adapts the import sheet contract to article extraction and storage services.
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

/// Resolves the root route into the first concrete screen the user should see.
String _resolveEntryRoute(DependenciesContainer deps) =>
    _redirectLibraryIfNeeded(deps) ?? AppRoutes.library;

/// Applies first-run redirects without rechecking storage on every normal route
/// transition.
String? _redirectLibraryIfNeeded(DependenciesContainer deps) {
  final prefs = deps.preferencesService.current;

  if (!prefs.onboardingCompleted) {
    return AppRoutes.onboarding;
  }

  return null;
}
