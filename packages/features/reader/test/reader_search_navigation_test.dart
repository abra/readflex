import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  const origin = ReaderSearchLocation(cfi: 'origin', fraction: 0.12);
  const later = ReaderSearchLocation(cfi: 'later', fraction: 0.65);
  final results = List.generate(
    3,
    (index) => ReaderSearchResult(
      cfi: 'cfi-$index',
      excerpt: const ReaderSearchExcerpt(match: 'term'),
    ),
  );

  Future<ReaderSearchCubit> ready() async {
    final cubit = ReaderSearchCubit();
    addTearDown(cubit.close);
    cubit.recentQuerySelected(
      'term',
      searchBook: (_) => Stream.fromIterable([
        ReaderSearchResults(requestId: 1, results: results),
        const ReaderSearchDone(requestId: 1),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  test(
    'forward and backward navigation preserve the first reading anchor',
    () async {
      final cubit = await ready();
      final cachedResults = cubit.state.results;
      expect(cubit.resultSelected(index: 0, returnLocation: origin), isTrue);
      expect(cubit.state.canGoPrevious, isFalse);
      expect(cubit.state.canGoNext, isTrue);
      cubit.resultSelected(index: 2, returnLocation: later);
      expect(cubit.state.canGoNext, isFalse);
      cubit.resultSelected(index: 1, returnLocation: later);
      expect(cubit.state.activeResultIndex, 1);
      expect(cubit.state.returnLocation, origin);
      expect(identical(cubit.state.results, cachedResults), isTrue);
      expect(cubit.state.recentQueries, ['term']);
    },
  );

  test('invalid result indices do not start or change navigation', () async {
    final cubit = await ready();
    final before = cubit.state;
    expect(cubit.resultSelected(index: -1, returnLocation: origin), isFalse);
    expect(cubit.resultSelected(index: 3, returnLocation: origin), isFalse);
    expect(cubit.state, before);
  });

  test(
    'query replacement clears the active result but keeps the reading origin',
    () async {
      final cubit = await ready();
      cubit.resultSelected(index: 1, returnLocation: origin);
      cubit.queryChanged('new', searchBook: (_) => const Stream.empty());
      expect(cubit.state.activeResultIndex, isNull);
      expect(cubit.state.returnLocation, origin);
      expect(cubit.state.isNavigating, isTrue);
      expect(cubit.state.canGoNext, isFalse);
      expect(cubit.state.canGoPrevious, isFalse);
    },
  );

  test('reset ends navigation and prevents late stream results', () async {
    var cancelled = false;
    final stream = StreamController<ReaderSearchEvent>(
      onCancel: () => cancelled = true,
    );
    addTearDown(stream.close);
    final cubit = ReaderSearchCubit();
    addTearDown(cubit.close);
    cubit.recentQuerySelected('term', searchBook: (_) => stream.stream);
    stream.add(ReaderSearchResults(requestId: 1, results: results));
    await Future<void>.delayed(const Duration(milliseconds: 25));
    cubit.resultSelected(index: 0, returnLocation: origin);
    cubit.reset();
    stream.add(ReaderSearchResults(requestId: 1, results: results));
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(cancelled, isTrue);
    expect(cubit.state.isNavigating, isFalse);
    expect(cubit.state.returnLocation, isNull);
    expect(cubit.state.results, isEmpty);
    expect(cubit.state.query, isEmpty);
    expect(cubit.state.clearSearchToken, 1);
    expect(cubit.state.recentQueries, ['term']);
  });
}
