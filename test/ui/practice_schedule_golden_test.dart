import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/practice_word_sheet.dart';
import 'package:practice/src/review_due_label.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

final _deadline = DateTime(2026, 11, 7, 14, 35).toUtc();
final _fsrs = FsrsCardData(
  state: FsrsState.review,
  reps: 1,
  nextReviewAt: _deadline,
);

void main() {
  setUpAll(loadUiFonts);
  for (final (profile, size, locale, suffix) in [
    (VisualProfile.phone, const Size(390, 844), const Locale('en'), ''),
    (VisualProfile.phone, const Size(390, 844), const Locale('ru'), '-ru'),
    (VisualProfile.dark, const Size(390, 844), const Locale('en'), ''),
    (VisualProfile.largeText, const Size(320, 568), const Locale('de'), ''),
    (
      VisualProfile.tabletRtl,
      const Size(390, 844),
      const Locale('ar'),
      '-phone-rtl',
    ),
    (
      VisualProfile.tabletRtl,
      const Size(1280, 800),
      const Locale('ar'),
      '-tablet',
    ),
  ]) {
    testWidgets('stored Practice deadlines ${profile.name}$suffix', (
      tester,
    ) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final ids = (await tester.runAsync(() => _seed(app)))!;
      try {
        await pumpGoldenSurface(
          tester,
          profile,
          (_) => PracticeWordsScreen(
            dictionaryRepository: app.dictionaryRepository,
            fsrsRepository: app.fsrsRepository,
            bookRepository: app.bookRepository,
            articleRepository: app.articleRepository,
            onOpenInSource: (_, _) async {},
          ),
          surfaceSize: size,
          locale: locale,
        );
        final word = find.byKey(ValueKey('practiceWord-${ids.word}'));
        await waitForUi(
          tester,
          () => word.evaluate().isNotEmpty,
          description: 'scheduled word',
        );
        final label = reviewDueLabel(tester.element(word), _fsrs);
        final wordDate = find.descendant(of: word, matching: find.text(label));
        await tester.ensureVisible(wordDate);
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(wordDate).didExceedMaxLines,
          isFalse,
        );
        await expectUiGolden(tester, profile, 'practice-schedule-words$suffix');

        await tapUi(tester, wordDate);
        final detailsDate = find.descendant(
          of: find.byType(PracticeWordSheet),
          matching: find.text(label),
        );
        await tester.ensureVisible(detailsDate);
        await tester.pumpAndSettle();
        expect(detailsDate.hitTestable(), findsOneWidget);
        await expectUiGolden(
          tester,
          profile,
          'practice-schedule-details$suffix',
        );
        await unmountUi(tester);

        await pumpGoldenSurface(
          tester,
          profile,
          (_) => PracticeHighlightsScreen(
            highlightRepository: app.highlightRepository,
            fsrsRepository: app.fsrsRepository,
            bookRepository: app.bookRepository,
            articleRepository: app.articleRepository,
            onOpenInSource: (_) async {},
          ),
          surfaceSize: size,
          locale: locale,
        );
        final highlight = find.byKey(
          ValueKey('practiceHighlight-${ids.highlight}'),
        );
        await waitForUi(
          tester,
          () => highlight.evaluate().isNotEmpty,
          description: 'scheduled highlight',
        );
        final highlightDate = find.descendant(
          of: highlight,
          matching: find.text(reviewDueLabel(tester.element(highlight), _fsrs)),
        );
        await tester.ensureVisible(highlightDate);
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(highlightDate).didExceedMaxLines,
          isFalse,
        );
        await expectUiGolden(
          tester,
          profile,
          'practice-schedule-highlights$suffix',
        );
      } finally {
        await unmountUi(tester);
      }
    }, tags: ['golden']);
  }
}

Future<({String word, String highlight})> _seed(UiTestApp app) async {
  const sourceTitle =
      'A Reader’s Companion to Stories, Language, Memory and the Art of Learning';
  await app.database.booksDao.updateBook(
    BooksTableCompanion(
      id: Value(app.book!.id),
      title: const Value(sourceTitle),
    ),
  );
  final word = await app.dictionaryRepository.addEntry(
    word: 'reading',
    translation: 'чтение',
    context: 'Reading is a quiet conversation with the page.',
    sourceId: app.book!.id,
    sourceType: SourceType.book,
    addedAt: DateTime(2026, 1, 2),
  );
  await app.dictionaryRepository.addEntry(
    word: 'stillness',
    translation: 'тишина',
    sourceId: app.book!.id,
    sourceType: SourceType.book,
    addedAt: DateTime(2026, 1, 1),
  );
  final highlight = await app.highlightRepository.addHighlight(
    sourceId: app.book!.id,
    sourceType: SourceType.book,
    text: 'A book is a dream you hold in your hands.',
    note: 'Opening line',
    chapterTitle: 'Chapter One: A Quiet Conversation with Stories and Memory',
    cfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:42)',
  );
  for (final (id, type) in [
    (word.id, ReviewableType.dictionary),
    (highlight.id, ReviewableType.highlight),
  ]) {
    await app.database.reviewItemsDao.upsertItem(
      ReviewItemsTableCompanion(
        itemId: Value(id),
        itemType: Value(type.toStorageString()),
        fsrsState: const Value('review'),
        reps: const Value(1),
        nextReviewAt: Value(_deadline.toIso8601String()),
      ),
    );
  }
  return (word: word.id, highlight: highlight.id);
}
