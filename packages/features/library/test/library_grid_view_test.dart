import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:library_feature/src/library_grid_tile.dart';
import 'package:library_feature/src/library_content_scroll_view.dart';
import 'package:library_feature/src/library_grid_sliver.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

final _sources = [
  for (var i = 0; i < 60; i++)
    LibrarySource(
      id: 'g$i',
      sourceType: SourceType.book,
      title: 'Book $i',
      typeLabel: 'EPUB',
      addedAt: DateTime(2026),
    ),
];

final _reading = LibrarySource(
  id: 'reading',
  sourceType: SourceType.book,
  title: 'A book in progress with a title long enough to wrap',
  typeLabel: 'EPUB',
  addedAt: DateTime(2026),
  readingProgress: .4,
  lastOpenedAt: DateTime(2026, 2),
);

Finder _tile(int index) => find.byKey(ValueKey('library-grid-g$index'));

/// Tiles laid out on the first row of the grid.
int _columnsOnScreen(WidgetTester tester) {
  final top = tester.getTopLeft(_tile(0)).dy;
  var columns = 0;
  while (_tile(columns).evaluate().isNotEmpty &&
      tester.getTopLeft(_tile(columns)).dy == top) {
    columns++;
  }
  return columns;
}

/// The tile and card elements mounted now that build again during [frames].
/// Tiles mounted later are new elements, not rebuilds.
Future<List<Element>> _rebuiltDuring(
  WidgetTester tester,
  Future<void> Function() frames,
) async {
  final watched = {
    ...find.byType(BookLibraryGridTile).evaluate(),
    ...find.byType(LibraryContinueReadingCard).evaluate(),
  };
  expect(watched.length, greaterThan(3));
  final rebuilt = <Element>[];
  debugOnRebuildDirtyWidget = (element, _) {
    if (watched.contains(element)) rebuilt.add(element);
  };
  try {
    await frames();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return rebuilt;
}

void main() {
  late ScrollController controller;

  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  // Built once, as the Library body does, so only layout changes reach it.
  LibraryContentScrollView grid({bool continueReading = true}) =>
      LibraryContentScrollView(
        layoutMode: LibraryLayoutMode.grid,
        sources: _sources,
        continueReadingSource: continueReading ? _reading : null,
        selection: const LibrarySelectionState(),
        scrollController: controller,
        onSourcePressed: (_) {},
        onSourceLongPressed: (_) {},
        onConfirmSwipeDelete: (_) async => false,
      );

  Widget app(Widget body) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    supportedLocales: ReadflexSupportedLocales.locales,
    home: Scaffold(body: body),
  );

  void useWindow(WidgetTester tester, Size size) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final (name, window, columns) in [
    ('phone', const Size(390, 844), 3),
    ('tablet', const Size(1376, 1032), 8),
  ]) {
    testWidgets('keyboard frames rebuild no tile or card: $name', (
      tester,
    ) async {
      useWindow(tester, window);
      await tester.pumpWidget(app(grid()));
      final viewport = find.byType(CustomScrollView);
      final resting = tester.getSize(viewport).height;
      final scrollView = tester.widget(viewport);
      final tile = tester.widget(_tile(0));
      final card = tester.widget(find.byType(LibraryContinueReadingCard));
      expect(_columnsOnScreen(tester), columns);

      final rebuilt = await _rebuiltDuring(tester, () async {
        for (final keyboard in [
          for (var frame = 1; frame <= 20; frame++) 16.0 * frame,
          for (var frame = 19; frame >= 0; frame--) 16.0 * frame,
        ]) {
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          await tester.pump();
          // The body really shrinks with the keyboard.
          expect(tester.getSize(viewport).height, resting - keyboard);
          expect(_columnsOnScreen(tester), columns);
        }
      });

      expect(rebuilt, isEmpty);
      expect(tester.widget(viewport), same(scrollView));
      expect(tester.widget(_tile(0)), same(tile));
      expect(
        tester.widget(find.byType(LibraryContinueReadingCard)),
        same(card),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a width change relayouts the columns', (tester) async {
    useWindow(tester, const Size(1400, 1000));
    final width = ValueNotifier<double>(390);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (_, value, child) => SizedBox(width: value, child: child),
            child: grid(),
          ),
        ),
      ),
    );

    for (final (value, columns) in [
      (390.0, 3),
      (1376.0, 8),
      (834.0, 6),
      (320.0, 3),
      (1194.0, 7),
      (390.0, 3),
    ]) {
      width.value = value;
      await tester.pump();
      expect(libraryGridColumnCount(value, textScale: 1), columns);
      expect(_columnsOnScreen(tester), columns, reason: '$value');
      // Tiles share the width inside the 16dp gutters and 12dp gaps.
      expect(
        tester.getSize(_tile(0)).width,
        closeTo(
          (value - AppSpacing.lg * 2 - AppSpacing.md * (columns - 1)) / columns,
          .001,
        ),
        reason: '$value',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a text scale change relayouts the columns', (tester) async {
    useWindow(tester, const Size(390, 844));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // Without the card, whose new height would relayout every sliver, only
    // the grid's own delegate can ask for new columns.
    await tester.pumpWidget(app(grid(continueReading: false)));
    expect(_columnsOnScreen(tester), 3);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    expect(_columnsOnScreen(tester), 2);

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();
    expect(_columnsOnScreen(tester), 3);
    expect(tester.takeException(), isNull);
  });
}
