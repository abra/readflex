import 'dart:ui' show FontFeature, Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_highlight_quote_background.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader_webview/reader_webview.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  final book = Book(
    id: 'book',
    title: 'Book',
    filePath: '/book.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  );
  final highlight = Highlight(
    id: 'h1',
    sourceId: book.id,
    sourceType: SourceType.book,
    text: 'A saved passage',
    cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
    color: HighlightColor.green,
    createdAt: DateTime(2026),
  );
  const toc = [
    ReaderTocItem(label: 'Part one', href: 'part1.xhtml', level: 1),
    ReaderTocItem(label: 'Chapter one', href: 'ch1.xhtml', level: 2),
  ];
  late ReaderBloc bloc;

  Future<void> load(WidgetTester tester, {bool withHighlight = false}) async {
    final highlights = FakeHighlightRepository();
    if (withHighlight) highlights.seedHighlights(book.id, [highlight]);
    bloc = ReaderBloc(
      bookRepository: FakeBookRepository()..seedBook(book),
      highlightRepository: highlights,
      initialSource: book,
    );
    addTearDown(bloc.close);
    bloc.add(ReaderSourceLoadRequested(sourceId: book.id));
    await bloc.stream
        .firstWhere((s) => s.status == ReaderStatus.ready)
        .timeout(const Duration(seconds: 3), onTimeout: () => bloc.state);
  }

  /// Pumps the Contents sheet on a phone-sized surface by default.
  Future<void> pump(
    WidgetTester tester, {
    bool visible = true,
    bool rtl = false,
    bool disableAnimations = false,
    double scale = 1,
    bool dark = false,
    BookFormat format = BookFormat.epub,
    Size size = _phone,
    VoidCallback? onClose,
    ValueChanged<ReaderTocItem>? onItemSelected,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: Stack(
              children: [
                ReaderTocDrawerDriver(
                  loadThumbnail: (_) async => null,
                  visible: visible,
                  format: format,
                  pageProgressionRtl: false,
                  readerTheme: ReaderThemePreset.paper.data,
                  onClose: onClose ?? () {},
                  onItemSelected: onItemSelected ?? (_) {},
                  onBookmarkSelected: (_) {},
                  onHighlightSelected: (_) {},
                  onBookmarkDeleted: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('every tab shows the shared compact EmptyState', (tester) async {
    await load(tester);
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final empty = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(empty.compact, isTrue);
    expect(empty.icon, AppIcons.toc);

    await openTab(tester, l10n.readerBookmarks);
    expect(
      tester.widget<EmptyState>(find.byType(EmptyState)).message,
      l10n.readerNoBookmarksYet,
    );

    await openTab(tester, l10n.readerHighlights);
    expect(
      tester.widget<EmptyState>(find.byType(EmptyState)).message,
      l10n.readerNoHighlightsYet,
    );
    expect(find.byType(AppFilterChip), findsNothing);
  });

  testWidgets('highlight "All" filter is a selected filter chip', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await load(tester, withHighlight: true);
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await openTab(tester, l10n.readerHighlights);
    final chip = find.byType(AppFilterChip);
    expect(chip, findsOneWidget);
    expect(find.text(l10n.readerHighlightFilterAll), findsOneWidget);
    expect(tester.widget<AppFilterChip>(chip).selected, isTrue);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(l10n.readerHighlightFilterAll))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.getSize(chip).height, AppSizes.chipTapTarget);

    await tester.tap(find.byTooltip(l10n.highlightColorYellow));
    await tester.pumpAndSettle();
    expect(tester.widget<AppFilterChip>(chip).selected, isFalse);
    expect(find.byType(EmptyState), findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<AppFilterChip>(chip).selected, isTrue);
    expect(find.text('A saved passage'), findsOneWidget);
    semantics.dispose();
  });

  for (final rtl in [false, true]) {
    testWidgets(
      'highlight filters start on the search gutter with 32dp swatches '
      'rtl=$rtl',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await load(tester, withHighlight: true);
        await pump(tester, rtl: rtl);
        final l10n = tester.element(find.byType(Scaffold)).l10n;
        await openTab(tester, l10n.readerHighlights);
        final width = tester.getSize(find.byType(Scaffold)).width;
        final field = tester.getRect(find.byType(SearchField));
        final chip = tester.getRect(find.byType(AppFilterChip));
        expect(rtl ? width - chip.right : chip.left, AppSpacing.lg);
        expect(rtl ? chip.right : chip.left, rtl ? field.right : field.left);
        // 8dp above and below the 48dp targets, after the field's own 16.
        expect(chip.height, AppSizes.chipTapTarget);
        expect(chip.top - field.bottom, AppSpacing.lg + AppSpacing.sm);
        final list = tester.getRect(
          find.ancestor(
            of: find.byType(ReaderHighlightListTile),
            matching: find.byType(ListView),
          ),
        );
        expect(list.top - chip.bottom, AppSpacing.sm);
        final yellow = find.byTooltip(l10n.highlightColorYellow);
        expect(
          tester.getSize(yellow),
          const Size.square(AppSizes.buttonHeight),
        );
        expect(
          tester.getSize(
            find.descendant(
              of: yellow,
              matching: find.byType(AnimatedContainer),
            ),
          ),
          const Size.square(AppSizes.chipHeight),
        );
        expect(
          tester.getRect(yellow).center.dy,
          moreOrLessEquals(chip.center.dy, epsilon: 0.5),
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      },
    );

    testWidgets('scrollable tabs start on the 16dp gutter rtl=$rtl', (
      tester,
    ) async {
      await load(tester);
      // Wide surface: the three tabs share the width.
      await pump(tester, rtl: rtl, size: const Size(800, 600));
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).tabAlignment,
        TabAlignment.fill,
      );
      await pump(tester, rtl: rtl, scale: 2);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.isScrollable, isTrue);
      expect(tabBar.tabAlignment, TabAlignment.start);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      final icon = tester.getRect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.byIcon(AppIcons.toc),
        ),
      );
      final title = tester.getRect(find.text(l10n.readerContents));
      expect(rtl ? 390 - icon.right : icon.left, AppSpacing.lg);
      expect(rtl ? 390 - title.right : title.left, AppSpacing.lg);
    });

    testWidgets('comic pages grid starts on the drawer gutter rtl=$rtl', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await load(tester);
      bloc.add(
        ReaderTocUpdated(
          items: List.generate(
            4,
            (i) => ReaderTocItem(label: 'page-$i.jpg', href: '$i', level: 0),
          ),
        ),
      );
      await pump(tester, rtl: rtl, format: BookFormat.cbz);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      final title = tester.getRect(find.text(l10n.readerContents));
      // The grid follows page progression (LTR here), so page 1 is the
      // leftmost tile in both app directions.
      final first = tester.getRect(
        find
            .ancestor(
              of: find.text(l10n.readerPageNumber(1)),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(first.left, AppSpacing.lg);
      expect(rtl ? 390 - title.right : title.left, AppSpacing.lg);
      final tabs = tester.getRect(find.byType(TabBar));
      expect(first.top - tabs.bottom, AppSpacing.lg);
    });

    testWidgets('chapter rows indent from the app leading edge rtl=$rtl', (
      tester,
    ) async {
      await load(tester);
      bloc.add(const ReaderTocUpdated(items: toc));
      await pump(tester, rtl: rtl);
      final nested = find.widgetWithText(ListTile, 'Chapter one');
      final row = tester.getRect(nested);
      final text = tester.getRect(find.text('Chapter one'));
      final tile = tester.widget<ListTile>(nested);
      // Full-bleed active row: the themed 16dp tile radius must not apply.
      expect(tile.shape, const RoundedRectangleBorder());
      expect(
        tile.contentPadding,
        const EdgeInsetsDirectional.only(
          start: AppSpacing.lg + AppSpacing.md,
          end: AppSpacing.lg,
          top: AppSpacing.xxs,
          bottom: AppSpacing.xxs,
        ),
      );
      // Indent, then the constant 16dp mark slot and its 8dp gap.
      expect(
        rtl ? row.right - text.right : text.left - row.left,
        AppSpacing.lg + AppSpacing.md + AppIconSize.xs + AppSpacing.sm,
      );
      // The chapter title keeps the book direction regardless of locale.
      expect(
        tester.widget<Text>(find.text('Chapter one')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('close glyph sits on the 16dp gutter rtl=$rtl', (tester) async {
      await load(tester);
      await pump(tester, rtl: rtl);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      final close = find.byTooltip(l10n.commonClose);
      final icon = find.byIcon(AppIcons.close);
      final width = tester.getSize(find.byType(Scaffold)).width;
      expect(tester.getSize(close), const Size.square(AppSizes.buttonHeight));
      expect(tester.getSize(icon), const Size.square(AppIconSize.sm));
      final iconRect = tester.getRect(icon);
      expect(rtl ? iconRect.left : width - iconRect.right, AppSpacing.lg);
      final field = tester.getRect(find.byType(SearchField));
      expect(
        rtl ? iconRect.left : iconRect.right,
        rtl ? field.left : field.right,
      );
    });

    testWidgets('opens as a sheet at 60% of the height rtl=$rtl', (
      tester,
    ) async {
      await load(tester);
      await pump(tester, rtl: rtl);
      final sheet = tester.getRect(_sheetSurface);
      final geometry = AppInlineSheetGeometry.resolve(
        maxHeight: _phone.height,
        keyboardInset: 0,
        topInset: 0,
      );
      expect(sheet.top, moreOrLessEquals(_phone.height - geometry.half));
      expect(sheet.left, 0);
      expect(sheet.right, _phone.width);
      // The header, tabs and search field sit in the middle of the screen.
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(
        tester.getRect(find.text(l10n.readerContents)).top,
        greaterThan(_phone.height / 3),
      );
    });

    testWidgets('a hidden sheet stays mounted offstage rtl=$rtl', (
      tester,
    ) async {
      await load(tester);
      await pump(tester, visible: false, rtl: rtl);
      final offstage = tester.widget<Offstage>(
        find
            .descendant(
              of: find.byType(AppInlineSheet),
              matching: find.byType(Offstage),
            )
            .first,
      );
      expect(offstage.offstage, isTrue);
      // Mounted, so tab and search state survive; finders skip offstage.
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBar, skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('every tab fits a landscape phone at 200% text', (tester) async {
    await load(tester);
    await pump(tester, size: const Size(844, 390), scale: 2);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    expect(tester.takeException(), isNull);
    for (final tab in [l10n.readerBookmarks, l10n.readerHighlights]) {
      await tester.ensureVisible(find.text(tab));
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
      expect(find.byType(EmptyState), findsOneWidget, reason: tab);
    }
  });

  testWidgets('large text opens the sheet at full height', (tester) async {
    await load(tester);
    await pump(tester, scale: 1.5);
    expect(
      tester.getRect(_sheetSurface).top,
      moreOrLessEquals(AppInlineSheetGeometry.topGap),
    );
  });

  testWidgets('dragging the header up opens the whole list', (tester) async {
    await load(tester);
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;

    await tester.drag(find.text(l10n.readerContents), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(_sheetSurface).top,
      moreOrLessEquals(AppInlineSheetGeometry.topGap),
    );
  });

  testWidgets('a fling down on the header asks to close', (tester) async {
    var closes = 0;
    await load(tester);
    await pump(tester, onClose: () => closes++);
    final l10n = tester.element(find.byType(Scaffold)).l10n;

    await tester.fling(
      find.text(l10n.readerContents),
      const Offset(0, 200),
      1500,
    );
    await tester.pumpAndSettle();

    expect(closes, 1);
  });

  group('chapter progress', () {
    const chapters = [
      ReaderTocItem(
        label: 'Part one',
        href: 'p1',
        level: 1,
        startPage: 0,
        startPercentage: 0,
      ),
      ReaderTocItem(
        label: 'Chapter one',
        href: 'c1',
        level: 2,
        startPage: 12,
        startPercentage: .1,
      ),
      ReaderTocItem(
        label: 'Chapter two',
        href: 'c2',
        level: 2,
        startPercentage: .456,
      ),
      ReaderTocItem(label: 'Part two', href: 'p2', level: 1),
      ReaderTocItem(
        label: 'Chapter three',
        href: 'c3',
        level: 2,
        startPage: 80,
        startPercentage: .8,
      ),
    ];

    Future<void> loadChapters(WidgetTester tester) async {
      await load(tester);
      bloc
        ..add(const ReaderTocUpdated(items: chapters))
        ..add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/6)',
            progress: .5,
            chapterTitle: 'Chapter two',
          ),
        );
      await bloc.stream
          .firstWhere((s) => s.chapterTitle == 'Chapter two')
          .timeout(const Duration(seconds: 3));
      // Let the debounced position save run before the drawer mounts.
      await tester.pump(const Duration(seconds: 1));
    }

    Finder row(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(ListTile));

    Finder inRow(String title, Finder matching) =>
        find.descendant(of: row(title), matching: matching);

    final dot = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    );

    Text label(WidgetTester tester, String title, String text) =>
        tester.widget<Text>(inRow(title, find.text(text)));

    testWidgets('rows show their start page, else a whole percent, else none', (
      tester,
    ) async {
      await loadChapters(tester);
      await pump(tester);
      final context = tester.element(find.byType(Scaffold));
      // Page 0 of the opening chapter reads as page 1.
      expect(inRow('Part one', find.text('1')), findsOneWidget);
      expect(inRow('Chapter one', find.text('12')), findsOneWidget);
      expect(inRow('Chapter one', find.text('10%')), findsNothing);
      expect(inRow('Chapter two', find.text('46%')), findsOneWidget);
      expect(
        tester.widgetList<Text>(inRow('Part two', find.byType(Text))).length,
        1,
        reason: 'only the title, no position label',
      );
      expect(inRow('Chapter three', find.text('80')), findsOneWidget);
      final page = label(tester, 'Chapter one', '12');
      expect(page.style?.fontSize, context.text.bodySmall.fontSize);
      expect(page.style?.color, context.colors.onSurfaceVariant);
      expect(page.style?.fontFeatures, const [FontFeature.tabularFigures()]);
      expect(page.semanticsLabel, context.l10n.readerPageNumber(12));
      expect(label(tester, 'Chapter two', '46%').semanticsLabel, isNull);
    });

    testWidgets('read rows are muted with a check, the active row has a dot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await loadChapters(tester);
      await pump(tester);
      final context = tester.element(find.byType(Scaffold));
      final colors = context.colors;
      final l10n = context.l10n;
      Color? titleColor(String title) =>
          tester.widget<Text>(find.text(title)).style?.color;

      // Read: before the active chapter, outside its parent part.
      expect(inRow('Chapter one', find.byIcon(AppIcons.check)), findsOneWidget);
      expect(
        tester.getSize(inRow('Chapter one', find.byIcon(AppIcons.check))),
        const Size.square(AppIconSize.xs),
      );
      expect(
        tester
            .widget<Icon>(inRow('Chapter one', find.byIcon(AppIcons.check)))
            .color,
        colors.onSurfaceVariant,
      );
      expect(titleColor('Chapter one'), colors.onSurfaceVariant);
      final readData = tester
          .getSemantics(row('Chapter one'))
          .getSemanticsData();
      expect(readData.value, l10n.readerChapterRead);
      // The bare page number is announced as a page.
      expect(readData.label, 'Chapter one\n${l10n.readerPageNumber(12)}');

      // The part containing the active chapter is not finished.
      expect(inRow('Part one', find.byIcon(AppIcons.check)), findsNothing);
      expect(titleColor('Part one'), colors.onSurface);

      // Active: selected fill, accent title and a dot instead of a check.
      final active = tester.widget<ListTile>(row('Chapter two'));
      expect(active.selected, isTrue);
      expect(active.selectedTileColor, colors.selectedControlBackground);
      expect(titleColor('Chapter two'), colors.selectedControlForeground);
      expect(inRow('Chapter two', dot), findsOneWidget);
      expect(inRow('Chapter two', find.byIcon(AppIcons.check)), findsNothing);
      expect(
        (tester.widget<DecoratedBox>(inRow('Chapter two', dot)).decoration
                as BoxDecoration)
            .color,
        colors.selectedControlForeground,
      );
      expect(
        label(tester, 'Chapter two', '46%').style?.color,
        colors.selectedControlForeground,
      );
      final activeData = tester
          .getSemantics(row('Chapter two'))
          .getSemanticsData();
      expect(activeData.flagsCollection.isSelected, Tristate.isTrue);
      expect(activeData.value, isEmpty);

      // Later chapters are plain.
      for (final title in ['Part two', 'Chapter three']) {
        expect(inRow(title, find.byIcon(AppIcons.check)), findsNothing);
        expect(inRow(title, dot), findsNothing);
        expect(titleColor(title), colors.onSurface);
        expect(
          tester.getSemantics(row(title)).getSemanticsData().value,
          isEmpty,
        );
      }
      expect(dot, findsOneWidget);
      semantics.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets('the active row keeps its label readable dark=$dark', (
        tester,
      ) async {
        await loadChapters(tester);
        await pump(tester, dark: dark);
        final colors = tester.element(find.byType(Scaffold)).colors;
        final fill = Color.alphaBlend(
          colors.selectedControlBackground,
          colors.surface,
        );
        for (final text in ['Chapter two', '46%']) {
          expect(
            readerContrastRatio(
              tester.widget<Text>(find.text(text)).style!.color!,
              fill,
            ),
            greaterThanOrEqualTo(4.5),
            reason: text,
          );
        }
      });
    }

    for (final rtl in [false, true]) {
      testWidgets(
        '390dp rows align titles past a constant mark slot rtl=$rtl',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await loadChapters(tester);
          await pump(tester, rtl: rtl);
          double start(Rect rect) => rtl ? 390 - rect.right : rect.left;
          double end(Rect rect) => rtl ? rect.left : 390 - rect.right;
          const slot = AppIconSize.xs + AppSpacing.sm;
          const nested = AppSpacing.lg + AppSpacing.md;
          // Same level, with a check, a dot or nothing: one title edge.
          final levelTwo = [
            for (final title in ['Chapter one', 'Chapter two', 'Chapter three'])
              start(tester.getRect(find.text(title))),
          ];
          expect(levelTwo, everyElement(nested + slot));
          for (final title in ['Part one', 'Part two']) {
            expect(
              start(tester.getRect(find.text(title))),
              AppSpacing.lg + slot,
            );
          }
          // Marks start on their row's indent and centre on the first line.
          final check = tester.getRect(
            inRow('Chapter one', find.byIcon(AppIcons.check)),
          );
          final checkTitle = tester.getRect(find.text('Chapter one'));
          expect(start(check), nested);
          final context = tester.element(find.byType(Scaffold));
          final lineHeight =
              context.text.bodyMedium.fontSize! *
              context.text.bodyMedium.height!;
          expect(
            check.center.dy,
            moreOrLessEquals(checkTitle.top + lineHeight / 2, epsilon: 0.5),
          );
          final activeDot = tester.getRect(inRow('Chapter two', dot));
          expect(activeDot.size, const Size.square(AppSpacing.sm));
          expect(
            start(activeDot),
            nested + (AppIconSize.xs - AppSpacing.sm) / 2,
          );
          // Position labels end on the 16dp gutter and share a baseline
          // with the title's first line.
          for (final (title, text) in [
            ('Part one', '1'),
            ('Chapter one', '12'),
            ('Chapter two', '46%'),
            ('Chapter three', '80'),
          ]) {
            final position = tester.getRect(inRow(title, find.text(text)));
            expect(end(position), AppSpacing.lg, reason: title);
            final titleRect = tester.getRect(find.text(title));
            expect(
              rtl
                  ? titleRect.left - position.right
                  : position.left - titleRect.right,
              greaterThanOrEqualTo(AppSpacing.md),
            );
            expect(position.bottom, lessThanOrEqualTo(titleRect.bottom));
          }
          // The active fill still runs edge to edge.
          final activeRow = tester.getRect(row('Chapter two'));
          expect(activeRow.left, 0);
          expect(activeRow.right, 390);
        },
      );

      testWidgets(
        'large text keeps long titles and labels in bounds rtl=$rtl',
        (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await load(tester);
          bloc.add(
            ReaderTocUpdated(
              items: [
                const ReaderTocItem(
                  label:
                      'An opening chapter title long enough to need two lines',
                  href: 'a',
                  level: 1,
                  startPage: 1,
                ),
                const ReaderTocItem(
                  label:
                      'A nested chapter with an equally long and winding name',
                  href: 'b',
                  level: 3,
                  startPage: 1234,
                ),
              ],
            ),
          );
          await pump(tester, rtl: rtl, scale: 2);
          expect(tester.takeException(), isNull);
          final position = tester.getRect(find.text('1234'));
          expect(rtl ? position.left : 390 - position.right, AppSpacing.lg);
          final title = tester.widget<Text>(
            find.textContaining('A nested chapter'),
          );
          expect(title.maxLines, 2);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        },
      );
    }

    testWidgets('tapping a row still navigates to its chapter', (tester) async {
      final selected = <ReaderTocItem>[];
      await loadChapters(tester);
      await pump(tester, onItemSelected: selected.add);
      await tester.tap(find.text('Chapter one'));
      await tester.tap(find.text('80'));
      expect(selected.map((item) => item.href), ['c1', 'c3']);
    });

    testWidgets('filtered rows keep the state of their source position', (
      tester,
    ) async {
      await loadChapters(tester);
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'chapter');
      await tester.pumpAndSettle();
      expect(find.text('Part one'), findsNothing);
      expect(inRow('Chapter one', find.byIcon(AppIcons.check)), findsOneWidget);
      expect(inRow('Chapter two', dot), findsOneWidget);
      expect(inRow('Chapter three', find.text('80')), findsOneWidget);
      expect(find.byIcon(AppIcons.check), findsOneWidget);
    });

    testWidgets('opening scrolls a far active chapter into view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await load(tester);
      bloc
        ..add(
          ReaderTocUpdated(
            items: [
              for (var i = 0; i < 60; i++)
                ReaderTocItem(
                  label: 'Chapter $i',
                  href: '$i',
                  level: 1,
                  startPage: i * 10,
                ),
            ],
          ),
        )
        ..add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/90)',
            progress: .75,
            chapterTitle: 'Chapter 45',
          ),
        );
      await bloc.stream
          .firstWhere((s) => s.chapterTitle == 'Chapter 45')
          .timeout(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await pump(tester);
      expect(find.text('Chapter 45').hitTestable(), findsOneWidget);
      expect(inRow('Chapter 44', find.byIcon(AppIcons.check)), findsOneWidget);
      expect(inRow('Chapter 45', dot), findsOneWidget);
    });
  });

  testWidgets('the sheet settles in one frame under reduced motion', (
    tester,
  ) async {
    await load(tester);
    await pump(tester, visible: false, disableAnimations: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: Stack(
              children: [
                ReaderTocDrawerDriver(
                  loadThumbnail: (_) async => null,
                  visible: true,
                  format: BookFormat.epub,
                  pageProgressionRtl: false,
                  readerTheme: ReaderThemePreset.paper.data,
                  onClose: () {},
                  onItemSelected: (_) {},
                  onBookmarkSelected: (_) {},
                  onHighlightSelected: (_) {},
                  onBookmarkDeleted: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final geometry = AppInlineSheetGeometry.resolve(
      maxHeight: _phone.height,
      keyboardInset: 0,
      topInset: 0,
    );
    expect(
      tester.getRect(_sheetSurface).top,
      moreOrLessEquals(_phone.height - geometry.half),
    );
    // A second frame without elapsed time: only focus bookkeeping was
    // pending, a running slide would still be animating.
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}

const _phone = Size(390, 844);

final _sheetSurface = find
    .descendant(
      of: find.byType(AppInlineSheet),
      matching: find.byType(Material),
    )
    .first;
