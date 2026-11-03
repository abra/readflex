import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_fsrs_repository.dart';

void main() {
  late PreferencesService preferences;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    addTearDown(preferences.dispose);
  });

  testWidgets('five idle minutes refresh only the due queue once', (
    tester,
  ) async {
    final harness = _Harness(preferences: preferences);
    try {
      harness.review
        ..stats = reviewStats(words: 3, highlights: 2)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 5));
      await harness.load(tester);
      final sources = harness.bloc.state.sources;

      await harness.advance(tester, const Duration(minutes: 4));
      expect(harness.review.getReviewQueueStatusCallCount, 1);
      expect(harness.bloc.state.practice!.due, 0);

      harness.review
        ..stats = reviewStats(words: 3, highlights: 2, due: 1)
        ..nextReviewAt = null;
      await harness.advance(tester, const Duration(minutes: 1));

      expect(harness.bloc.state.practice!.due, 1);
      expect(harness.bloc.state.practice!.words, 3);
      expect(harness.bloc.state.practice!.highlights, 2);
      expect(harness.bloc.state.sources, same(sources));
      expect(harness.books.getBooksCallCount, 1);
      expect(harness.articles.reads, 1);
      expect(harness.review.getStatsCallCount, 1);
      expect(harness.review.getReviewQueueStatusCallCount, 2);

      await harness.advance(tester, const Duration(hours: 1));
      expect(harness.review.getReviewQueueStatusCallCount, 2);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets('each refresh schedules the next future deadline', (
    tester,
  ) async {
    final harness = _Harness(preferences: preferences);
    try {
      harness.review
        ..stats = reviewStats(words: 2)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 1));
      await harness.load(tester);

      harness.review
        ..stats = reviewStats(words: 2, due: 1)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 3));
      await harness.advance(tester, const Duration(minutes: 1));
      expect(harness.bloc.state.practice!.due, 1);
      expect(harness.review.getReviewQueueStatusCallCount, 2);

      await harness.advance(tester, const Duration(minutes: 1));
      expect(harness.review.getReviewQueueStatusCallCount, 2);

      harness.review
        ..stats = reviewStats(words: 2, due: 2)
        ..nextReviewAt = null;
      await harness.advance(tester, const Duration(minutes: 1));
      expect(harness.bloc.state.practice!.due, 2);
      expect(harness.bloc.state.practice!.nextReviewAt, isNull);
      expect(harness.review.getReviewQueueStatusCallCount, 3);
      expect(harness.books.getBooksCallCount, 1);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets('background cancels the deadline and resume refreshes at once', (
    tester,
  ) async {
    final harness = _Harness(preferences: preferences);
    try {
      harness.review
        ..stats = reviewStats(words: 2)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 5));
      await harness.load(tester);

      harness.bloc.add(const LibraryForegroundChanged(false));
      await tester.pump();
      harness.review
        ..stats = reviewStats(words: 2, due: 1)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 20));
      await harness.advance(tester, const Duration(minutes: 10));
      expect(harness.review.getReviewQueueStatusCallCount, 1);
      expect(harness.bloc.state.practice!.due, 0);

      harness.bloc.add(const LibraryForegroundChanged(true));
      await tester.pump();
      expect(harness.bloc.state.practice!.due, 1);
      expect(harness.review.getReviewQueueStatusCallCount, 2);
      expect(harness.books.getBooksCallCount, 1);
      expect(harness.review.getStatsCallCount, 1);

      harness.review
        ..stats = reviewStats(words: 2, due: 2)
        ..nextReviewAt = null;
      await harness.advance(tester, const Duration(minutes: 10));
      expect(harness.bloc.state.practice!.due, 2);
      expect(harness.review.getReviewQueueStatusCallCount, 3);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets('initial background state does not arm a timer', (tester) async {
    final harness = _Harness(preferences: preferences, isForeground: false);
    try {
      harness.review
        ..stats = reviewStats(words: 1)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 1));
      await harness.load(tester);
      harness.review
        ..stats = reviewStats(words: 1, due: 1)
        ..nextReviewAt = null;
      await harness.advance(tester, const Duration(minutes: 5));
      expect(harness.review.getReviewQueueStatusCallCount, 1);

      harness.bloc.add(const LibraryForegroundChanged(true));
      await tester.pump();
      expect(harness.bloc.state.practice!.due, 1);
      expect(harness.review.getReviewQueueStatusCallCount, 2);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets('closing cancels the pending deadline', (tester) async {
    final harness = _Harness(preferences: preferences);
    try {
      harness.review
        ..stats = reviewStats(words: 1)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 1));
      await harness.load(tester);
      await harness.close(tester);
      await harness.advance(tester, const Duration(minutes: 5));

      expect(harness.bloc.isClosed, isTrue);
      expect(harness.review.getReviewQueueStatusCallCount, 1);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets('a full refresh replaces the old deadline', (tester) async {
    final harness = _Harness(preferences: preferences);
    try {
      harness.review
        ..stats = reviewStats(words: 1)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 1));
      await harness.load(tester);

      harness.review.nextReviewAt = harness.now.add(const Duration(minutes: 3));
      await harness.refresh(tester);
      await harness.advance(tester, const Duration(minutes: 1));
      expect(harness.review.getReviewQueueStatusCallCount, 2);
      expect(harness.bloc.state.practice!.due, 0);

      harness.review
        ..stats = reviewStats(words: 1, due: 1)
        ..nextReviewAt = null;
      await harness.advance(tester, const Duration(minutes: 2));
      expect(harness.bloc.state.practice!.due, 1);
      expect(harness.review.getReviewQueueStatusCallCount, 3);
      expect(harness.review.getStatsCallCount, 2);
      expect(harness.books.getBooksCallCount, 2);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets('queue refresh uses active types and preserves saved totals', (
    tester,
  ) async {
    final review = _RecordingQueueRepository()
      ..stats = const ReviewStats(
        totalByType: {
          ReviewableType.dictionary: 2,
          ReviewableType.highlight: 3,
          ReviewableType.flashcard: 4,
        },
        dueByType: {
          ReviewableType.dictionary: 1,
          ReviewableType.highlight: 2,
          ReviewableType.flashcard: 4,
        },
      );
    await preferences.update(
      (p) => p.copyWith(practiceReviewHighlights: false),
    );
    final harness = _Harness(preferences: preferences, review: review);
    try {
      await harness.load(tester);
      expect(harness.bloc.state.practice!.due, 1);
      expect(review.requestedTypes, {ReviewableType.dictionary});

      await preferences.update(
        (p) => p.copyWith(practiceReviewHighlights: true),
      );
      harness.bloc.add(const LibraryPracticeRefreshRequested());
      await tester.pump();

      expect(review.requestedTypes, {
        ReviewableType.dictionary,
        ReviewableType.highlight,
      });
      expect(harness.bloc.state.practice!.due, 3);
      expect(harness.bloc.state.practice!.words, 2);
      expect(harness.bloc.state.practice!.highlights, 3);
      expect(review.getStatsCallCount, 1);
      expect(harness.books.getBooksCallCount, 1);
    } finally {
      await harness.close(tester);
    }
  });

  testWidgets(
    'a failed due read preserves the state and retries after a minute',
    (
      tester,
    ) async {
      final harness = _Harness(preferences: preferences);
      try {
        harness.review
          ..stats = reviewStats(words: 1)
          ..nextReviewAt = harness.now.add(const Duration(minutes: 1));
        await harness.load(tester);
        final originalPractice = harness.bloc.state.practice;

        harness.review.shouldThrow = true;
        await harness.advance(tester, const Duration(minutes: 1));
        expect(harness.bloc.state.practice, originalPractice);
        expect(harness.review.getReviewQueueStatusCallCount, 2);

        await harness.advance(tester, const Duration(seconds: 59));
        expect(harness.review.getReviewQueueStatusCallCount, 2);
        harness.review
          ..shouldThrow = false
          ..stats = reviewStats(words: 1, due: 1)
          ..nextReviewAt = null;
        await harness.advance(tester, const Duration(seconds: 1));
        expect(harness.bloc.state.practice!.due, 1);
        expect(harness.review.getReviewQueueStatusCallCount, 3);
        expect(harness.books.getBooksCallCount, 1);
        expect(harness.review.getStatsCallCount, 1);
      } finally {
        await harness.close(tester);
      }
    },
  );

  testWidgets('a stale due reply cannot replace a newer full snapshot', (
    tester,
  ) async {
    final review = _GatedQueueRepository();
    final harness = _Harness(preferences: preferences, review: review);
    final pending = Completer<ReviewQueueStatus>();
    try {
      review
        ..stats = reviewStats(words: 1)
        ..nextReviewAt = harness.now.add(const Duration(minutes: 1));
      await harness.load(tester);

      review.nextRead = pending.future;
      await harness.advance(tester, const Duration(minutes: 1));
      expect(review.getReviewQueueStatusCallCount, 2);

      final freshDeadline = harness.now.add(const Duration(minutes: 29));
      review.nextReviewAt = freshDeadline;
      await harness.refresh(tester);
      expect(harness.bloc.state.practice!.nextReviewAt, freshDeadline);

      pending.complete(const ReviewQueueStatus(dueCount: 1));
      await tester.pump();
      expect(harness.bloc.state.practice!.due, 0);
      expect(harness.bloc.state.practice!.nextReviewAt, freshDeadline);

      review
        ..stats = reviewStats(words: 1, due: 1)
        ..nextReviewAt = null;
      await harness.advance(tester, const Duration(minutes: 29));
      expect(harness.bloc.state.practice!.due, 1);
      expect(review.getReviewQueueStatusCallCount, 4);
    } finally {
      if (!pending.isCompleted) {
        pending.complete(const ReviewQueueStatus(dueCount: 0));
        await tester.pump();
      }
      await harness.close(tester);
    }
  });
}

class _Harness {
  _Harness({
    required PreferencesService preferences,
    FakeFsrsRepository? review,
    bool isForeground = true,
  }) : review = review ?? FakeFsrsRepository() {
    books.seedBooks([
      Book(
        id: 'timer-book',
        title: 'Reading',
        filePath: '/timer.epub',
        format: BookFormat.epub,
        addedAt: now,
      ),
    ]);
    bloc = LibraryBloc(
      bookRepository: books,
      articleRepository: articles,
      fsrsRepository: this.review,
      preferencesService: preferences,
      clock: () => now,
      isForeground: isForeground,
    );
  }

  DateTime now = DateTime.utc(2026, 11, 4, 12);
  final books = FakeBookRepository();
  final articles = _ArticleRepository();
  final FakeFsrsRepository review;
  late final LibraryBloc bloc;

  Future<void> load(WidgetTester tester) async {
    bloc.add(const LibraryLoadRequested());
    await tester.pump();
    expect(bloc.state.status, LibraryStatus.success);
  }

  Future<void> refresh(WidgetTester tester) async {
    final done = Completer<void>();
    bloc.add(LibraryRefreshRequested(completer: done));
    await tester.pump();
    expect(done.isCompleted, isTrue);
  }

  Future<void> advance(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    if (bloc.isClosed) return;
    await tester.runAsync(bloc.close);
  }
}

class _ArticleRepository implements ArticleRepository {
  int reads = 0;

  @override
  Future<List<LibrarySource>> getLibrarySources() async {
    reads++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingQueueRepository extends FakeFsrsRepository {
  Set<ReviewableType>? requestedTypes;

  @override
  Future<ReviewQueueStatus> getReviewQueueStatus({
    Set<ReviewableType>? types,
  }) {
    requestedTypes = types;
    return super.getReviewQueueStatus(types: types);
  }
}

class _GatedQueueRepository extends FakeFsrsRepository {
  Future<ReviewQueueStatus>? nextRead;

  @override
  Future<ReviewQueueStatus> getReviewQueueStatus({
    Set<ReviewableType>? types,
  }) {
    final pending = nextRead;
    if (pending == null) return super.getReviewQueueStatus(types: types);
    nextRead = null;
    getReviewQueueStatusCallCount++;
    return pending;
  }
}
