import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_empty_state.dart';
import 'package:library_feature/src/library_content_scroll_view.dart';
import 'package:library_feature/src/library_grid_sliver.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_selection_bar.dart';
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

/// The first label in [node]'s subtree: what a screen reader reads for it.
String _semanticsLabel(SemanticsNode node) {
  if (node.label.isNotEmpty) return node.label;
  var label = '';
  node.visitChildren((child) {
    label = _semanticsLabel(child);
    return label.isEmpty;
  });
  return label;
}

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
            body: LibraryContentScrollView(
              layoutMode: LibraryLayoutMode.grid,
              sources: _sources(9),
              selection: const LibrarySelectionState(),
              scrollController: controller,
              onSourcePressed: (_) {},
              onSourceLongPressed: (_) {},
              onConfirmSwipeDelete: (_) async => false,
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
      LibrarySource? continueReadingSource,
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
              body: LibraryContentScrollView(
                layoutMode: LibraryLayoutMode.list,
                sources: _sources(count),
                continueReadingSource: continueReadingSource,
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

    for (final window in const [_tabletLandscape, _phonePortrait]) {
      testWidgets('screen readers count sources, not lines ($window)', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpList(
            tester,
            window: window,
            count: 3,
            continueReadingSource: _sources(4).last,
          );

          final list = find.semantics
              .byPredicate((node) => node.scrollChildCount != null)
              .evaluate()
              .single;
          expect(list.scrollChildCount, 4);
          // Flutter takes the first visible index from the viewport's
          // children in paint order, so the card's own sliver above the
          // rows is passed over: the rows start the count at 1.
          expect(list.scrollIndex, 1);
          final items = <int?, String>{};
          list.visitChildren((item) {
            items[item.indexInParent] = _semanticsLabel(item);
            return true;
          });
          expect(items, {0: 'Book 3', 1: 'Book 0', 2: 'Book 1', 3: 'Book 2'});
        } finally {
          semantics.dispose();
        }
      });
    }

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

    testWidgets('the column stops at the onboarding width', (tester) async {
      for (final window in const [
        _tabletPortrait,
        _tabletLandscape,
        // iPad Air 11-inch and iPad mini in portrait: narrow, not phones.
        Size(820, 1180),
        Size(744, 1133),
        // A Split View half and a phone in landscape.
        Size(678, 1032),
        _phoneLandscape,
      ]) {
        final button = await uploadButton(tester, window);
        expect(
          button.width,
          AppSizes.centeredColumnMaxWidth,
          reason: '$window',
        );
        expect(button.center.dx, closeTo(window.width / 2, 0.01));
      }
    });

    testWidgets('phones in portrait keep buttons across the screen', (
      tester,
    ) async {
      for (final window in const [Size(320, 568), _phonePortrait]) {
        final button = await uploadButton(tester, window);
        expect(
          button.width,
          window.width - AppSpacing.lg * 2,
          reason: '$window',
        );
      }
    });
  });

  group('selection bar', () {
    // The smallest wide window: Split View halves and phones stay narrow.
    const smallestWide = Size(840, 480);

    Future<void> pumpBar(
      WidgetTester tester, {
      required Size window,
      double ratio = 1,
      double textScale = 1,
      String locale = 'en',
    }) async {
      tester.view
        ..physicalSize = window * ratio
        ..devicePixelRatio = ratio;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final cubit = LibrarySelectionCubit()
        ..toggle('b-0')
        ..toggle('b-1');
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: Locale(locale),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              floatingActionButton: LibrarySelectionBar(
                onAddToCollection: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
    }

    final close = find.byKey(const ValueKey('libraryCancelSelectionFab'));
    final delete = find.byKey(const ValueKey('libraryDeleteSelectedButton'));
    final add = find.byKey(const ValueKey('libraryAddToCollectionButton'));
    final capsule = find.byKey(const ValueKey('librarySelectionCapsule'));

    final count = find.byKey(const ValueKey('librarySelectedCount'));

    for (final window in const [
      _tabletPortrait,
      _tabletLandscape,
      smallestWide,
    ]) {
      testWidgets(
        'a wide window separates cancel from the action capsule ($window)',
        (
          tester,
        ) async {
          await pumpBar(tester, window: window);
          final closeRect = tester.getRect(close);
          final capsuleRect = tester.getRect(capsule);
          for (final item in [count, add, delete]) {
            final bounds = tester.getRect(item);
            expect(bounds.left, greaterThanOrEqualTo(capsuleRect.left));
            expect(bounds.right, lessThanOrEqualTo(capsuleRect.right));
            expect(
              bounds.bottom,
              lessThanOrEqualTo(capsuleRect.bottom),
              reason: '$item',
            );
          }
          expect(closeRect.left, closeTo(AppSpacing.lg, .5));
          expect(
            window.width - capsuleRect.right,
            closeTo(AppSpacing.lg, .5),
          );
          expect(
            capsuleRect.left - closeRect.right,
            greaterThanOrEqualTo(AppSpacing.md),
          );
          expect(capsuleRect.bottom, closeTo(closeRect.bottom, .5));
          expect(closeRect.width, greaterThanOrEqualTo(56));
          expect(closeRect.height, greaterThanOrEqualTo(56));
          for (final control in [add, delete]) {
            expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
            expect(control.hitTestable(), findsOneWidget);
          }
          expect(
            find.descendant(
              of: find.byType(LibrarySelectionBar),
              matching: find.byType(Divider),
            ),
            findsNothing,
            reason: 'floating actions do not reserve a bottom navigation bar',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('right-to-left mirrors the row', (tester) async {
      await pumpBar(tester, window: _tabletLandscape, locale: 'ar');
      expect(
        _tabletLandscape.width - tester.getRect(close).right,
        closeTo(AppSpacing.lg, .5),
      );
      expect(tester.getRect(capsule).left, closeTo(AppSpacing.lg, .5));
      expect(
        tester.getRect(close).left - tester.getRect(capsule).right,
        greaterThanOrEqualTo(AppSpacing.md),
      );
      expect(
        tester.getRect(count).right,
        lessThan(tester.getRect(close).left),
      );
      expect(tester.getRect(delete).right, lessThan(tester.getRect(add).left));
    });

    for (final window in const [_phonePortrait, _phoneLandscape]) {
      testWidgets(
        'a phone keeps cancel separate from the floating capsule ($window)',
        (
          tester,
        ) async {
          await pumpBar(tester, window: window);
          final closeRect = tester.getRect(close);
          final capsuleRect = tester.getRect(capsule);
          expect(closeRect.left, closeTo(AppSpacing.lg, .5));
          expect(capsuleRect.left, greaterThan(closeRect.right));
          expect(capsuleRect.bottom, closeTo(closeRect.bottom, .5));
          expect(
            window.width - capsuleRect.right,
            closeTo(AppSpacing.lg, .5),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final locale in ReadflexSupportedLocales.locales) {
      for (final (window, ratio, textScale) in const [
        (smallestWide, 1.0, 1.0),
        (smallestWide, 1.0, 2.0),
        (_tabletPortrait, 2.0, 1.0),
        (_phonePortrait, 1.0, 1.0),
        (Size(320, 568), 1.0, 1.0),
        (Size(320, 568), 2.0, 1.0),
      ]) {
        testWidgets(
          'the bar lays out (${window.width.round()}@${ratio.round()}x, '
          'text ${textScale}x, ${locale.toLanguageTag()})',
          (tester) async {
            await pumpBar(
              tester,
              window: window,
              ratio: ratio,
              textScale: textScale,
              locale: locale.toLanguageTag(),
            );
            expect(tester.takeException(), isNull);
            // Synthetic glyphs are wider than the app font; the root suite
            // checks real label wrapping. Here every action stays reachable.
            for (final control in [close, add, delete]) {
              expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
              expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
              expect(control.hitTestable(), findsOneWidget);
            }
            expect(
              tester.getRect(capsule).bottom,
              closeTo(tester.getRect(close).bottom, .5),
            );
          },
        );
      }
    }
  });
}
