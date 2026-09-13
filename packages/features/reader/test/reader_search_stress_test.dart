import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

ReaderSearchResults chunk(int index) => ReaderSearchResults(
  requestId: 1,
  results: [
    ReaderSearchResult(
      cfi: 'cfi-$index',
      excerpt: const ReaderSearchExcerpt(match: 'power'),
    ),
  ],
);

void main() {
  late ReaderSearchCubit cubit;
  late StreamController<ReaderSearchEvent> controller;

  setUp(() {
    cubit = ReaderSearchCubit();
    controller = StreamController<ReaderSearchEvent>.broadcast();
  });
  tearDown(() async {
    await cubit.close();
    await controller.close();
  });

  void search(String query) => cubit.recentQuerySelected(
    query,
    searchBook: (_) => controller.stream,
  );

  test('synchronous renderer failure becomes a recoverable state', () {
    expect(
      () => cubit.recentQuerySelected(
        'power',
        searchBook: (_) => throw StateError('renderer disposed'),
      ),
      returnsNormally,
    );
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.errorCode, ReaderSearchErrorCode.searchFailed);
  });

  test('burst results have bounded emissions and no lost matches', () async {
    final states = <ReaderSearchState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
    search('power');
    for (var i = 0; i < 5000; i++) {
      controller.add(chunk(i));
      controller.add(ReaderSearchProgress(requestId: 1, progress: i / 5000));
    }
    controller.add(const ReaderSearchDone(requestId: 1));
    await controller.close();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.results, hasLength(5000));
    expect(cubit.state.results.first.cfi, 'cfi-0');
    expect(cubit.state.results.last.cfi, 'cfi-4999');
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.progress, 1);
    expect(states.length, lessThanOrEqualTo(3));
    expect(
      states.fold<int>(0, (sum, state) => sum + state.results.length),
      lessThanOrEqualTo(10000),
      reason: 'A burst must not repeatedly copy all previous results',
    );
  });

  test('partial results appear within one update interval', () async {
    search('power');
    controller.add(chunk(0));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final firstSnapshot = cubit.state.results;
    expect(firstSnapshot.single.cfi, 'cfi-0');
    expect(cubit.state.isLoading, isTrue);

    controller.add(chunk(1));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    expect(cubit.state.results, hasLength(2));
    expect(
      firstSnapshot,
      hasLength(1),
      reason: 'Published states are snapshots',
    );
  });

  test(
    'done flushes pending results without waiting for stream close',
    () async {
      search('power');
      controller.add(chunk(0));
      controller.add(const ReaderSearchDone(requestId: 1));
      controller.add(chunk(1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.results.single.cfi, 'cfi-0');
    },
  );

  for (final streamError in [false, true]) {
    test(
      'terminal error discards pending and late results: $streamError',
      () async {
        search('power');
        controller.add(chunk(0));
        if (streamError) {
          controller.addError(StateError('renderer failed'));
        } else {
          controller.add(
            const ReaderSearchError(requestId: 1, message: 'Failed'),
          );
        }
        controller.add(chunk(1));
        controller.add(const ReaderSearchDone(requestId: 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(cubit.state.results, isEmpty);
        expect(cubit.state.isLoading, isFalse);
        expect(
          streamError ? cubit.state.errorCode : cubit.state.errorMessage,
          streamError ? ReaderSearchErrorCode.searchFailed : 'Failed',
        );
      },
    );
  }

  test('reset cancels pending publication', () async {
    search('power');
    controller.add(chunk(0));
    await Future<void>.delayed(Duration.zero);
    cubit.reset();
    controller.add(chunk(1));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.query, isEmpty);
    expect(cubit.state.results, isEmpty);
    expect(cubit.state.isLoading, isFalse);
  });

  test('replacement discards the previous query pending batch', () async {
    search('power');
    controller.add(chunk(0));
    await Future<void>.delayed(Duration.zero);
    cubit.recentQuerySelected(
      'devices',
      searchBook: (_) => Stream.fromIterable([chunk(99)]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.query, 'devices');
    expect(cubit.state.results.single.cfi, 'cfi-99');
  });

  test('typing searches only the final debounced query', () {
    fakeAsync((time) {
      final debouncedCubit = ReaderSearchCubit();
      final queries = <String>[];
      Stream<ReaderSearchEvent> renderer(String query) {
        queries.add(query);
        return const Stream.empty();
      }

      for (final query in ['po', 'pow', 'powe', 'power']) {
        debouncedCubit.queryChanged(query, searchBook: renderer);
        time.elapse(const Duration(milliseconds: 50));
      }
      expect(queries, isEmpty);
      time.elapse(const Duration(milliseconds: 249));
      expect(queries, isEmpty);
      time.elapse(const Duration(milliseconds: 1));
      expect(queries, ['power']);
      expect(debouncedCubit.state.isLoading, isFalse);
      unawaited(debouncedCubit.close());
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('close cancels timers and renderer subscription', () async {
    search('power');
    controller.add(chunk(0));
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    expect(controller.hasListener, isFalse);
    controller.add(chunk(1));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(cubit.isClosed, isTrue);
  });
}
