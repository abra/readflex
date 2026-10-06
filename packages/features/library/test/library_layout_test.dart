import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  Widget host(Widget child, {double width = 390}) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    supportedLocales: ReadflexSupportedLocales.locales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  final sources = [
    LibrarySource.fromBook(
      Book(
        id: 'b-1',
        title: 'First',
        filePath: '/b1.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    ),
  ];

  group('filter chip strip', () {
    Widget header({required double width}) {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      return host(
        LibraryHeader(
          state: LibraryState(),
          isOffline: false,
          searchController: controller,
          searchFocusNode: focus,
          onSearchChanged: (_) {},
          onFilterChanged: (_) {},
          onCollectionScopePressed: () {},
          onCollectionScopeCleared: () {},
        ),
        width: width,
      );
    }

    Finder endFade() => find.byWidgetPredicate(
      (w) => w is ScrollEdgeFade && w.edge == ScrollFadeEdge.end,
    );

    testWidgets('shows an end fade while chips are hidden and clears it at '
        'the end of the strip', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(header(width: 320));
      await tester.pump();
      expect(tester.widget<ScrollEdgeFade>(endFade()).visible, isTrue);

      final strip = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(strip, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<ScrollEdgeFade>(endFade()).visible, isFalse);
      final list = tester.widget<ListView>(strip);
      expect(
        list.padding!.resolve(TextDirection.ltr).right,
        AppSpacing.sm,
      );
    });

    testWidgets('wide header has no fade', (tester) async {
      await tester.pumpWidget(header(width: 800));
      await tester.pump();
      expect(tester.widget<ScrollEdgeFade>(endFade()).visible, isFalse);
    });
  });

  group('content clears the FAB', () {
    Widget bothLayouts(ScrollController controller) => Column(
      children: [
        Expanded(
          child: LibraryListView(
            sources: sources,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
        Expanded(
          child: LibraryGridView(
            sources: sources,
            selection: const LibrarySelectionState(),
            scrollController: ScrollController(),
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
          ),
        ),
      ],
    );

    for (final (inset, expected) in [
      (0.0, 96.0),
      (16.0, 96.0),
      (34.0, 114.0),
      (48.0, 128.0),
    ]) {
      testWidgets('clearance covers the FAB, its lift, a content gap and the '
          'safe inset beyond the margin: inset=$inset', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
            child: host(bothLayouts(controller)),
          ),
        );
        final context = tester.element(find.byType(LibraryListView));
        expect(libraryContentBottomPadding(context), expected);
        expect(
          libraryContentBottomPadding(context),
          56 +
              AppSpacing.sm +
              AppSpacing.lg +
              AppSpacing.lg +
              math.max(0, inset - AppSpacing.lg),
        );
        final list = tester.widget<ListView>(find.byType(ListView));
        expect(list.padding!.resolve(TextDirection.ltr).bottom, expected);
        final grid = tester.widget<GridView>(find.byType(GridView));
        expect(grid.padding!.resolve(TextDirection.ltr).bottom, expected);
      });
    }
  });

  testWidgets('list and grid rows start at the same offset and gutter', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget layout(LibraryLayoutMode mode) => host(
      SizedBox(
        height: 400,
        child: switch (mode) {
          LibraryLayoutMode.list => LibraryListView(
            sources: sources,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
          LibraryLayoutMode.grid => LibraryGridView(
            sources: sources,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
          ),
        },
      ),
    );
    await tester.pumpWidget(layout(LibraryLayoutMode.list));
    final listCover = tester.getRect(find.byType(AppSourceCoverFrame));
    await tester.pumpWidget(layout(LibraryLayoutMode.grid));
    final gridCover = tester.getRect(find.byType(AppSourceCoverFrame));
    expect(listCover.left, AppSpacing.lg);
    expect(gridCover.left, AppSpacing.lg);
    expect(listCover.top, kLibraryContentTopPadding);
    expect(gridCover.top, listCover.top);
  });

  testWidgets('grid covers sit on the 16dp gutter in RTL', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: host(
          SizedBox(
            height: 400,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: LibraryGridView(
                sources: sources,
                selection: const LibrarySelectionState(),
                scrollController: controller,
                onSourcePressed: (_) {},
                onSourceLongPressed: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final cover = tester.getRect(find.byType(AppSourceCoverFrame));
    expect(cover.right, 390 - AppSpacing.lg);
    expect(cover.top, kLibraryContentTopPadding);
  });

  testWidgets('grid keeps three phone columns and grows on tablets', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 8; i++)
        LibrarySource.fromBook(
          Book(
            id: 'g-$i',
            title: 'Book $i',
            filePath: '/g$i.epub',
            format: BookFormat.epub,
            addedAt: DateTime(2026),
          ),
        ),
    ];
    Future<int> columnsAt(double width) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 600,
            child: LibraryGridView(
              sources: many,
              selection: const LibrarySelectionState(),
              scrollController: controller,
              onSourcePressed: (_) {},
              onSourceLongPressed: (_) {},
            ),
          ),
          width: width,
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      return delegate.crossAxisCount;
    }

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(await columnsAt(390), 3);
    expect(await columnsAt(1024), greaterThan(3));
    expect(await columnsAt(1024), lessThanOrEqualTo(6));
  });
}
