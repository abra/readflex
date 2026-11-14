import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:practice/src/practice_bloc.dart';
import 'package:practice/src/review_session_bloc.dart';
import 'package:reader/src/reader_bloc.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';

void main() {
  late UiTestApp app;

  setUp(() async {
    app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
  });

  test(
    'a failing final import observer still leaves a readable Library book',
    () async {
      final original = await File('${app.directory.path}/original.fb2')
          .writeAsString(ReadingFixture.fb2);
      final notifications = <double>[];
      final saved = await app.bookRepository.addBook(
        sourceFile: original,
        title: ReadingFixture.bookTitle,
        format: BookFormat.fb2,
        onProgress: (value) {
          notifications.add(value);
          if (value == 1) {
            throw StateError('The importing screen was dismissed');
          }
        },
      );
      expect(notifications.last, 1);
      final library = LibraryBloc(bookRepository: app.bookRepository);
      final reader = ReaderBloc(
        bookRepository: app.bookRepository,
        highlightRepository: app.highlightRepository,
      );
      addTearDown(library.close);
      addTearDown(reader.close);

      await _send(
        library,
        const LibraryLoadRequested(),
        (state) => state.status == LibraryStatus.success,
      );
      expect(library.state.sources.single.id, saved.id);
      await _send(
        reader,
        ReaderSourceLoadRequested(sourceId: saved.id),
        (state) => state.status == ReaderStatus.ready,
      );
      expect(reader.state.document?.id, saved.id);
      expect(await File(saved.filePath).readAsString(), ReadingFixture.fb2);
      expect(await original.readAsString(), ReadingFixture.fb2);
    },
  );

  for (final sourceType in SourceType.values) {
    for (final reviewHighlights in [false, true]) {
      test('Reader → Practice → late rating → Undo: '
          '$sourceType, highlights=$reviewHighlights', () async {
        await app.preferencesService.update(
          (preferences) => preferences.copyWith(
            practiceReviewHighlights: reviewHighlights,
          ),
        );
        final String sourceId;
        if (sourceType == SourceType.article) {
          sourceId = (await app.articleRepository.addExtractedArticle(
            ReadingFixture.article,
          )).id;
        } else {
          final file = await File('${app.directory.path}/original.fb2')
              .writeAsString(ReadingFixture.fb2);
          sourceId = (await app.bookRepository.addBook(
            sourceFile: file,
            title: ReadingFixture.bookTitle,
            format: BookFormat.fb2,
          )).id;
        }
        final highlight = await app.highlightRepository.addHighlight(
          sourceId: sourceId,
          sourceType: sourceType,
          text: 'A quiet conversation with the page.',
          note: 'Keep this thought',
          cfiRange: sourceType == SourceType.article
              ? 'article:0'
              : 'epubcfi(/6/2!/4/2,/1:0,/1:34)',
        );
        await app.highlightRepository.addImageAreaHighlight(
          sourceId: sourceId,
          sourceType: sourceType,
          pageIndex: 0,
          x: .1,
          y: .1,
          width: .3,
          height: .3,
        );
        final now = DateTime.utc(2026, 11, 14, 12);
        final reviews = FsrsRepository(
          database: app.database,
          clock: () => now,
        );
        final schedule = await reviews.getReviewState(highlight.id);
        final reader = ReaderBloc(
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          highlightRepository: app.highlightRepository,
        );
        final library = LibraryBloc(
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          fsrsRepository: reviews,
          preferencesService: app.preferencesService,
          clock: () => now,
          isForeground: false,
        );
        final practice = PracticeBloc(
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          dictionaryRepository: app.dictionaryRepository,
          highlightRepository: app.highlightRepository,
          fsrsRepository: reviews,
          preferencesService: app.preferencesService,
        );
        final session = ReviewSessionBloc(
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          dictionaryRepository: app.dictionaryRepository,
          highlightRepository: app.highlightRepository,
          fsrsRepository: reviews,
          preferencesService: app.preferencesService,
          sourceId: sourceId,
        );
        addTearDown(reader.close);
        addTearDown(library.close);
        addTearDown(practice.close);
        addTearDown(session.close);

        Future<void> expectCounts(int expected) async {
          await _send(
            library,
            const LibraryLoadRequested(),
            (state) => state.status == LibraryStatus.success,
          );
          await _send(
            practice,
            const PracticeLoadRequested(),
            (state) => state.status == PracticeStatus.ready,
          );
          expect(library.state.practice?.due, expected);
          expect(practice.state.due, expected);
          expect(
            practice.state.sources
                .where((summary) => summary.source.id == sourceId)
                .fold(0, (total, summary) => total + summary.due),
            expected,
          );
        }

        await _send(
          reader,
          ReaderSourceLoadRequested(sourceId: sourceId),
          (state) => state.status == ReaderStatus.ready,
        );
        await expectCounts(reviewHighlights ? 1 : 0);
        await _send(
          session,
          const ReviewSessionStarted(),
          (state) => state.status != ReviewSessionStatus.loading,
        );
        expect(
          session.state.items.map((item) => item.itemId),
          reviewHighlights ? [highlight.id] : isEmpty,
        );
        final cachedCard = session.state.cardIdentity;

        await _send(
          reader,
          ReaderHighlightDeleteRequested(highlightId: highlight.id),
          (state) => state.highlightEdits.removed.isNotEmpty,
        );
        expect(await reviews.getReviewState(highlight.id), isNull);
        if (cachedCard != null) {
          await _send(
            session,
            ReviewSessionCardRated(cachedCard, Rating.good),
            (state) => state.status == ReviewSessionStatus.empty,
          );
        }
        expect(session.state.ratings, isEmpty);
        expect((await reviews.getStats()).totalReviews, 0);
        await expectCounts(0);

        await _send(
          reader,
          ReaderHighlightRestored(highlightId: highlight.id),
          (state) => state.highlightEdits.removed.isEmpty,
        );
        expect(
          await app.highlightRepository.getHighlightById(highlight.id),
          highlight,
        );
        expect(await reviews.getReviewState(highlight.id), schedule);
        await expectCounts(reviewHighlights ? 1 : 0);
        await _send(
          session,
          const ReviewSessionStarted(),
          (state) => state.status != ReviewSessionStatus.loading,
        );
        expect(session.state.items, hasLength(reviewHighlights ? 1 : 0));
        expect((await reviews.getStats()).totalReviews, 0);
      });
    }
  }
}

Future<State> _send<Event, State>(
  Bloc<Event, State> bloc,
  Event event,
  bool Function(State) matches,
) {
  final next = bloc.stream
      .firstWhere(matches)
      .timeout(const Duration(seconds: 5));
  bloc.add(event);
  return next;
}
