import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:practice/src/practice_item.dart';
import 'package:practice/src/review_session_bloc.dart';

import 'helpers/practice_harness.dart';
import 'helpers/controlled_review_repository.dart';
// Reuse the app's real transformer without a feature runtime dependency on it.
// ignore: avoid_relative_lib_imports
import '../../../../lib/app/bloc/bloc_transformer.dart';

void main() {
  late PracticeHarness h;

  setUp(() async {
    final previous = Bloc.transformer;
    addTearDown(() => Bloc.transformer = previous);
    Bloc.transformer = SequentialBlocTransformer<Object?>().transform;
    h = await PracticeHarness.create();
  });
  tearDown(() => h.dispose());

  ReviewSessionBloc bloc({
    String? sourceId,
    bool ahead = false,
    FsrsRepository? fsrs,
  }) => ReviewSessionBloc(
    fsrsRepository: fsrs ?? h.fsrs,
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
    if (b.state.current is PracticeWordItem && !b.state.revealed) {
      b.add(ReviewSessionAnswerRevealed(b.state.cardIdentity!));
      await b.stream.firstWhere((s) => s.revealed);
    }
    final before = b.state.cardIdentity;
    b.add(ReviewSessionCardRated(before!, rating));
    await b.stream.firstWhere(
      (s) =>
          !s.isSaving &&
          (s.cardIdentity != before ||
              s.status != ReviewSessionStatus.reviewing),
    );
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
    final highlight = state.items.whereType<PracticeHighlightItem>().single;
    expect(highlight.source?.id, 'b1');
    expect(highlight.source?.title, 'Dune');
    expect(highlight.source?.author, 'Author');
    expect(highlight.sourceTitle, 'Dune');
  });

  test('rating records the review and advances; Again is collected', () async {
    await h.addBook('b1');
    final word = await h.addWord('a', sourceId: 'b1');
    final other = await h.addWord('b', sourceId: 'b1');
    final b = bloc();
    addTearDown(b.close);
    await start(b);

    b.add(ReviewSessionAnswerRevealed(b.state.cardIdentity!));
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

  for (final rating in [Rating.good, Rating.easy]) {
    test(
      'highlights ignore reveal and record an immediate $rating rating',
      () async {
        await h.addBook('b1');
        final highlight = await h.addHighlight(
          'b1',
          'A saved passage.',
          note: 'A note.',
        );
        final b = bloc();
        addTearDown(b.close);
        final state = await start(b);
        expect(state.current, isA<PracticeHighlightItem>());
        expect(state.revealed, isFalse);
        final emitted = <ReviewSessionState>[];
        final subscription = b.stream.listen(emitted.add);
        addTearDown(subscription.cancel);
        b.add(ReviewSessionAnswerRevealed(b.state.cardIdentity!));
        final completed = await rate(b, rating);
        expect(completed.status, ReviewSessionStatus.completed);
        expect(completed.reviewed, 1);
        expect(completed.ratings[highlight.id], rating);
        expect(emitted.every((state) => !state.revealed), isTrue);
        final stored = await h.fsrs.getReviewState(highlight.id);
        expect(stored!.reps, 1);
      },
    );
  }

  test('removing the current card excludes it from review', () async {
    await h.addBook('b1');
    final word = await h.addWord('a', sourceId: 'b1');
    await h.addWord('b', sourceId: 'b1');
    final b = bloc();
    addTearDown(b.close);
    await start(b);

    b.add(ReviewSessionCardRemoved(b.state.cardIdentity!));
    await b.stream.firstWhere(
      (state) => !state.isSaving && state.items.length == 1,
    );

    expect(b.state.items.length, 1);
    expect(b.state.current?.itemId, isNot(word.id));
    expect(await h.fsrs.getReviewState(word.id), isNull);
  });

  for (final highlight in [false, true]) {
    test('session removal persists through repair and restart: '
        'highlight=$highlight', () async {
      await h.addBook('b1');
      final id = highlight
          ? (await h.addHighlight('b1', 'A saved passage')).id
          : (await h.addWord('saved', sourceId: 'b1')).id;
      final session = bloc();
      addTearDown(session.close);
      expect((await start(session)).current?.itemId, id);

      session.add(ReviewSessionCardRemoved(session.state.cardIdentity!));
      await session.stream.firstWhere(
        (state) => state.status == ReviewSessionStatus.empty,
      );
      await h.fsrs.backfillTextHighlights();
      expect(await h.fsrs.getReviewState(id), isNull);
      expect(await h.fsrs.getDueItemCount(), 0);
      expect(
        highlight
            ? await h.highlights.getHighlightById(id)
            : await h.dictionary.getEntryById(id),
        isNotNull,
      );

      final restarted = bloc();
      final ahead = bloc(ahead: true);
      addTearDown(restarted.close);
      addTearDown(ahead.close);
      expect((await start(restarted)).status, ReviewSessionStatus.empty);
      expect((await start(ahead)).status, ReviewSessionStatus.empty);
    });
  }

  test(
    'removing the final unreviewed card completes without showing a rated card',
    () async {
      await h.addWord('first');
      await h.addWord('last');
      final b = bloc();
      addTearDown(b.close);
      await start(b);
      final first = b.state.current!.itemId;
      await rate(b, Rating.good);
      final last = b.state.cardIdentity!;
      b.add(ReviewSessionCardRemoved(last));
      await b.stream.firstWhere(
        (state) => state.status == ReviewSessionStatus.completed,
      );
      expect(b.state.current, isNull);
      expect(b.state.reviewed, 1);
      expect(b.state.ratings.keys, [first]);
      expect((await h.fsrs.getReviewState(first))!.reps, 1);
      expect(await h.fsrs.getReviewState(last.itemId), isNull);
    },
  );

  test(
    'Again previews and repeated passes use the newly committed FSRS state',
    () async {
      await h.addBook('book');
      await h.addWord('again', sourceId: 'book');
      final b = bloc();
      addTearDown(b.close);
      await start(b);
      final original = b.state.current! as PracticeWordItem;
      for (var pass = 1; pass <= 2; pass++) {
        await rate(b, Rating.again);
        final saved = (await h.fsrs.getReviewState(original.itemId))!;
        expect(saved.reps, pass);
        expect(b.state.again.single.fsrs, saved);
        b.add(const ReviewSessionAgainRequested());
        await b.stream.firstWhere(
          (state) => state.status == ReviewSessionStatus.reviewing,
        );
        final current = b.state.current! as PracticeWordItem;
        expect(current.fsrs, saved);
        expect(current.entry, original.entry);
        expect(current.cfiRange, original.cfiRange);
        expect(current.sourceTitle, original.sourceTitle);
        expect(b.state.intervals, h.fsrs.previewIntervals(saved));
      }
    },
  );

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

  for (final sourceId in [null, 'book']) {
    for (final inactiveType in [
      ReviewableType.highlight,
      ReviewableType.flashcard,
    ]) {
      test('inactive $inactiveType rows cannot consume the due queue limit: '
          'source=$sourceId', () async {
        await h.addBook('book');
        final word = await h.addWord('eligible', sourceId: 'book');
        await h.review(word.id, ReviewableType.dictionary, Rating.hard);
        for (
          var index = 0;
          index < ReviewSessionBloc.sessionLimit * 2 + 1;
          index++
        ) {
          await h.fsrs.createReviewItem(
            itemId: 'inactive-$index',
            itemType: inactiveType,
            sourceId: 'book',
          );
        }
        h.now = h.now.add(const Duration(hours: 1));
        await h.preferences.update(
          (preferences) => preferences.copyWith(
            practiceReviewHighlights: inactiveType != ReviewableType.highlight,
          ),
        );
        final b = bloc(sourceId: sourceId);
        addTearDown(b.close);

        final state = await start(b);

        expect(state.status, ReviewSessionStatus.reviewing);
        expect(state.items.single.itemId, word.id);
      });
    }
  }

  test('Review ahead excludes disabled highlights before its limit', () async {
    await h.addBook('book');
    final word = await h.addWord('eligible', sourceId: 'book');
    await h.review(word.id, ReviewableType.dictionary, Rating.easy);
    for (var index = 0; index < ReviewSessionBloc.aheadLimit + 1; index++) {
      final highlight = await h.addHighlight('book', 'Earlier quote $index');
      await h.review(highlight.id, ReviewableType.highlight, Rating.hard);
    }
    await h.preferences.update(
      (preferences) => preferences.copyWith(practiceReviewHighlights: false),
    );
    final b = bloc(sourceId: 'book', ahead: true);
    addTearDown(b.close);

    final state = await start(b);

    expect(state.status, ReviewSessionStatus.reviewing);
    expect(state.items.single.itemId, word.id);
  });

  for (final sourceId in [null, 'book']) {
    for (final remainingNewBudget in [0, 2]) {
      test('due reviews survive a large new-card prefix: '
          'source=$sourceId remainingNew=$remainingNewBudget', () async {
        await h.addBook('book');
        await h.addBook('other');
        final mature = await h.addWord('mature', sourceId: 'book');
        await h.review(mature.id, ReviewableType.dictionary, Rating.good);
        final scheduled = await h.fsrs.getReviewState(mature.id);
        h.now = scheduled!.nextReviewAt!.add(const Duration(minutes: 1));
        const dailyLimit = 3;
        for (var index = 0; index < dailyLimit - remainingNewBudget; index++) {
          final reviewed = await h.addWord(
            'reviewed-$index',
            sourceId: 'other',
          );
          await h.review(reviewed.id, ReviewableType.dictionary, Rating.easy);
        }
        for (
          var index = 0;
          index < ReviewSessionBloc.sessionLimit * 2 + 1;
          index++
        ) {
          await h.addWord('new-$index', sourceId: 'book');
        }
        await h.preferences.update(
          (preferences) =>
              preferences.copyWith(practiceNewCardsPerDay: dailyLimit),
        );
        expect(
          (await h.fsrs.getStats()).newReviewedToday,
          dailyLimit - remainingNewBudget,
        );
        final b = bloc(sourceId: sourceId);
        addTearDown(b.close);

        final state = await start(b);

        expect(state.status, ReviewSessionStatus.reviewing);
        expect(state.items, hasLength(remainingNewBudget + 1));
        expect(
          state.items.where((item) => item.isNew),
          hasLength(remainingNewBudget),
        );
        expect(state.items.last.itemId, mature.id);
        expect(state.items.every((item) => item.sourceId == 'book'), isTrue);
      });
    }
  }

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

  test('unrevealed words cannot be rated', () async {
    final word = await h.addWord('unrevealed');
    final b = bloc();
    addTearDown(b.close);
    await start(b);
    final card = b.state.cardIdentity!;
    b.add(ReviewSessionCardRated(card, Rating.good));
    b.add(ReviewSessionAnswerRevealed(card));
    await b.stream.firstWhere((state) => state.revealed);
    expect((await h.fsrs.getReviewState(word.id))!.reps, 0);
    expect(b.state.current!.itemId, word.id);
    expect(b.state.ratings, isEmpty);
  });

  for (final type in [ReviewableType.dictionary, ReviewableType.highlight]) {
    test(
      'a deleted $type card is skipped without a rating and review continues',
      () async {
        if (type == ReviewableType.dictionary) {
          await h.addWord('first');
          await h.addWord('second');
        } else {
          await h.addHighlight('source', 'First');
          await h.addHighlight('source', 'Second');
        }
        final b = bloc();
        addTearDown(b.close);
        await start(b);
        final unavailable = b.state.current!;
        if (type == ReviewableType.dictionary) {
          await h.dictionary.deleteEntry(unavailable.itemId);
        } else {
          await h.highlights.deleteHighlight(unavailable.itemId);
        }

        final skipped = await rate(b, Rating.again);

        expect(skipped.status, ReviewSessionStatus.reviewing);
        expect(skipped.items, hasLength(1));
        expect(skipped.current!.itemId, isNot(unavailable.itemId));
        expect(skipped.reviewed, 0);
        expect(skipped.known, 0);
        expect(skipped.again, isEmpty);
        expect(skipped.revealed, isFalse);
        expect(await h.fsrs.getReviewState(unavailable.itemId), isNull);
        expect((await h.fsrs.getStats()).totalReviews, 0);

        final remainingId = skipped.current!.itemId;
        final completed = await rate(b, Rating.good);
        expect(completed.status, ReviewSessionStatus.completed);
        expect(completed.ratings, {remainingId: Rating.good});
        expect((await h.fsrs.getStats()).totalReviews, 1);
      },
    );
  }

  test(
    'a deleted only card leaves an empty session without a fake review',
    () async {
      final highlight = await h.addHighlight('source', 'No longer available');
      final b = bloc();
      addTearDown(b.close);
      await start(b);
      await h.highlights.deleteHighlight(highlight.id);

      final state = await rate(b, Rating.good);

      expect(state.status, ReviewSessionStatus.empty);
      expect(state.current, isNull);
      expect(state.ratings, isEmpty);
      expect(state.again, isEmpty);
      expect(state.intervals, isEmpty);
      expect((await h.fsrs.getStats()).totalReviews, 0);
    },
  );

  test(
    'a deleted final card preserves earlier committed session results',
    () async {
      await h.addWord('first');
      await h.addWord('last');
      final b = bloc();
      addTearDown(b.close);
      await start(b);
      final reviewedId = b.state.current!.itemId;
      await rate(b, Rating.good);
      final unavailableId = b.state.current!.itemId;
      await h.dictionary.deleteEntry(unavailableId);

      final state = await rate(b, Rating.good);

      expect(state.status, ReviewSessionStatus.completed);
      expect(state.current, isNull);
      expect(state.reviewed, 1);
      expect(state.known, 1);
      expect(state.ratings, {reviewedId: Rating.good});
      expect(await h.fsrs.getReviewState(unavailableId), isNull);
      expect((await h.fsrs.getStats()).totalReviews, 1);
    },
  );

  for (final removeFirst in [false, true]) {
    test(
      'queued ${removeFirst ? 'remove/rate' : 'rate/remove'} only mutates the displayed card',
      () async {
        await h.addWord('first');
        await h.addWord('second');
        final repository = ControlledReviewRepository(h);
        final b = bloc(fsrs: repository);
        addTearDown(() async {
          repository.release();
          await b.close();
        });
        await start(b);
        final first = b.state.cardIdentity!;
        b.add(ReviewSessionAnswerRevealed(first));
        await b.stream.firstWhere((state) => state.revealed);
        if (removeFirst) {
          repository.excludeGate = repository.gate;
          b.add(ReviewSessionCardRemoved(first));
          await repository.excludeStarted.future;
          b.add(ReviewSessionCardRated(first, Rating.good));
        } else {
          repository.recordGate = repository.gate;
          b.add(ReviewSessionCardRated(first, Rating.good));
          await repository.recordStarted.future;
          b.add(ReviewSessionCardRemoved(first));
          b.add(ReviewSessionCardRated(first, Rating.easy));
        }
        expect(b.state.isSaving, isTrue);
        expect(b.state.cardIdentity, first);
        final advanced = b.stream.firstWhere(
          (state) => !state.isSaving && state.cardIdentity != first,
        );
        repository.release();
        await advanced;
        final second = b.state.cardIdentity!;
        b.add(ReviewSessionAnswerRevealed(second));
        await b.stream.firstWhere((state) => state.revealed);
        expect(
          repository.persistedRatings,
          removeFirst ? isEmpty : [(first.itemId, Rating.good)],
        );
        expect(repository.excludedIds, removeFirst ? [first.itemId] : isEmpty);
        expect((await h.fsrs.getReviewState(second.itemId))!.reps, 0);
      },
    );
  }

  test('same-ID actions from before Retry are stale', () async {
    await h.addWord('same');
    final repository = ControlledReviewRepository(h);
    final b = bloc(fsrs: repository);
    addTearDown(b.close);
    await start(b);
    final old = b.state.cardIdentity!;
    await start(b);
    final current = b.state.cardIdentity!;
    expect(current.itemId, old.itemId);
    expect(current.revision, isNot(old.revision));
    b.add(ReviewSessionCardRemoved(old));
    b.add(ReviewSessionAnswerRevealed(current));
    await b.stream.firstWhere((state) => state.revealed);
    b.add(ReviewSessionCardRated(old, Rating.easy));
    b.add(ReviewSessionCardRated(current, Rating.good));
    await b.stream.firstWhere(
      (state) => state.status == ReviewSessionStatus.completed,
    );
    expect(repository.excludedIds, isEmpty);
    expect(repository.persistedRatings, [(current.itemId, Rating.good)]);
  });

  test('same-ID actions from the previous Again pass are stale', () async {
    await h.addWord('again');
    final repository = ControlledReviewRepository(h);
    final b = bloc(fsrs: repository);
    addTearDown(b.close);
    await start(b);
    final old = b.state.cardIdentity!;
    await rate(b, Rating.again);
    b.add(const ReviewSessionAgainRequested());
    await b.stream.firstWhere(
      (state) => state.status == ReviewSessionStatus.reviewing,
    );
    final current = b.state.cardIdentity!;
    expect(current.itemId, old.itemId);
    expect(current.revision, isNot(old.revision));
    b.add(ReviewSessionAnswerRevealed(current));
    await b.stream.firstWhere((state) => state.revealed);
    b.add(ReviewSessionCardRated(old, Rating.good));
    b.add(ReviewSessionCardRated(current, Rating.hard));
    await b.stream.firstWhere(
      (state) => state.status == ReviewSessionStatus.completed,
    );
    expect(repository.persistedRatings, [
      (old.itemId, Rating.again),
      (current.itemId, Rating.hard),
    ]);
  });

  test(
    'closing during a write drains the accepted mutation',
    () async {
      await h.addHighlight('source', 'A passage');
      final repository = ControlledReviewRepository(h);
      repository.recordGate = repository.gate;
      final b = bloc(fsrs: repository);
      addTearDown(() async {
        repository.release();
        await b.close();
      });
      await start(b);
      final card = b.state.cardIdentity!;
      b.add(ReviewSessionCardRated(card, Rating.good));
      await repository.recordStarted.future;
      final closing = b.close();
      repository.release();
      await closing;
      expect(repository.persistedRatings, [(card.itemId, Rating.good)]);
      expect((await h.fsrs.getReviewState(card.itemId))!.reps, 1);
      expect(b.isClosed, isTrue);
    },
  );

  test(
    'restart waits for the accepted mutation and ignores the old gesture',
    () async {
      await h.addHighlight('source', 'First');
      await h.addHighlight('source', 'Second');
      final repository = ControlledReviewRepository(h);
      repository.recordGate = repository.gate;
      final b = bloc(fsrs: repository);
      addTearDown(() async {
        repository.release();
        await b.close();
      });
      await start(b);
      final first = b.state.cardIdentity!;
      b.add(ReviewSessionCardRated(first, Rating.good));
      await repository.recordStarted.future;
      b.add(const ReviewSessionStarted());
      b.add(ReviewSessionCardRemoved(first));
      final reloaded = b.stream.firstWhere(
        (state) =>
            state.status == ReviewSessionStatus.reviewing &&
            !state.isSaving &&
            state.items.length == 1,
      );
      repository.release();
      await reloaded;
      // A second start is a barrier behind the stale Remove action.
      await start(b);
      expect(b.state.items.single.itemId, isNot(first.itemId));
      expect(repository.excludedIds, isEmpty);
      expect(repository.persistedRatings, [(first.itemId, Rating.good)]);
    },
  );

  for (final removing in [false, true]) {
    test(
      'failed ${removing ? 'removal' : 'rating'} clears saving without advancing',
      () async {
        await h.addHighlight('source', 'A passage');
        final repository = ControlledReviewRepository(h)
          ..failRecord = !removing
          ..failExclude = removing;
        final b = bloc(fsrs: repository);
        addTearDown(b.close);
        await start(b);
        final card = b.state.cardIdentity!;
        b.add(
          removing
              ? ReviewSessionCardRemoved(card)
              : ReviewSessionCardRated(card, Rating.good),
        );
        await b.stream.firstWhere(
          (state) => state.status == ReviewSessionStatus.failure,
        );
        expect(b.state.isSaving, isFalse);
        expect(b.state.cardIdentity, card);
        expect((await h.fsrs.getReviewState(card.itemId))!.reps, 0);
        expect(repository.excludedIds, isEmpty);
        expect(repository.persistedRatings, isEmpty);
      },
    );
  }
}
