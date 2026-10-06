import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    bool visible = true,
    bool rtl = false,
    bool disableAnimations = false,
    double scale = 1,
    BookFormat format = BookFormat.epub,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
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
      await pump(tester, rtl: rtl);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).tabAlignment,
        TabAlignment.fill,
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      expect(
        rtl ? row.right - text.right : text.left - row.left,
        AppSpacing.lg + AppSpacing.md,
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

    testWidgets('hidden drawer slides toward the leading edge rtl=$rtl', (
      tester,
    ) async {
      await load(tester);
      await pump(tester, visible: false, rtl: rtl);
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, Offset(rtl ? 1 : -1, 0));
      expect(slide.duration, AppMotion.short);
    });
  }

  testWidgets('drawer settles in one frame under reduced motion', (
    tester,
  ) async {
    await load(tester);
    await pump(tester, visible: false, disableAnimations: true);
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
    await pump(tester, visible: true, disableAnimations: true);
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    expect(
      tester
          .getRect(
            find
                .descendant(
                  of: find.byType(ReaderTocDrawerDriver),
                  matching: find.byType(Material),
                )
                .first,
          )
          .left,
      0,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}
