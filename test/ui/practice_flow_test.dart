import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// Library → Practice → back, through the real router and repositories.
void main() {
  late UiTestApp app;

  setUp(() async {
    app = await UiTestApp.create();
  });
  tearDown(() async => app.dispose());

  final row = find.byKey(const ValueKey('libraryPracticeRow'));
  final button = find.byKey(const ValueKey('libraryPracticeButton'));
  final badge = find.byKey(const ValueKey('libraryPracticeBadge'));

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app.widget);
    await waitForUi(
      tester,
      () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
      description: 'library contents',
    );
  }

  Future<void> saveWordAndHighlight() async {
    await app.dictionaryRepository.addEntry(
      word: 'power',
      translation: 'Strom',
      sourceId: app.book!.id,
      sourceType: SourceType.book,
      anchorText: 'power',
      anchorCfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:5)',
    );
    await app.highlightRepository.addHighlight(
      sourceId: app.book!.id,
      sourceType: SourceType.book,
      text: ReadingFixture.sentence,
      cfiRange: 'epubcfi(/6/2!/4/4,/1:0,/1:40)',
    );
  }

  testWidgets('before the first save only the capsule leads to Practice', (
    tester,
  ) async {
    await launch(tester);
    expect(row, findsNothing);
    expect(badge, findsNothing);

    await tapUi(tester, button);
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('practiceEmptyState')), findsOneWidget);
    expect(find.byKey(const ValueKey('practiceStartReview')), findsNothing);

    await tapUi(tester, find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsNothing);
    expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
    await unmountUi(tester);
  });

  testWidgets('after a session the Library shows the new counts', (
    tester,
  ) async {
    await launch(tester);
    await tester.runAsync(saveWordAndHighlight);
    // Saved while the Library was up: the entry appears on the next reload,
    // here the one that follows closing Practice.
    expect(row, findsNothing);

    await tapUi(tester, button);
    await waitForUi(
      tester,
      () =>
          find.byKey(const ValueKey('practiceTodayCard')).evaluate().isNotEmpty,
      description: 'practice hub',
    );
    await tapUi(tester, find.byKey(const ValueKey('practiceStartReview')));
    await waitForUi(
      tester,
      () => find.byKey(const ValueKey('reviewWord')).evaluate().isNotEmpty,
      description: 'first card',
    );
    await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
    await tapUi(tester, find.byKey(const ValueKey('reviewRate-good')));
    await waitForUi(
      tester,
      () => find.byKey(const ValueKey('reviewQuote')).evaluate().isNotEmpty,
      description: 'highlight card',
    );
    await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
    await tapUi(tester, find.byKey(const ValueKey('reviewRate-keep')));
    await waitForUi(
      tester,
      () => find
          .byKey(const ValueKey('reviewSummaryTitle'))
          .evaluate()
          .isNotEmpty,
      description: 'summary',
    );
    await tapUi(tester, find.byKey(const ValueKey('reviewDone')));
    expect(find.byType(PracticeScreen), findsOneWidget);
    await tapUi(tester, find.byType(AppBackButton));
    await tester.pumpAndSettle();

    await waitForUi(
      tester,
      () => row.evaluate().isNotEmpty,
      description: 'practice row after the session',
    );
    expect(
      find.descendant(of: row, matching: find.text('All caught up')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('1 word · 1 highlight')),
      findsOneWidget,
    );
    expect(badge, findsNothing);
    await unmountUi(tester);
  });
}
