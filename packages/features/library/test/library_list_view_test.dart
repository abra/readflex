import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_selection_tint.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

final _books = [
  Book(
    id: 'b-1',
    title: 'First Book',
    author: 'Author',
    filePath: '/books/first.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  ),
  Book(
    id: 'b-2',
    title: 'Second Book',
    author: 'Author',
    filePath: '/books/second.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  ),
];

final _article = Article(
  id: 'a-1',
  title: 'Saved Article',
  url: 'https://example.com/article',
  siteName: 'Example',
  contentPath: '/articles/a-1/article.json',
  addedAt: DateTime(2026),
);

void main() {
  testWidgets('list tile exposes source semantics and reader action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final openedArticle = _article.copyWith(
      readingProgress: 0.2,
      lastOpenedAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookLibraryListTile(
            source: LibrarySource.fromArticle(openedArticle),
            showTopDivider: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Saved Article')),
      matchesSemantics(
        label: 'Saved Article',
        value: 'Article, Example, 20 percent read',
        isButton: true,
        hasTapAction: true,
        hasLongPressAction: true,
        onTapHint: 'Open reader',
        onLongPressHint: 'Select source',
      ),
    );

    semantics.dispose();
  });

  testWidgets('selected list tile exposes selection tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookLibraryListTile(
            source: LibrarySource.fromBook(_books.first),
            showTopDivider: false,
            isSelected: true,
            isSelectionMode: true,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('First Book')),
      matchesSemantics(
        label: 'First Book',
        value: 'Book, Author, EPUB, New',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        hasLongPressAction: true,
        onTapHint: 'Deselect source',
      ),
    );

    semantics.dispose();
  });

  testWidgets(
    'selected list cover uses the selection marker, not delete color',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BookLibraryListTile(
              source: LibrarySource.fromBook(_books.first),
              showTopDivider: false,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      );

      final colors = Theme.of(
        tester.element(find.byType(BookLibraryListTile)),
      ).colorScheme;
      final selectionColor = colors.selectionMarkerBackground;
      expect(selectionColor, isNot(colors.error));
      final selectionDecoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .singleWhere(
            (decoration) =>
                decoration.border is Border &&
                (decoration.border! as Border).top.color == selectionColor &&
                (decoration.border! as Border).top.width == 2,
          );

      expect(selectionDecoration.color, selectionColor.withValues(alpha: 0.15));

      final coverRect = tester.getRect(find.byType(AppSourceCoverFrame));
      final checkRect = tester.getRect(
        find.byKey(const ValueKey('libraryListSelectionCheck')),
      );
      expect(checkRect.top, coverRect.top + AppSpacing.xs);
      expect(checkRect.right, coverRect.right - AppSpacing.xs);
    },
  );

  testWidgets('selected list background follows cover height', (
    tester,
  ) async {
    const longTitle =
        'A selected library book title that wraps across several list lines';
    final source = LibrarySource.fromBook(
      Book(
        id: 'b-selected-long-title',
        title: longTitle,
        filePath: '/books/selected.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: BookLibraryListTile(
              source: source,
              showTopDivider: false,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final rowRect = tester.getRect(find.byType(GestureDetector));
    final coverRect = tester.getRect(
      find.byKey(const ValueKey('libraryListCoverSlot')),
    );
    final backgroundRect = tester.getRect(
      find.byKey(const ValueKey('libraryListSelectionBackground')),
    );

    expect(rowRect.height, greaterThan(backgroundRect.height));
    expect(backgroundRect.top, closeTo(coverRect.top - AppSpacing.xs, 0.1));
    expect(
      backgroundRect.bottom,
      closeTo(coverRect.bottom + AppSpacing.xs, 0.1),
    );
    // Full-bleed tint; the content keeps the 16dp gutter.
    expect(backgroundRect.left, rowRect.left);
    expect(backgroundRect.right, rowRect.right);
    expect(coverRect.left, rowRect.left + AppSpacing.lg);
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    for (final selected in [false, true]) {
      testWidgets(
        'list metadata contrast: ${theme.brightness}, selected=$selected',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Column(
                  children: [
                    for (final source in [
                      LibrarySource.fromBook(_books.first),
                      LibrarySource.fromArticle(_article),
                    ])
                      BookLibraryListTile(
                        source: source,
                        showTopDivider: false,
                        isSelected: selected,
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            ),
          );
          var background = theme.scaffoldBackgroundColor;
          if (selected) {
            final tint = tester
                .widget<ColoredBox>(
                  find
                      .byKey(const ValueKey('libraryListSelectionBackground'))
                      .first,
                )
                .color;
            background = Color.alphaBlend(tint, background);
          }
          final metadata = find.descendant(
            of: find.byKey(const ValueKey('libraryListRowMeta')),
            matching: find.byType(Text),
          );
          expect(metadata, findsWidgets);
          for (final text in tester.widgetList<Text>(metadata)) {
            final foreground = Color.alphaBlend(text.style!.color!, background);
            final a = foreground.computeLuminance();
            final b = background.computeLuminance();
            final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
            expect(ratio, greaterThanOrEqualTo(4.5), reason: text.data);
          }
        },
      );
    }
    testWidgets(
      'list separators use the shared theme above shadows: ${theme.brightness}',
      (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: LibraryListView(
                sources: _books.map(LibrarySource.fromBook).toList(),
                selection: const LibrarySelectionState(),
                scrollController: controller,
                onSourcePressed: (_) {},
                onSourceLongPressed: (_) {},
                onConfirmSwipeDelete: (_) async => false,
              ),
            ),
          ),
        );

        final dividerFinder = find.byKey(
          const ValueKey('libraryListRowTopDivider'),
        );
        expect(dividerFinder, findsOneWidget);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: dividerFinder,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        final border = decoration.border! as Border;
        expect(border.bottom.color, theme.dividerTheme.color);
        expect(border.bottom.width, theme.dividerTheme.thickness);

        final dividerTop = tester.getTopLeft(dividerFinder).dy;
        final dividerLeft = tester.getTopLeft(dividerFinder).dx;
        final firstTitleTop = tester.getTopLeft(find.text('First Book')).dy;
        final secondTitleOffset = tester.getTopLeft(find.text('Second Book'));

        expect(dividerTop, greaterThan(firstTitleTop));
        expect(dividerTop, lessThan(secondTitleOffset.dy));
        expect(dividerLeft, AppSpacing.lg);
        expect(
          tester.getTopRight(dividerFinder).dx,
          tester.getSize(find.byType(LibraryListView)).width - AppSpacing.lg,
        );
        expect(dividerLeft, lessThan(secondTitleOffset.dx));
      },
    );
  }

  testWidgets('article list row uses readable type label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryListView(
            sources: [LibrarySource.fromArticle(_article)],
            selection: const LibrarySelectionState(),
            scrollController: ScrollController(),
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      ),
    );

    expect(find.text('ARTICLE'), findsNothing);
    expect(find.text('Article'), findsWidgets);
    expect(find.text('Example'), findsWidgets);
  });

  testWidgets('list row title can wrap to four lines', (tester) async {
    const longTitle =
        'A very long saved article title that needs four readable lines in list mode';
    final source = LibrarySource.fromArticle(
      Article(
        id: 'a-long-title',
        title: longTitle,
        url: 'https://example.com/long-title',
        siteName: 'Example',
        contentPath: '/articles/a-long-title/article.json',
        addedAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BookLibraryListTile(
              source: source,
              showTopDivider: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(longTitle));

    expect(title.maxLines, 4);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('RTL list row aligns source info to the right edge', (
    tester,
  ) async {
    final rtlArticle = Article(
      id: 'a-rtl',
      title: 'مقال عربي',
      url: 'https://example.com/ar',
      siteName: 'الجزيرة',
      language: 'ar',
      contentPath: '/articles/a-rtl/article.json',
      addedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BookLibraryListTile(
              source: LibrarySource.fromArticle(rtlArticle),
              showTopDivider: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(rtlArticle.title));
    final metaRow = tester.widget<Row>(
      find.byKey(const ValueKey('libraryListRowMeta')),
    );
    final rowRect = tester.getRect(find.byType(GestureDetector));
    final titleRect = tester.getRect(find.text(rtlArticle.title));

    expect(title.textDirection, TextDirection.rtl);
    expect(title.textAlign, TextAlign.start);
    expect(metaRow.textDirection, TextDirection.rtl);
    expect(titleRect.right, closeTo(rowRect.right - AppSpacing.lg, 1));
  });

  testWidgets('RTL swipe reveals the delete icon inside the revealed area', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: LibraryListView(
              sources: [LibrarySource.fromBook(_books.first)],
              selection: const LibrarySelectionState(),
              scrollController: controller,
              onSourcePressed: (_) {},
              onSourceLongPressed: (_) {},
              onConfirmSwipeDelete: (_) async => false,
            ),
          ),
        ),
      ),
    );

    final tile = find.byType(BookLibraryListTile);
    final restingRect = tester.getRect(tile);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    // endToStart in RTL is a left-to-right drag; the first move only
    // resolves the gesture arena, the second one moves the row.
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    final movedRect = tester.getRect(tile);
    expect(movedRect.left, greaterThan(restingRect.left + 60));
    final revealed = Rect.fromLTRB(
      restingRect.left,
      restingRect.top,
      movedRect.left,
      restingRect.bottom,
    );
    final icon = tester.getRect(find.byIcon(AppIcons.delete));
    expect(revealed.contains(icon.topLeft), isTrue);
    expect(revealed.contains(icon.bottomRight), isTrue);
    expect(icon.left, closeTo(restingRect.left + AppSpacing.lg, 1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(tile), restingRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list selection check sits at the top-end corner in RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BookLibraryListTile(
              source: LibrarySource.fromBook(_books.first),
              showTopDivider: false,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final coverRect = tester.getRect(find.byType(AppSourceCoverFrame));
    final checkRect = tester.getRect(
      find.byKey(const ValueKey('libraryListSelectionCheck')),
    );
    expect(checkRect.top, coverRect.top + AppSpacing.xs);
    expect(checkRect.left, coverRect.left + AppSpacing.xs);
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets(
      'selected row uses the paired selected-control colors: '
      '${theme.brightness}',
      (tester) async {
        final finished = _books.first.copyWith(
          isFinished: true,
          lastOpenedAt: DateTime(2026, 1, 2),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: BookLibraryListTile(
                source: LibrarySource.fromBook(finished),
                showTopDivider: false,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        );
        final colors = theme.colorScheme;
        final background = tester.widget<ColoredBox>(
          find.byKey(const ValueKey('libraryListSelectionBackground')),
        );
        expect(background.color, colors.selectedControlBackground);
        expect(
          tester.widget<Text>(find.text(_books.first.title)).style!.color,
          colors.selectedControlForeground,
        );
        final metadata = find.descendant(
          of: find.byKey(const ValueKey('libraryListRowMeta')),
          matching: find.byType(Text),
        );
        for (final text in tester.widgetList<Text>(metadata)) {
          expect(
            text.style!.color,
            colors.selectedControlForeground,
            reason: text.data,
          );
        }
        final coverTint = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .singleWhere(
              (decoration) =>
                  decoration.border is Border &&
                  (decoration.border! as Border).top.width == 2,
            );
        expect(
          coverTint.color,
          colors.selectionMarkerBackground.withValues(
            alpha: kLibraryCoverSelectionTintAlpha,
          ),
        );
      },
    );
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('list cover and header title share the 16dp gutter ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      final searchController = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(searchController.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: Column(
              children: [
                LibraryHeader(
                  state: LibraryState(),
                  isOffline: false,
                  searchController: searchController,
                  searchFocusNode: focus,
                  onSearchChanged: (_) {},
                ),
                Expanded(
                  child: LibraryListView(
                    sources: _books.map(LibrarySource.fromBook).toList(),
                    selection: const LibrarySelectionState(),
                    scrollController: controller,
                    onSourcePressed: (_) {},
                    onSourceLongPressed: (_) {},
                    onConfirmSwipeDelete: (_) async => false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final strings = tester.element(find.byType(LibraryHeader)).l10n;
      final title = tester.getRect(find.text(strings.libraryTitle));
      final cover = tester.getRect(find.byType(AppSourceCoverFrame).first);
      final text = tester.getRect(find.text('First Book'));
      final divider = tester.getRect(
        find.byKey(const ValueKey('libraryListRowTopDivider')),
      );
      final header = tester.getRect(find.byType(LibraryHeader));
      if (locale.languageCode == 'ar') {
        expect(cover.right, closeTo(390 - AppSpacing.lg, .01));
        expect(cover.right, closeTo(title.right, .01));
        expect(text.right, lessThan(cover.left));
      } else {
        expect(cover.left, closeTo(AppSpacing.lg, .01));
        expect(cover.left, closeTo(title.left, .01));
        expect(text.left, greaterThan(cover.right));
      }
      expect(divider.left, AppSpacing.lg);
      expect(divider.right, 390 - AppSpacing.lg);
      expect(
        cover.top,
        closeTo(header.bottom + kLibraryContentTopPadding, .01),
      );
    });
  }

  testWidgets('swipe background is full width and its glyph ends 16dp from '
      'the edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryListView(
            sources: [LibrarySource.fromBook(_books.first)],
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      ),
    );
    final tile = find.byType(BookLibraryListTile);
    final resting = tester.getRect(tile);
    expect(resting.left, 0);
    expect(resting.right, 390);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    final background = tester.getRect(
      find.byKey(const ValueKey('librarySwipeDeleteBackground')),
    );
    final icon = tester.getRect(
      find.byKey(const ValueKey('librarySwipeDeleteIcon')),
    );
    expect(background.left, 0);
    expect(background.right, 390);
    expect(icon.right, closeTo(390 - AppSpacing.lg, .01));
    expect(tester.getRect(tile).right, lessThan(icon.left));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(tile), resting);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection tint is full-bleed in RTL while content keeps the '
      'gutter', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BookLibraryListTile(
              source: LibrarySource.fromBook(_books.first),
              showTopDivider: true,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final tint = tester.getRect(
      find.byKey(const ValueKey('libraryListSelectionBackground')),
    );
    final cover = tester.getRect(
      find.byKey(const ValueKey('libraryListCoverSlot')),
    );
    final divider = tester.getRect(
      find.byKey(const ValueKey('libraryListRowTopDivider')),
    );
    expect(tint.left, 0);
    expect(tint.right, 390);
    expect(cover.right, 390 - AppSpacing.lg);
    expect(divider.left, AppSpacing.lg);
    expect(divider.right, 390 - AppSpacing.lg);
  });
}
