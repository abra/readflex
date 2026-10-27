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

  test('backfills review rows for highlights saved without them', () async {
    await h.addBook('b1');
    final highlight = await h.addHighlight('b1', 'Old');
    await h.database.reviewItemsDao.deleteItemsByIds([highlight.id]);
    final b = bloc();
    addTearDown(b.close);

    final state = await load(b);

    expect(state.stats.totalOf(ReviewableType.highlight), 1);
    expect(await h.fsrs.getReviewState(highlight.id), isNotNull);
  });

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
  });
}
