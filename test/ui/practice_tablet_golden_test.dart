import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// Tablet Practice uses the production router and repositories throughout:
/// start a session, reveal and rate both items, then return to the refreshed hub.
void main() {
  setUpAll(loadUiFonts);

  for (final (profile, size, name, scale) in const [
    (VisualProfile.phone, Size(800, 1280), 'portrait-800', 1.0),
    (VisualProfile.tabletRtl, Size(1280, 800), 'landscape-1280', 1.0),
    (VisualProfile.phone, Size(1032, 1376), 'portrait', 1.0),
    (VisualProfile.phone, Size(1376, 1032), 'landscape', 1.0),
    (VisualProfile.tabletRtl, Size(1376, 1032), 'landscape', 1.0),
    (
      VisualProfile.tabletRtl,
      Size(1280, 800),
      'landscape-1280-large-text',
      2.0,
    ),
    (
      VisualProfile.largeText,
      Size(800, 1280),
      'portrait-800-large-text',
      2.0,
    ),
  ]) {
    testWidgets('tablet Practice flow ${profile.name} $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      await tester.runAsync(() async {
        await app.preferencesService.update(
          (preferences) => preferences.copyWith(
            locale: profile.locale,
            themeMode: profile.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
          ),
        );
        await _seedPractice(app);
      });

      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: goldenBoundary,
            child: app.widgetAt(AppRoutes.practice),
          ),
        );
        final wide = AppWindowSize.isWideSize(size) && scale <= 1.5;
        final workspaceKey = wide ? 'practiceWideWorkspace' : 'practiceContent';
        await waitForUi(
          tester,
          () => find.byKey(ValueKey(workspaceKey)).evaluate().isNotEmpty,
          description: 'tablet Practice hub',
        );
        await tester.pumpAndSettle();

        final workspace = tester.getRect(
          find.byKey(ValueKey(workspaceKey)),
        );
        final today = tester.getRect(find.byType(PracticeTodayCard));
        final collection = tester.getRect(
          find.byKey(const ValueKey('practiceWords')),
        );
        final start = find.byKey(const ValueKey('practiceStartReview'));
        expect(workspace.width, lessThanOrEqualTo(1200));
        expect(workspace.center.dx, closeTo(size.width / 2, .01));
        if (!wide) {
          expect(tester.getRect(start).top, greaterThan(collection.bottom));
        } else if (profile.locale.languageCode == 'ar') {
          expect(today.contains(tester.getCenter(start)), isTrue);
          expect(today.left, greaterThan(collection.right));
        } else {
          expect(today.contains(tester.getCenter(start)), isTrue);
          expect(today.right, lessThan(collection.left));
        }
        await expectUiGolden(
          tester,
          profile,
          'tablet-practice-hub-$name',
        );

        await tapUi(tester, start);
        await waitForUi(
          tester,
          () => find.byKey(const ValueKey('reviewWord')).evaluate().isNotEmpty,
          description: 'tablet word question',
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReviewSessionScreen), findsOneWidget);
        final card = tester.getRect(
          find.byKey(const ValueKey('reviewStudyCard')),
        );
        final reveal = tester.getRect(
          find.byKey(const ValueKey('reviewShowAnswer')),
        );
        expect(card.width, lessThanOrEqualTo(640));
        expect(card.center.dx, closeTo(size.width / 2, .01));
        expect(reveal.left, closeTo(card.left, .01));
        expect(reveal.right, closeTo(card.right, .01));
        expect(reveal.height, greaterThanOrEqualTo(48));
        expect(reveal.bottom, greaterThan(size.height - 100));
        await expectUiGolden(
          tester,
          profile,
          'tablet-practice-review-word-$name',
        );

        await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
        expect(find.byKey(const ValueKey('reviewAnswer')), findsOneWidget);
        final ratings = [
          for (final name in ['again', 'hard', 'good'])
            tester.getRect(find.byKey(ValueKey('reviewRate-$name'))),
        ];
        expect(
          ratings.map((rect) => rect.left).reduce(math.min),
          closeTo(card.left, .01),
        );
        expect(
          ratings.map((rect) => rect.right).reduce(math.max),
          closeTo(card.right, .01),
        );
        for (final rating in ratings) {
          expect(rating.height, greaterThanOrEqualTo(48));
          expect(rating.bottom, lessThanOrEqualTo(size.height));
        }
        await expectUiGolden(
          tester,
          profile,
          'tablet-practice-review-answer-$name',
        );

        await tapUi(tester, find.byKey(const ValueKey('reviewRate-good')));
        await waitForUi(
          tester,
          () => find.byKey(const ValueKey('reviewQuote')).evaluate().isNotEmpty,
          description: 'tablet highlight question',
        );
        await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
        expect(find.text('Opening line'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('reviewStudyCard'))).width,
          lessThanOrEqualTo(640),
        );
        await expectUiGolden(
          tester,
          profile,
          'tablet-practice-review-highlight-$name',
        );

        await tapUi(tester, find.byKey(const ValueKey('reviewRate-keep')));
        await waitForUi(
          tester,
          () => find
              .byKey(const ValueKey('reviewSummaryTitle'))
              .evaluate()
              .isNotEmpty,
          description: 'tablet review summary',
        );
        await tester.pumpAndSettle();
        final summary = tester.getRect(
          find.byKey(const ValueKey('reviewSummaryCard')),
        );
        final done = find.byKey(const ValueKey('reviewDone'));
        expect(summary.width, lessThanOrEqualTo(480));
        expect(summary.center.dx, closeTo(size.width / 2, .01));
        expect(summary.contains(tester.getCenter(done)), isTrue);
        await expectUiGolden(
          tester,
          profile,
          'tablet-practice-summary-$name',
        );

        await tapUi(tester, done);
        final due = find.byKey(const ValueKey('practiceTodayDue'));
        await waitForUi(
          tester,
          () {
            if (find.byType(ReviewSessionScreen).evaluate().isNotEmpty ||
                due.evaluate().isEmpty) {
              return false;
            }
            final l10n = ReadflexLocalizations.of(tester.element(due))!;
            return tester.widget<Text>(due).data == l10n.practiceCaughtUp;
          },
          description: 'refreshed tablet Practice hub after Done',
        );
        expect(find.byType(PracticeScreen), findsOneWidget);
        expect(start, findsOneWidget);
        final stats = (await tester.runAsync(app.fsrsRepository.getStats))!;
        expect(stats.total, 2);
        expect(stats.due, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await unmountUi(tester);
      }
    }, tags: ['golden']);
  }
}

/// Matches the word/highlight content in practice_golden_test.dart so phone and
/// tablet captures compare layout with the same saved material.
Future<void> _seedPractice(UiTestApp app) async {
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
