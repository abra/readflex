import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_event.dart';
import 'package:reader/src/reader_search_navigator.dart';
import 'package:reader/src/reader_text_surface.dart';
import 'package:reader/src/reader_ui_cubit.dart';

void main() {
  late ReaderSearchCubit search;
  late ReaderUiCubit ui;
  late ReaderSearchNavigator navigator;
  late _RecordingSurface surface;
  late SourceType sourceType;
  late List<Completer<void>> frames;
  late List<String> events;

  setUp(() async {
    search = ReaderSearchCubit();
    ui = ReaderUiCubit();
    events = [];
    surface = _RecordingSurface(events);
    sourceType = SourceType.book;
    frames = [];
    navigator = ReaderSearchNavigator(
      searchCubit: search,
      uiCubit: ui,
      surface: () => surface,
      sourceType: () => sourceType,
      closeSearchPanel: () {
        events.add('close-panel');
        ui.closeSearchDrawer(restoreChrome: false, clearSearch: false);
      },
      waitForLayout: () {
        final frame = Completer<void>();
        frames.add(frame);
        return frame.future;
      },
    );
    search.recentQuerySelected(
      'term',
      searchBook: (_) => Stream.fromIterable([
        ReaderSearchResults(
          requestId: 1,
          results: [
            for (final cfi in ['hit-0', 'hit-1', ''])
              ReaderSearchResult(
                cfi: cfi,
                excerpt: const ReaderSearchExcerpt(match: 'term'),
              ),
          ],
        ),
        const ReaderSearchDone(requestId: 1),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    navigator.dispose();
    await search.close();
    await ui.close();
  });

  test(
    'capture precedes keyboard relocation; a jump waits for layout',
    () async {
      navigator.rememberLocation(cfi: 'origin', fraction: .12);
      navigator.openSearch();
      navigator.rememberLocation(cfi: 'keyboard-relocation', fraction: .2);
      final pending = navigator.selectResult(0);

      expect(
        search.state.returnLocation,
        const ReaderSearchLocation(cfi: 'origin', fraction: .12),
      );
      expect(events, ['close-panel']);
      expect(ui.state.searchHighlightVisible, isFalse);
      frames.single.complete();
      await pending;
      expect(events, ['close-panel', 'result:hit-0']);
      expect(ui.state.searchHighlightVisible, isTrue);
    },
  );

  test('rapid selection reaches only the most recent result', () async {
    final first = navigator.selectResult(0);
    final next = navigator.selectResult(1);
    frames.first.complete();
    await first;
    expect(events, ['close-panel', 'close-panel']);
    frames.last.complete();
    await next;
    expect(events.last, 'result:hit-1');
    expect(search.state.activeResultIndex, 1);
  });

  for (final cancel in ['end', 'loading', 'dispose', 'replace-query']) {
    test('$cancel prevents a pending jump', () async {
      final pending = navigator.selectResult(0);
      switch (cancel) {
        case 'end':
          navigator.endSearch();
        case 'loading':
          navigator.surfaceLoading();
        case 'dispose':
          navigator.dispose();
        case 'replace-query':
          search.queryChanged(
            'replacement',
            searchBook: (_) => const Stream.empty(),
          );
      }
      frames.single.complete();
      await pending;
      expect(events, ['close-panel']);
      expect(ui.state.searchHighlightVisible, isFalse);
    });
  }

  for (final type in SourceType.values) {
    test('return restores $type with the matching surface command', () async {
      sourceType = type;
      navigator.rememberLocation(cfi: 'origin', fraction: .37);
      final jump = navigator.selectResult(0);
      frames.single.complete();
      await jump;
      navigator.rememberLocation(cfi: 'search-hit', fraction: .9);
      final returning = navigator.returnToReading();
      expect(search.state.isNavigating, isFalse);
      frames.last.complete();
      await returning;
      expect(
        events.last,
        type == SourceType.article ? 'fraction:0.37' : 'bookmark:origin:0.37',
      );
    });
  }

  for (final cancel in ['end', 'loading', 'dispose']) {
    test('$cancel invalidates a pending return', () async {
      navigator.rememberLocation(cfi: 'origin', fraction: .5);
      final jump = navigator.selectResult(0);
      frames.single.complete();
      await jump;
      final returning = navigator.returnToReading();
      switch (cancel) {
        case 'end':
          navigator.endSearch();
        case 'loading':
          navigator.surfaceLoading();
        case 'dispose':
          navigator.dispose();
      }
      frames.last.complete();
      await returning;
      expect(events.last, 'result:hit-0');
    });
  }

  test(
    'invalid result indices and empty anchors leave navigation untouched',
    () async {
      final initial = search.state;
      await navigator.selectResult(-1);
      await navigator.selectResult(99);
      await navigator.selectResult(2);
      await navigator.returnToReading();
      expect(search.state, initial);
      expect(events, isEmpty);
      expect(frames, isEmpty);
    },
  );

  test(
    'invalid reports preserve the last valid clamped reading location',
    () async {
      navigator.rememberLocation(cfi: 'last-valid', fraction: 1.4);
      navigator.rememberLocation(cfi: '', fraction: .2);
      navigator.rememberLocation(cfi: 'invalid', fraction: double.nan);
      navigator.rememberLocation(cfi: 'invalid', fraction: double.infinity);
      final jump = navigator.selectResult(0);
      expect(
        search.state.returnLocation,
        const ReaderSearchLocation(cfi: 'last-valid', fraction: 1),
      );
      frames.single.complete();
      await jump;
    },
  );

  test('disposal drops commands without closing injected cubits', () async {
    navigator.dispose();
    navigator.openSearch();
    navigator.surfaceLoading();
    navigator.endSearch();
    await navigator.selectResult(0);
    await navigator.returnToReading();
    expect(events, isEmpty);
    expect(frames, isEmpty);
    expect(search.isClosed, isFalse);
    expect(ui.isClosed, isFalse);
  });
}

class _RecordingSurface extends ReaderTextSurface {
  _RecordingSurface(this.events);

  final List<String> events;

  @override
  void goToSearchResult(String cfi) => events.add('result:$cfi');

  @override
  void goToFraction(double fraction) => events.add('fraction:$fraction');

  @override
  void goToBookmark({
    required String cfi,
    required double progress,
    int? anchorSectionIndex,
    int? anchorSectionPage,
    int? anchorVersion,
  }) => events.add('bookmark:$cfi:$progress');
}
