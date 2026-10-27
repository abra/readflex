import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/practice_item.dart';
import 'package:practice/src/review_session_bloc.dart';

import 'helpers/practice_harness.dart';

void main() {
  late PracticeHarness h;

  setUp(() async => h = await PracticeHarness.create());
  tearDown(() => h.dispose());

  ReviewSessionBloc bloc({String? sourceId, bool ahead = false}) =>
      ReviewSessionBloc(
        fsrsRepository: h.fsrs,
        dictionaryRepository: h.dictionary,
        highlightRepository: h.highlights,
        bookRepository: h.books,
        articleRepository: h.articles,
        preferencesService: h.preferences,
        sourceId: sourceId,
        ahead: ahead,
      );

  Future<ReviewSessionState> start(ReviewSessionBloc b) async {
    b.add(const ReviewSessionStarted());
    await b.stream.firstWhere((s) => s.status != ReviewSessionStatus.loading);
    return b.state;
  }

  Future<ReviewSessionState> rate(ReviewSessionBloc b, Rating rating) async {
    final before = b.state;
    b.add(ReviewSessionCardRated(rating));
    await b.stream.firstWhere((s) => s != before);
    return b.state;
  }

  test('no due cards: empty', () async {
    final b = bloc();
    addTearDown(b.close);

    expect((await start(b)).status, ReviewSessionStatus.empty);
  });

  test('queues due words and highlights with intervals', () async {
    await h.addBook('b1', title: 'Dune');
    await h.addWord('spice', sourceId: 'b1', context: 'The spice must flow.');
    await h.addHighlight('b1', 'A quote');
    final b = bloc();
    addTearDown(b.close);

    final state = await start(b);

    expect(state.status, ReviewSessionStatus.reviewing);
    expect(state.items.length, 2);
    expect(state.current, isA<PracticeWordItem>());
    expect(state.intervals.keys, containsAll(Rating.values));
    expect(state.revealed, isFalse);
  });

  test('rating records the review and advances; Again is collected', () async {
    await h.addBook('b1');
    final word = await h.addWord('a', sourceId: 'b1');
    final other = await h.addWord('b', sourceId: 'b1');
    final b = bloc();
    addTearDown(b.close);
    await start(b);

    b.add(const ReviewSessionAnswerRevealed());
    await b.stream.first;
    expect(b.state.revealed, isTrue);

    var state = await rate(b, Rating.again);
    expect(state.index, 1);
    expect(state.revealed, isFalse);
    expect(state.again.single.itemId, word.id);
    expect((await h.fsrs.getReviewState(word.id))!.reps, 1);

    state = await rate(b, Rating.good);
    expect(state.status, ReviewSessionStatus.completed);
    expect(state.reviewed, 2);
    expect(state.known, 1);
    expect((await h.fsrs.getReviewState(other.id))!.state, FsrsState.review);

    b.add(const ReviewSessionAgainRequested());
    await b.stream.first;
    expect(b.state.status, ReviewSessionStatus.reviewing);
    expect(b.state.items.single.itemId, word.id);
    expect(b.state.ratings, isEmpty);
  });

  test('removing the current card deletes its review row', () async {
    await h.addBook('b1');
    final word = await h.addWord('a', sourceId: 'b1');
    await h.addWord('b', sourceId: 'b1');
    final b = bloc();
    addTearDown(b.close);
    await start(b);

    b.add(const ReviewSessionCardRemoved());
    await b.stream.first;

    expect(b.state.items.length, 1);
    expect(b.state.current?.itemId, isNot(word.id));
    expect(await h.fsrs.getReviewState(word.id), isNull);
  });

  test('honours the daily new-card limit and the highlights setting', () async {
    await h.addBook('b1');
    for (var i = 0; i < 5; i++) {
      await h.addWord('w$i', sourceId: 'b1');
    }
    await h.addHighlight('b1', 'Quote');
    await h.preferences.update(
      (p) => p.copyWith(
        practiceNewCardsPerDay: 3,
        practiceReviewHighlights: false,
      ),
    );
    final b = bloc();
    addTearDown(b.close);

    final state = await start(b);

    expect(state.items.length, 3);
    expect(state.items.every((i) => i is PracticeWordItem), isTrue);
  });

  test('a source session only takes that source', () async {
    await h.addBook('b1');
    await h.addBook('b2');
    await h.addWord('a', sourceId: 'b1');
    await h.addWord('b', sourceId: 'b2');
    final b = bloc(sourceId: 'b2');
    addTearDown(b.close);

    final state = await start(b);

    expect(state.items.single.sourceId, 'b2');
  });

  test('ahead reviews the cards due soonest when nothing is due', () async {
    await h.addBook('b1');
    final soon = await h.addWord('soon', sourceId: 'b1');
    final later = await h.addWord('later', sourceId: 'b1');
    await h.review(soon.id, ReviewableType.dictionary, Rating.hard);
    await h.review(later.id, ReviewableType.dictionary, Rating.easy);
    expect((await start(bloc())).status, ReviewSessionStatus.empty);
    final b = bloc(ahead: true);
    addTearDown(b.close);

    final state = await start(b);

    expect(state.status, ReviewSessionStatus.reviewing);
    expect(state.items.map((i) => i.itemId), [soon.id, later.id]);
  });
}
