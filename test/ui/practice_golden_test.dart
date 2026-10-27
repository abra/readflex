import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/routing.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// The Library with its Practice entry, the Practice section and a review
/// session, in every visual profile.
///
/// The app is pumped whole (router, real repositories) so each screen is
/// captured as the reader reaches it.
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
              ? ThemeMode.dark
              : ThemeMode.light,
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
      await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
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
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
