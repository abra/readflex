import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:library_feature/library_feature.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

import 'package:preferences_service/preferences_service.dart';

/// The Library with its Practice entry, the Practice section and a review
/// session, in every visual profile.
///
/// Navigation flows pump the whole app; large-count coverage substitutes only
/// the Practice stats to avoid seeding a million review items.
void main() {
  setUpAll(loadUiFonts);

  for (final (name, profile, locale, size) in [
    ('phone', VisualProfile.phone, const Locale('en'), const Size(390, 844)),
    ('phoneRu', VisualProfile.phone, const Locale('ru'), const Size(390, 844)),
    ('dark', VisualProfile.dark, const Locale('en'), const Size(390, 844)),
    (
      'largeText',
      VisualProfile.largeText,
      const Locale('de'),
      const Size(320, 568),
    ),
    (
      'phoneRtl',
      VisualProfile.tabletRtl,
      const Locale('ar'),
      const Size(390, 844),
    ),
    (
      'landscape',
      VisualProfile.landscape,
      const Locale('en'),
      const Size(844, 390),
    ),
  ]) {
    Future<UiTestApp> createApp(WidgetTester tester) async {
      final app = await tester.runAsync(() => UiTestApp.create());
      addTearDown(app!.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app.preferencesService.update(
        (p) => p.copyWith(
          locale: locale,
          themeMode: profile.brightness == Brightness.dark
              ? AppThemeMode.dark
              : AppThemeMode.light,
        ),
      );
      return app;
    }

    /// One saved word and one highlight from the fixture book, both due.
    Future<void> seedPractice(UiTestApp app) async {
      await app.dictionaryRepository.addEntry(
        word: 'reading',
        translation: 'чтение',
        baseTranslation: 'чтение, читать',
        contextTranslation: 'Чтение — это тихий разговор.',
        pronunciation: 'ˈriːdɪŋ',
        partOfSpeech: 'noun',
        context: 'Reading is a quiet conversation with the page.',
        sourceId: app.book!.id,
        sourceType: SourceType.book,
        anchorText: 'reading',
        anchorCfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:7)',
      );
      await app.highlightRepository.addHighlight(
        sourceId: app.book!.id,
        sourceType: SourceType.book,
        text: 'A book is a dream you hold in your hands.',
        note: 'Opening line',
        cfiRange: 'epubcfi(/6/2!/4/4,/1:0,/1:40)',
        chapterTitle: 'Chapter One',
      );
    }

    Future<void> pump(
      WidgetTester tester,
      UiTestApp app,
      String location,
      bool Function() ready,
    ) async {
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widgetAt(location)),
      );
      await waitForUi(tester, ready, description: location);
      await tester.pumpAndSettle();
    }

    Future<void> snapshot(WidgetTester tester, String surface) async {
      expect(tester.takeException(), isNull, reason: '$name/$surface');
      await expectLater(
        find.byKey(goldenBoundary),
        matchesGoldenFile('goldens/$name/$surface.png'),
      );
      expect(tester.takeException(), isNull, reason: '$name/$surface');
    }

    testWidgets('library with cards due $name', (tester) async {
      final app = await createApp(tester);
      await seedPractice(app);
      await pump(
        tester,
        app,
        AppRoutes.library,
        () => find
            .byKey(const ValueKey('libraryPracticeRow'))
            .evaluate()
            .isNotEmpty,
      );
      await snapshot(tester, 'library-practice');
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('library with large card count $name', (tester) async {
      final app = await createApp(tester);
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => LibraryScreen(
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          collectionRepository: app.collectionRepository,
          preferencesService: app.preferencesService,
          fsrsRepository: _LargeCountFsrsRepository(),
          onSourcePressed: (
            _, {
            onSourceOpened,
            onReadingPositionSaved,
          }) async {},
          onAddPressed: ({
            required onImported,
            entry = LibraryImportEntry.menu,
          }) async {},
          onPracticePressed: () async {},
        ),
        surfaceSize: size,
        locale: locale,
      );
      final badge = find.byKey(const ValueKey('libraryPracticeBadge'));
      await waitForUi(
        tester,
        () => badge.evaluate().isNotEmpty,
        description: 'large Practice count',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: badge, matching: find.text('99+')),
        findsOneWidget,
      );
      final button = find.byKey(const ValueKey('libraryPracticeButton'));
      final l10n = ReadflexLocalizations.of(tester.element(button))!;
      final fullCount = l10n.practiceDueToday(_LargeCountFsrsRepository.count);
      expect(find.text(fullCount), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        expect(tester.getSemantics(button).value, fullCount);
      } finally {
        semantics.dispose();
      }
      await snapshot(tester, 'library-practice-large-count');
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('practice section $name', (tester) async {
      final app = await createApp(tester);
      await seedPractice(app);
      await pump(
        tester,
        app,
        AppRoutes.practice,
        () => find
            .byKey(const ValueKey('practiceTodayCard'))
            .evaluate()
            .isNotEmpty,
      );
      await snapshot(tester, 'practice');
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('practice settings sheet $name', (tester) async {
      final app = await createApp(tester);
      await seedPractice(app);
      await pump(
        tester,
        app,
        AppRoutes.practice,
        () => find
            .byKey(const ValueKey('practiceTodayCard'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('practiceSettingsButton')));
      await tester.pumpAndSettle();
      await snapshot(tester, 'practice-settings');
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('practice section with nothing saved $name', (tester) async {
      final app = await createApp(tester);
      await pump(
        tester,
        app,
        AppRoutes.practice,
        () => find
            .byKey(const ValueKey('practiceEmptyState'))
            .evaluate()
            .isNotEmpty,
      );
      await snapshot(tester, 'practice-empty');
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('review session word and highlight $name', (tester) async {
      final shadowsDisabled = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = shadowsDisabled);
      try {
        final app = await createApp(tester);
        await seedPractice(app);
        await pump(
          tester,
          app,
          AppRoutes.practiceReview,
          () => find.byKey(const ValueKey('reviewWord')).evaluate().isNotEmpty,
        );
        await snapshot(tester, 'review-word');
        await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
        await snapshot(tester, 'review-word-answer');
        await tapUi(tester, find.byKey(const ValueKey('reviewRate-good')));
        await waitForUi(
          tester,
          () => find.byKey(const ValueKey('reviewQuote')).evaluate().isNotEmpty,
          description: 'highlight card',
        );
        expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
        expect(find.byKey(const ValueKey('reviewRate-keep')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reviewRate-showLess')),
          findsOneWidget,
        );
        expect(find.text('Opening line'), findsOneWidget);
        await snapshot(tester, 'review-highlight-answer');
        await tapUi(tester, find.byKey(const ValueKey('reviewRate-keep')));
        await waitForUi(
          tester,
          () => find
              .byKey(const ValueKey('reviewSummaryTitle'))
              .evaluate()
              .isNotEmpty,
          description: 'summary',
        );
        await snapshot(tester, 'review-summary');
      } finally {
        debugDisableShadows = shadowsDisabled;
        await unmountUi(tester);
      }
    }, tags: ['golden']);
  }
}

class _LargeCountFsrsRepository implements FsrsRepository {
  static const count = 1000000;

  @override
  Future<ReviewStats> getStats() async => const ReviewStats(
    totalByType: {ReviewableType.dictionary: count},
    dueByType: {ReviewableType.dictionary: count},
  );

  @override
  Future<ReviewQueueStatus> getReviewQueueStatus({
    Set<ReviewableType>? types,
  }) async => ReviewQueueStatus(
    dueCount: types == null || types.contains(ReviewableType.dictionary)
        ? count
        : 0,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
