// Cross-package contract: saving a reviewable item and registering it with
// FSRS must result in the item appearing in the FSRS due queue for its
// source. Regressions in DB mapping, ReviewableType serialization, or
// `dueItems` SQL would be invisible to per-package unit tests with fakes.

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late HighlightRepository highlights;
  late FlashcardRepository flashcards;
  late DictionaryRepository dictionary;
  late FsrsRepository fsrs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    highlights = HighlightRepository(database: db);
    flashcards = FlashcardRepository(database: db);
    dictionary = DictionaryRepository(database: db);
    fsrs = FsrsRepository(database: db);
  });

  tearDown(() => db.close());

  test('highlight save -> FSRS due queue contains it', () async {
    const sourceId = 'book-1';

    final highlight = await highlights.addHighlight(
      sourceId: sourceId,
      sourceType: SourceType.book,
      text: 'selected text',
    );
    await fsrs.createReviewItem(
      itemId: highlight.id,
      itemType: ReviewableType.highlight,
      sourceId: sourceId,
    );

    final due = await fsrs.getDueItemsBySource(sourceId);

    expect(due, hasLength(1));
    expect(due.single.itemId, highlight.id);
    expect(due.single.itemType, ReviewableType.highlight);
    expect(due.single.sourceId, sourceId);
  });

  test('flashcard save -> FSRS due queue contains it', () async {
    const deckId = 'book-2';

    final card = await flashcards.addFlashcard(
      deckId: deckId,
      front: 'Q',
      back: 'A',
    );
    await fsrs.createReviewItem(
      itemId: card.id,
      itemType: ReviewableType.flashcard,
      sourceId: deckId,
    );

    final due = await fsrs.getDueItemsBySource(deckId);

    expect(due, hasLength(1));
    expect(due.single.itemId, card.id);
    expect(due.single.itemType, ReviewableType.flashcard);
  });

  test('dictionary entry save -> FSRS due queue contains it', () async {
    const sourceId = 'book-2';

    final entry = await dictionary.addEntry(
      word: 'serendipity',
      translation: 'случайная удача',
      sourceId: sourceId,
      sourceType: SourceType.book,
    );
    await fsrs.createReviewItem(
      itemId: entry.id,
      itemType: ReviewableType.dictionary,
      sourceId: sourceId,
    );

    final due = await fsrs.getDueItemsBySource(sourceId);

    expect(due, hasLength(1));
    expect(due.single.itemId, entry.id);
    expect(due.single.itemType, ReviewableType.dictionary);
  });

  test('type filter only returns matching ReviewableType', () async {
    const sourceId = 'book-3';

    final highlight = await highlights.addHighlight(
      sourceId: sourceId,
      sourceType: SourceType.book,
      text: 'h',
    );
    final card = await flashcards.addFlashcard(
      deckId: sourceId,
      front: 'q',
      back: 'a',
    );
    await fsrs.createReviewItem(
      itemId: highlight.id,
      itemType: ReviewableType.highlight,
      sourceId: sourceId,
    );
    await fsrs.createReviewItem(
      itemId: card.id,
      itemType: ReviewableType.flashcard,
      sourceId: sourceId,
    );

    final onlyHighlights = await fsrs.getDueItemsBySource(
      sourceId,
      type: ReviewableType.highlight,
    );
    final onlyFlashcards = await fsrs.getDueItemsBySource(
      sourceId,
      type: ReviewableType.flashcard,
    );

    expect(onlyHighlights.single.itemId, highlight.id);
    expect(onlyFlashcards.single.itemId, card.id);
  });

  test('items from other sources are not returned', () async {
    final highlight = await highlights.addHighlight(
      sourceId: 'book-A',
      sourceType: SourceType.book,
      text: 'h',
    );
    await fsrs.createReviewItem(
      itemId: highlight.id,
      itemType: ReviewableType.highlight,
      sourceId: 'book-A',
    );

    final dueForOther = await fsrs.getDueItemsBySource('book-B');

    expect(dueForOther, isEmpty);
  });
}
