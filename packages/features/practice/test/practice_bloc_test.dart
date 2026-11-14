import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/practice_bloc.dart';

import 'helpers/practice_harness.dart';

void main() {
  late PracticeHarness h;

  setUp(() async => h = await PracticeHarness.create());
  tearDown(() => h.dispose());

  PracticeBloc bloc() => PracticeBloc(
    fsrsRepository: h.fsrs,
    dictionaryRepository: h.dictionary,
    highlightRepository: h.highlights,
    bookRepository: h.books,
    articleRepository: h.articles,
    preferencesService: h.preferences,
  );

  Future<PracticeState> load(PracticeBloc b) async {
    b.add(const PracticeLoadRequested());
    await b.stream.firstWhere((s) => s.status != PracticeStatus.loading);
    return b.state;
  }

  test('nothing saved: ready with nothing to practice', () async {
    final b = bloc();
    addTearDown(b.close);

    final state = await load(b);

    expect(state.status, PracticeStatus.ready);
    expect(state.hasNothing, isTrue);
    expect(state.due, 0);
    expect(state.sources, isEmpty);
  });

  test('counts words and highlights, groups them by source', () async {
    await h.addBook('b1', title: 'Dune');
    await h.addBook('b2', title: 'Emma');
    await h.addWord('spice', sourceId: 'b1');
    await h.addWord('sand', sourceId: 'b1');
    await h.addWord('tea', sourceId: 'b2');
    final kept = await h.addHighlight('b2', 'A quote');
    await h.review(kept.id, ReviewableType.highlight, Rating.good);
    final b = bloc();
    addTearDown(b.close);

    final state = await load(b);

    expect(state.total, 4);
    expect(state.due, 3);
    expect(state.stats.dueOf(ReviewableType.dictionary), 3);
    expect(state.sources.map((s) => s.source.title), ['Dune', 'Emma']);
    expect(state.sources.first.words, 2);
    expect(state.sources.first.due, 2);
    expect(state.sources.last.highlights, 1);
    expect(state.sources.last.due, 1);
  });

  test(
    'loading the hub does not recreate a removed highlight review row',
    () async {
      await h.addBook('b1');
      final highlight = await h.addHighlight('b1', 'Old');
      await h.database.reviewItemsDao.deleteItemsByIds([highlight.id]);
      final b = bloc();
      addTearDown(b.close);

      final state = await load(b);

      expect(state.stats.totalOf(ReviewableType.highlight), 0);
      expect(state.sources.single.highlights, 1);
      expect(await h.fsrs.getReviewState(highlight.id), isNull);
    },
  );

  test('highlights leave the due count when the setting is off', () async {
    await h.addBook('b1');
    await h.addHighlight('b1', 'Quote');
    await h.addWord('w', sourceId: 'b1');
    await h.preferences.update(
      (p) => p.copyWith(practiceReviewHighlights: false),
    );
    final b = bloc();
    addTearDown(b.close);

    final state = await load(b);

    expect(state.reviewHighlights, isFalse);
    expect(state.due, 1);
    expect(state.total, 2);
    expect(state.sources.single.due, 1);
  });

  for (final reviewHighlights in [false, true]) {
    test('hub and By book use the same active review types: '
        'highlights=$reviewHighlights', () async {
      await h.addBook('mixed', title: 'Mixed');
      await h.addBook('quotes', title: 'Quotes');
      await h.addWord('word', sourceId: 'mixed');
      await h.addHighlight('mixed', 'Mixed quote');
      await h.addHighlight('quotes', 'Only quote');
      await h.fsrs.createReviewItem(
        itemId: 'legacy-card',
        itemType: ReviewableType.flashcard,
        sourceId: 'mixed',
      );
      await h.preferences.update(
        (preferences) => preferences.copyWith(
          practiceReviewHighlights: reviewHighlights,
        ),
      );
      final b = bloc();
      addTearDown(b.close);

      final state = await load(b);
      final mixed = state.sources.singleWhere((s) => s.source.id == 'mixed');
      final quotes = state.sources.singleWhere((s) => s.source.id == 'quotes');

      expect(state.due, reviewHighlights ? 3 : 1);
      expect(mixed.due, reviewHighlights ? 2 : 1);
      expect(quotes.due, reviewHighlights ? 1 : 0);
      expect(
        state.sources.fold(0, (sum, source) => sum + source.due),
        state.due,
      );
      // Disabling review leaves the saved-content collections available.
      expect(state.total, 3);
      expect(mixed.highlights, 1);
      expect(quotes.highlights, 1);
    });
  }
}
