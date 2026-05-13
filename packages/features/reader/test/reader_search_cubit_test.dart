import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('ReaderSearchCubit', () {
    ReaderSearchResult result(String cfi) => ReaderSearchResult(
      cfi: cfi,
      excerpt: const ReaderSearchExcerpt(match: 'term'),
    );

    test('ignores queries shorter than minimum length', () {
      var searches = 0;
      final cubit = ReaderSearchCubit();

      cubit.queryChanged(
        'a',
        searchBook: (_) {
          searches++;
          return const Stream.empty();
        },
      );

      expect(searches, 0);
      expect(cubit.state.query, 'a');
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.results, isEmpty);
    });

    test('streams results and stores successful query in history', () async {
      final persisted = <List<String>>[];
      final cubit = ReaderSearchCubit(
        onRecentQueriesChanged: persisted.add,
      );

      cubit.recentQuerySelected(
        'term',
        searchBook: (_) => Stream<ReaderSearchEvent>.fromIterable([
          const ReaderSearchProgress(requestId: 1, progress: 0.5),
          ReaderSearchResults(requestId: 1, results: [result('cfi-1')]),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.progress, 1);
      expect(cubit.state.results.single.cfi, 'cfi-1');
      expect(cubit.state.recentQueries, ['term']);
      expect(persisted, [
        ['term'],
      ]);
    });

    test('clear token increments when replacing visible results', () async {
      final cubit = ReaderSearchCubit();

      cubit.recentQuerySelected(
        'term',
        searchBook: (_) => Stream<ReaderSearchEvent>.fromIterable([
          ReaderSearchResults(requestId: 1, results: [result('cfi-1')]),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      cubit.queryChanged('te', searchBook: (_) => const Stream.empty());

      expect(cubit.state.clearSearchToken, 1);
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.isLoading, isTrue);
    });

    test('removing recent query persists updated history', () {
      final persisted = <List<String>>[];
      final cubit = ReaderSearchCubit(
        initialRecentQueries: const ['one', 'two'],
        onRecentQueriesChanged: persisted.add,
      );

      cubit.recentQueryRemoved('one');

      expect(cubit.state.recentQueries, ['two']);
      expect(persisted, [
        ['two'],
      ]);
    });
  });
}
