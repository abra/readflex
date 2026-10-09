import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_list_cover_slot.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

final _article = LibrarySource.fromArticle(
  Article(
    id: 'a-1',
    title: 'The Long Read',
    author: 'Ada Writer',
    url: 'https://example.com/long',
    siteName: 'Example',
    contentPath: '/articles/a-1/article.json',
    addedAt: DateTime(2026),
    // 12000 chars at 1200/min: 10 minutes; 58% left rounds up to 6.
    textLength: 12000,
    readingProgress: 0.42,
    lastOpenedAt: DateTime(2026, 2, 1),
  ),
);

final _book = LibrarySource.fromBook(
  Book(
    id: 'b-1',
    title: 'Flutter in Action',
    author: 'Eric Windmill',
    filePath: '/books/flutter.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
    readingProgress: 0.42,
    lastOpenedAt: DateTime(2026, 2, 1),
  ),
);

final _card = find.byType(LibraryContinueReadingCard);
final _caption = find.byKey(const ValueKey('libraryContinueReadingCaption'));

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    LibrarySource source, {
    VoidCallback? onPressed,
    VoidCallback? onLongPressed,
    bool isSelectionMode = false,
    bool isSelected = false,
    ThemeData? theme,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 390,
                child: LibraryContinueReadingCard(
                  source: source,
                  isSelectionMode: isSelectionMode,
                  isSelected: isSelected,
                  onPressed: onPressed ?? () {},
                  onLongPressed: onLongPressed ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('LibraryContinueReadingCard', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('a full-width band with the row cover on the 16dp gutter: '
          '${theme.brightness}', (tester) async {
        await pumpCard(tester, _article, theme: theme);
        final material = tester.widget<Material>(
          find.byKey(const ValueKey('libraryContinueReadingCard')),
        );
        expect(material.color, theme.colorScheme.surfaceContainerLow);
        expect(material.borderRadius, isNull);
        final ink = tester.widget<InkWell>(
          find.descendant(of: _card, matching: find.byType(InkWell)),
        );
        expect(ink.borderRadius, isNull);

        final card = tester.getRect(_card);
        final cover = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingCover')),
        );
        expect(card.width, 390);
        expect(
          cover.size,
          const Size(kLibraryListCoverWidth, kLibraryListCoverHeight),
        );
        expect(cover.left - card.left, AppSpacing.lg);
        expect(cover.center.dy, closeTo(card.center.dy, .01));
        expect(cover.top - card.top, greaterThanOrEqualTo(AppSpacing.md));
        expect(
          find.descendant(
            of: _card,
            matching: find.byType(LibraryListCoverSlot),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _card,
            matching: find.byType(AppSourceCoverFrame),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('text roles: overline, serif title, muted author', (
      tester,
    ) async {
      await pumpCard(tester, _article);
      final strings = tester.element(_card).l10n;
      final theme = Theme.of(tester.element(_card));
      final overline = tester.widget<Text>(
        find.text(strings.libraryContinueReading),
      );
      expect(overline.style!.fontSize, theme.textTheme.labelSmall!.fontSize);
      expect(overline.style!.color, theme.colorScheme.onSurfaceVariant);

      final title = tester.widget<Text>(find.text('The Long Read'));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.style!.fontSize, theme.textTheme.titleMedium!.fontSize);
      expect(title.style!.fontFamily, AppTypography.fontFamilySerif);

      final author = tester.widget<Text>(find.text('Ada Writer'));
      expect(author.maxLines, 1);
      expect(author.style!.fontSize, theme.textTheme.bodySmall!.fontSize);
      expect(author.style!.color, theme.colorScheme.onSurfaceVariant);

      final cover = tester.getRect(
        find.byKey(const ValueKey('libraryContinueReadingCover')),
      );
      final overlineRect = tester.getRect(
        find.text(strings.libraryContinueReading),
      );
      expect(overlineRect.left - cover.right, kLibraryListCoverToTextGap);
      expect(
        tester.getRect(find.text('The Long Read')).top,
        greaterThan(overlineRect.bottom),
      );
    });

    testWidgets('omits the author line without an author', (tester) async {
      final anonymous = LibrarySource.fromBook(
        Book(
          id: 'b-2',
          title: 'Anonymous',
          filePath: '/b2.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          readingProgress: 0.5,
          lastOpenedAt: DateTime(2026, 2, 1),
        ),
      );
      await pumpCard(tester, anonymous);
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: _card, matching: find.byType(Text)),
          )
          .map((text) => text.data)
          .toList();
      expect(texts, ['Continue reading', 'Anonymous', '50%']);
    });

    testWidgets('caption shows percent and time left', (tester) async {
      await pumpCard(tester, _article);
      expect(tester.widget<Text>(_caption).data, '42% · 6 min left');
      final theme = Theme.of(tester.element(_caption));
      expect(
        tester.widget<Text>(_caption).style!.fontSize,
        theme.textTheme.bodySmall!.fontSize,
      );
    });

    testWidgets('caption shows hours past sixty minutes', (tester) async {
      final long = LibrarySource.fromArticle(
        Article(
          id: 'a-2',
          title: 'Very Long',
          url: 'https://example.com/very-long',
          contentPath: '/a2.json',
          addedAt: DateTime(2026),
          // 90 minutes left.
          textLength: 1200 * 180,
          readingProgress: 0.5,
          lastOpenedAt: DateTime(2026, 2, 1),
        ),
      );
      await pumpCard(tester, long);
      expect(tester.widget<Text>(_caption).data, '50% · 1 h 30 min left');
    });

    testWidgets('caption omits the time when the length is unknown', (
      tester,
    ) async {
      await pumpCard(tester, _book);
      expect(tester.widget<Text>(_caption).data, '42%');
      expect(find.textContaining('min left'), findsNothing);
    });

    for (final direction in TextDirection.values) {
      testWidgets('4dp progress bar fills from the start: $direction', (
        tester,
      ) async {
        await pumpCard(tester, _article, direction: direction);
        final track = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingProgress')),
        );
        final fill = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingProgressFill')),
        );
        expect(track.height, 4);
        expect(fill.height, 4);
        expect(fill.width, closeTo(track.width * .42, .5));
        if (direction == TextDirection.ltr) {
          expect(fill.left, track.left);
        } else {
          expect(fill.right, track.right);
        }
        final context = tester.element(
          find.byKey(const ValueKey('libraryContinueReadingProgressFill')),
        );
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(
                  const ValueKey('libraryContinueReadingProgressFill'),
                ),
              )
              .color,
          context.actionForeground,
        );
        expect(
          tester
              .widget<ColoredBox>(
                find
                    .descendant(
                      of: find.byKey(
                        const ValueKey('libraryContinueReadingProgress'),
                      ),
                      matching: find.byType(ColoredBox),
                    )
                    .first,
              )
              .color,
          context.colors.surfaceContainerHighest,
        );
      });
    }

    testWidgets('is one button: title label, progress and time value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpCard(tester, _article);
        final strings = tester.element(_card).l10n;
        expect(
          tester.getSemantics(_card),
          matchesSemantics(
            label: 'The Long Read',
            value: '42 percent read, 6 min left',
            isButton: true,
            hasTapAction: true,
            hasLongPressAction: true,
            onTapHint: strings.librarySourceOpenReader,
            onLongPressHint: strings.librarySourceSelect,
          ),
        );

        await pumpCard(tester, _book);
        expect(
          tester.getSemantics(_card).getSemanticsData().value,
          '42 percent read',
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('tap opens the source; long-press selects without opening', (
      tester,
    ) async {
      var pressed = 0;
      var longPressed = 0;
      await pumpCard(
        tester,
        _article,
        onPressed: () => pressed++,
        onLongPressed: () => longPressed++,
      );
      await tester.longPress(_card);
      await tester.pumpAndSettle();
      expect(longPressed, 1);
      expect(pressed, 0, reason: 'releasing a long-press does not open');
      await tester.tap(_card);
      expect(pressed, 1);
      expect(longPressed, 1);
    });

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('selects like a row: ${theme.brightness}', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final colors = theme.colorScheme;
          Color? textColor(String text) =>
              tester.widget<Text>(find.text(text)).style!.color;
          final check = find.descendant(
            of: _card,
            matching: find.byKey(const ValueKey('libraryListSelectionCheck')),
          );

          await pumpCard(tester, _article, theme: theme, isSelectionMode: true);
          final strings = tester.element(_card).l10n;
          expect(
            tester
                .widget<Material>(
                  find.byKey(const ValueKey('libraryContinueReadingCard')),
                )
                .color,
            colors.surfaceContainerLow,
          );
          expect(check, findsNothing);
          expect(textColor('The Long Read'), colors.onSurface);
          expect(
            tester.getSemantics(_card),
            matchesSemantics(
              label: 'The Long Read',
              value: '42 percent read, 6 min left',
              isButton: true,
              hasSelectedState: true,
              hasTapAction: true,
              hasLongPressAction: true,
              onTapHint: strings.librarySourceSelect,
            ),
          );

          await pumpCard(
            tester,
            _article,
            theme: theme,
            isSelectionMode: true,
            isSelected: true,
          );
          expect(
            tester
                .widget<Material>(
                  find.byKey(const ValueKey('libraryContinueReadingCard')),
                )
                .color,
            colors.selectedControlBackground,
          );
          expect(check, findsOneWidget);
          final fill = tester.widget<ColoredBox>(
            find.byKey(const ValueKey('libraryContinueReadingProgressFill')),
          );
          expect(fill.color, colors.selectedControlForeground);
          // Light mode's selected fill is translucent over the page.
          final band = Color.alphaBlend(
            colors.selectedControlBackground,
            theme.scaffoldBackgroundColor,
          );
          expect(
            _contrast(fill.color, band),
            greaterThanOrEqualTo(3),
            reason: 'the fill stays visible on the selected band',
          );
          for (final text in [
            'The Long Read',
            'Ada Writer',
            strings.libraryContinueReading,
          ]) {
            expect(
              textColor(text),
              colors.selectedControlForeground,
              reason: text,
            );
          }
          expect(
            tester.getSemantics(_card),
            matchesSemantics(
              label: 'The Long Read',
              value: '42 percent read, 6 min left',
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              hasTapAction: true,
              hasLongPressAction: true,
              onTapHint: strings.librarySourceDeselect,
            ),
          );
        } finally {
          semantics.dispose();
        }
      });
    }
  });

  group('placement', () {
    final rows = [
      for (final id in ['r-1', 'r-2'])
        LibrarySource.fromBook(
          Book(
            id: id,
            title: 'Row $id',
            filePath: '/$id.epub',
            format: BookFormat.epub,
            addedAt: DateTime(2026),
          ),
        ),
    ];

    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      supportedLocales: ReadflexSupportedLocales.locales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 390, height: 700, child: child),
        ),
      ),
    );

    testWidgets('list: first item on the gutter, 16dp above the first cover', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      LibrarySource? opened;
      await tester.pumpWidget(
        host(
          LibraryListView(
            sources: rows,
            continueReadingSource: _article,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (source) => opened = source,
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      );
      final card = tester.getRect(_card);
      expect(card.left, 0);
      expect(card.right, 390);
      expect(card.top, kLibraryContentTopPadding);
      final firstCover = tester.getRect(
        find.byKey(const ValueKey('libraryListCoverSlot')).first,
      );
      expect(firstCover.top - card.bottom, kLibraryContinueReadingGap);
      // The card's cover and title sit on the rows' cover and title lines.
      final cardCover = tester.getRect(
        find.byKey(const ValueKey('libraryContinueReadingCover')),
      );
      expect(cardCover.left, firstCover.left);
      expect(cardCover.size, firstCover.size);
      expect(
        tester.getRect(find.text('The Long Read')).left,
        tester.getRect(find.text('Row r-1')).left,
      );
      // The first source row still has no top hairline.
      expect(
        find.byKey(const ValueKey('libraryListRowTopDivider')),
        findsOneWidget,
      );
      await tester.tap(_card);
      expect(opened, _article);

      // It scrolls with the rows.
      controller.jumpTo(40);
      await tester.pump();
      expect(tester.getRect(_card).top, kLibraryContentTopPadding - 40);
    });

    testWidgets('list without a card starts with the first row', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          LibraryListView(
            sources: rows,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      );
      expect(_card, findsNothing);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('libraryListCoverSlot')).first)
            .top,
        kLibraryContentTopPadding,
      );
    });

    for (final direction in TextDirection.values) {
      testWidgets('grid: full-width first item, 16dp above the covers: '
          '$direction', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        LibrarySource? opened;
        await tester.pumpWidget(
          host(
            Directionality(
              textDirection: direction,
              child: LibraryGridView(
                sources: rows,
                continueReadingSource: _article,
                selection: const LibrarySelectionState(),
                scrollController: controller,
                onSourcePressed: (source) => opened = source,
                onSourceLongPressed: (_) {},
              ),
            ),
          ),
        );
        final card = tester.getRect(_card);
        expect(card.left, 0);
        expect(card.right, 390);
        expect(card.top, kLibraryContentTopPadding);
        final cardCover = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingCover')),
        );
        final covers = find.descendant(
          of: find.byType(SliverGrid),
          matching: find.byType(AppSourceCoverFrame),
        );
        final firstCover = tester.getRect(covers.first);
        expect(firstCover.top - card.bottom, kLibraryContinueReadingGap);
        if (direction == TextDirection.ltr) {
          expect(firstCover.left, AppSpacing.lg);
          expect(cardCover.left, firstCover.left);
        } else {
          expect(firstCover.right, 390 - AppSpacing.lg);
          expect(cardCover.right, firstCover.right);
        }
        await tester.tap(_card);
        expect(opened, _article);
        controller.jumpTo(40);
        await tester.pump();
        expect(tester.getRect(_card).top, kLibraryContentTopPadding - 40);
      });
    }
  });
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance() + .05;
  final second = b.computeLuminance() + .05;
  return first > second ? first / second : second / first;
}
