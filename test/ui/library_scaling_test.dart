import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_grid_tile.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/library_workload.dart';

void main() {
  for (final list in [false, true]) {
    testWidgets('20000 sources stay virtualized in ${list ? 'list' : 'grid'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = LibraryState(books: libraryWorkload(20000));
      final sources = state.visibleItems;
      expect(identical(state.visibleItems, sources), isTrue);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var opened = '';
      var longPressed = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: list
                ? LibraryListView(
                    sources: sources,
                    selection: const LibrarySelectionState(),
                    scrollController: scroll,
                    onSourcePressed: (source) => opened = source.id,
                    onSourceLongPressed: (source) => longPressed = source.id,
                    onConfirmSwipeDelete: (_) async => false,
                  )
                : LibraryGridView(
                    sources: sources,
                    selection: const LibrarySelectionState(),
                    scrollController: scroll,
                    onSourcePressed: (source) => opened = source.id,
                    onSourceLongPressed: (source) => longPressed = source.id,
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tiles = list
          ? find.byType(BookLibraryListTile)
          : find.byType(BookLibraryGridTile);
      expect(tiles.evaluate().length, inInclusiveRange(1, 60));
      await tester.tap(tiles.hitTestable().first);
      expect(opened, sources.first.id);
      await tester.longPress(tiles.hitTestable().first);
      expect(longPressed, sources.first.id);
      for (var page = 0; page < 5; page++) {
        scroll.jumpTo(scroll.offset + 700);
        await tester.pumpAndSettle();
        expect(
          tiles.evaluate().length,
          lessThanOrEqualTo(60),
          reason: 'Offscreen tiles must not accumulate while scrolling',
        );
      }
      expect(identical(state.visibleItems, sources), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test(
    'large library derives filters once per state and keeps source inputs',
    () {
      final books = libraryWorkload(20000);
      final state = LibraryState(books: books);
      expect(state.visibleItems.first.id, 'workload-19999');
      for (var read = 0; read < 1000; read++) {
        expect(identical(state.visibleItems, state.visibleItems), isTrue);
      }
      final filtered = state.copyWith(searchQuery: 'BOOK 19999');
      expect(filtered.visibleItems.single.id, 'workload-19999');
      expect(identical(filtered.books, state.books), isTrue);
      expect(state.visibleItems, hasLength(20000));
      expect(
        state.copyWith(filter: LibraryFilter.unread).visibleItems,
        hasLength(10000),
      );
    },
  );
}
