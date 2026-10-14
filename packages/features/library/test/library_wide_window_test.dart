import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_empty_state.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const _tabletPortrait = Size(1032, 1376);
const _tabletLandscape = Size(1376, 1032);
const _phonePortrait = Size(390, 844);
const _phoneLandscape = Size(844, 390);

List<LibrarySource> _sources(int count) => [
  for (var i = 0; i < count; i++)
    LibrarySource.fromBook(
      Book(
        id: 'b-$i',
        title: 'Book $i',
        author: 'Author $i',
        filePath: '/books/$i.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    ),
];

/// The grid's column rule before tablets: phones must keep it exactly.
int _phoneColumns(double width, double textScale) =>
    ((width - AppSpacing.lg * 2 + AppSpacing.md) /
            (88 * textScale.clamp(1.0, 1.5) + AppSpacing.md))
        .floor()
        .clamp(1, 6);

double _tileWidth(double width, int columns) =>
    (width - AppSpacing.lg * 2 - AppSpacing.md * (columns - 1)) / columns;

void main() {
  group('grid columns', () {
    test('every phone width keeps its columns at every text size', () {
      for (final scale in const [1.0, 1.15, 1.3, 1.5, 2.0]) {
        for (var width = 320.0; width <= 932; width++) {
          expect(
            libraryGridColumnCount(width, textScale: scale),
            _phoneColumns(width, scale),
            reason: 'width $width, text $scale',
          );
        }
      }
    });

    test('tablets add columns instead of growing covers', () {
      expect(libraryGridColumnCount(1032, textScale: 1), 6);
      expect(libraryGridColumnCount(1194, textScale: 1), 7);
      expect(libraryGridColumnCount(1376, textScale: 1), 8);
      for (var width = 840.0; width <= 2560; width += 8) {
        final columns = libraryGridColumnCount(width, textScale: 1);
        expect(
          _tileWidth(width, columns),
          lessThanOrEqualTo(160),
          reason: 'width $width',
        );
      }
    });

    test('large text keeps bigger tiles on tablets', () {
      // 150% text allows covers up to 240: a 13-inch tablet keeps six.
      expect(libraryGridColumnCount(1376, textScale: 1.5), 6);
      expect(
        libraryGridColumnCount(1376, textScale: 2),
        libraryGridColumnCount(1376, textScale: 1.5),
      );
    });

    testWidgets('the grid lays out the computed columns', (tester) async {
      tester.view
        ..physicalSize = _tabletLandscape
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: LibraryGridView(
              sources: _sources(9),
              selection: const LibrarySelectionState(),
              scrollController: controller,
              onSourcePressed: (_) {},
              onSourceLongPressed: (_) {},
            ),
          ),
        ),
      );

      final firstRowTop = tester
          .getTopLeft(find.byKey(const ValueKey('library-grid-b-0')))
          .dy;
      final firstRow = [
        for (var i = 0; i < 9; i++)
          if (tester.getTopLeft(find.byKey(ValueKey('library-grid-b-$i'))).dy ==
              firstRowTop)
            i,
      ];
      expect(firstRow, hasLength(8));
      expect(
        tester.getSize(find.byKey(const ValueKey('library-grid-b-0'))).width,
        closeTo(_tileWidth(_tabletLandscape.width, 8), 0.5),
      );
    });
  });

  group('list columns', () {
    Future<void> pumpList(
      WidgetTester tester, {
      required Size window,
      int count = 5,
      LibrarySelectionState selection = const LibrarySelectionState(),
      TextDirection textDirection = TextDirection.ltr,
      List<LibrarySource>? deleteRequests,
    }) async {
      tester.view
        ..physicalSize = window
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Directionality(
            textDirection: textDirection,
            child: Scaffold(
              body: LibraryListView(
                sources: _sources(count),
                selection: selection,
                scrollController: controller,
                onSourcePressed: (_) {},
                onSourceLongPressed: (_) {},
                onConfirmSwipeDelete: (source) async {
                  deleteRequests?.add(source);
                  return false;
                },
              ),
            ),
          ),
        ),
      );
    }

    Rect titleRect(WidgetTester tester, int index) =>
        tester.getRect(find.text('Book $index'));

    for (final window in const [_tabletPortrait, _tabletLandscape]) {
      testWidgets('a wide window reads across then down ($window)', (
        tester,
      ) async {
        await pumpList(tester, window: window);

        expect(titleRect(tester, 0).top, titleRect(tester, 1).top);
        expect(titleRect(tester, 1).left, greaterThan(window.width / 2));
        expect(titleRect(tester, 2).top, greaterThan(titleRect(tester, 0).top));
        expect(titleRect(tester, 2).left, titleRect(tester, 0).left);
        expect(titleRect(tester, 3).top, titleRect(tester, 2).top);
        // An odd count leaves the last line's end column empty.
        expect(titleRect(tester, 4).left, titleRect(tester, 0).left);
      });
    }

    testWidgets('columns keep the screen gutters and the grid gap', (
      tester,
    ) async {
      await pumpList(tester, window: _tabletLandscape);
      final covers = find.byKey(const ValueKey('libraryListCoverSlot'));
      final firstCover = tester.getRect(covers.at(0));
      final secondCover = tester.getRect(covers.at(1));
      final firstRow = tester.getRect(find.byType(BookLibraryListTile).at(0));
      final secondRow = tester.getRect(find.byType(BookLibraryListTile).at(1));

      expect(firstCover.left, AppSpacing.lg);
      expect(firstRow.right, closeTo(_tabletLandscape.width / 2, 0.01));
      expect(secondRow.left, closeTo(_tabletLandscape.width / 2, 0.01));
      expect(
        secondCover.left,
        closeTo(secondRow.left + AppSpacing.md / 2, 0.01),
      );
      expect(secondRow.right, _tabletLandscape.width);
    });

    testWidgets('every line after the first starts with both hairlines', (
      tester,
    ) async {
      await pumpList(tester, window: _tabletLandscape, count: 4);
      final dividers = find.byKey(const ValueKey('libraryListRowTopDivider'));

      expect(dividers, findsNWidgets(2));
      final start = tester.getRect(dividers.at(0));
      final end = tester.getRect(dividers.at(1));
      expect(start.top, end.top);
      expect(start.left, AppSpacing.lg);
      expect(start.right, closeTo(_tabletLandscape.width / 2 - 6, 0.01));
      expect(end.left, closeTo(_tabletLandscape.width / 2 + 6, 0.01));
      expect(end.right, _tabletLandscape.width - AppSpacing.lg);
      expect(start.top, lessThan(titleRect(tester, 2).top));
      expect(start.top, greaterThan(titleRect(tester, 0).bottom));
    });

    testWidgets('right-to-left puts the first source on the right', (
      tester,
    ) async {
      await pumpList(
        tester,
        window: _tabletLandscape,
        textDirection: TextDirection.rtl,
      );
      expect(
        titleRect(tester, 0).right,
        greaterThan(titleRect(tester, 1).right),
      );
      final firstCover = tester.getRect(
        find.byKey(const ValueKey('libraryListCoverSlot')).at(0),
      );
      expect(firstCover.right, _tabletLandscape.width - AppSpacing.lg);
    });

    testWidgets('rows swipe to delete one at a time, not while selecting', (
      tester,
    ) async {
      final requests = <LibrarySource>[];
      await pumpList(
        tester,
        window: _tabletLandscape,
        deleteRequests: requests,
      );
      expect(find.byType(Dismissible), findsNWidgets(5));
      await tester.drag(find.text('Book 1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(requests.map((source) => source.id), ['b-1']);

      await pumpList(
        tester,
        window: _tabletLandscape,
        selection: const LibrarySelectionState(selectedIds: {'b-1'}),
      );
      expect(find.byType(Dismissible), findsNothing);
    });

    for (final window in const [_phonePortrait, _phoneLandscape]) {
      testWidgets('a phone keeps one column ($window)', (tester) async {
        await pumpList(tester, window: window, count: 3);
        expect(
          titleRect(tester, 1).top,
          greaterThan(titleRect(tester, 0).top),
        );
        expect(titleRect(tester, 1).left, titleRect(tester, 0).left);
        final row = tester.getRect(find.byType(BookLibraryListTile).first);
        expect(row.width, window.width);
      });
    }
  });

  group('empty state', () {
    Future<Rect> uploadButton(WidgetTester tester, Size window) async {
      tester.view
        ..physicalSize = window
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(body: LibraryEmptyState(onImportPressed: (_) {})),
        ),
      );
      return tester.getRect(
        find.byKey(const ValueKey('libraryEmptyUploadFile')),
      );
    }

    testWidgets('a wide window stops the column at the onboarding width', (
      tester,
    ) async {
      for (final window in const [_tabletPortrait, _tabletLandscape]) {
        final button = await uploadButton(tester, window);
        expect(
          button.width,
          AppSizes.centeredColumnMaxWidth,
          reason: '$window',
        );
        expect(button.center.dx, closeTo(window.width / 2, 0.01));
      }
    });

    testWidgets('phones keep buttons across the screen', (tester) async {
      for (final window in const [_phonePortrait, _phoneLandscape]) {
        final button = await uploadButton(tester, window);
        expect(
          button.width,
          math.max(0, window.width - AppSpacing.lg * 2),
          reason: '$window',
        );
      }
    });
  });
}
