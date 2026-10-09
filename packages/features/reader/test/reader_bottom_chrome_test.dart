import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_chrome_colors.dart';
import 'package:reader/src/reader_chrome_progress_layout.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:toast_service/toast_service.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

const _capsuleKey = ValueKey('readerChromeCapsule');
const _startLabelKey = ValueKey('readerProgressStartLabel');
const _pageLabelKey = ValueKey('readerProgressPageLabel');

/// A book position in [chapter], page 1 of [pages], 20% through the book.
ReaderBookPositionUpdated _chapterPosition(
  String chapter, {
  double? minutesLeft,
  int pages = 16,
}) => ReaderBookPositionUpdated(
  cfi: 'epubcfi(/6/4!/4/2)',
  progress: 0.2,
  chapterTitle: chapter,
  chapterCurrentPage: 1,
  chapterTotalPages: pages,
  minutesLeft: minutesLeft,
  currentPageBookmarked: true,
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final book = Book(
    id: 'book',
    title: 'Book',
    filePath: '/book.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  );
  final comic = Book(
    id: 'comic',
    title: 'Comic',
    filePath: '/comic.cbz',
    format: BookFormat.cbz,
    addedAt: DateTime(2026),
  );
  final article = Article(
    id: 'article',
    title: 'Saved Article',
    url: 'https://example.com/article',
    siteName: 'Example',
    contentPath: '/articles/article/article.json',
    addedAt: DateTime(2026),
  );
  late PreferencesService preferences;
  late ReaderBloc bloc;
  late ReaderBloc comicBloc;
  late ReaderBloc articleBloc;
  late ReaderUiCubit uiCubit;
  late ReaderSelectionCubit selectionCubit;
  late ReaderAppearanceCubit appearanceCubit;

  // Blocs are loaded in real time; the widget bodies run under FakeAsync.
  Future<ReaderBloc> load(String sourceId) async {
    final loaded = ReaderBloc(
      bookRepository: FakeBookRepository()
        ..seedBook(book)
        ..seedBook(comic),
      articleRepository: FakeArticleRepository()..seedArticle(article),
      highlightRepository: FakeHighlightRepository(),
    );
    loaded.add(ReaderSourceLoadRequested(sourceId: sourceId));
    await loaded.stream
        .firstWhere((s) => s.status == ReaderStatus.ready)
        .timeout(const Duration(seconds: 3));
    loaded.add(
      const ReaderBookPositionUpdated(
        cfi: 'epubcfi(/6/4!/4/2)',
        progress: 0.2,
        chapterCurrentPage: 1,
        chapterTotalPages: 16,
        currentPageBookmarked: true,
        currentPageBookmarkCfi: 'epubcfi(/6/4)',
      ),
    );
    await loaded.stream
        .firstWhere((s) => s.currentPageBookmarked)
        .timeout(const Duration(seconds: 3));
    return loaded;
  }

  Future<void> update(
    WidgetTester tester,
    ReaderBloc target,
    ReaderBookPositionUpdated event,
  ) async {
    await tester.runAsync(() async {
      final updated = target.stream.firstWhere(
        (s) =>
            s.chapterTitle == event.chapterTitle &&
            s.minutesLeft == event.minutesLeft,
      );
      target.add(event);
      await updated.timeout(const Duration(seconds: 3));
    });
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    bloc = await load(book.id);
    comicBloc = await load(comic.id);
    articleBloc = await load(article.id);
    uiCubit = ReaderUiCubit()..showChrome();
    selectionCubit = ReaderSelectionCubit();
    appearanceCubit = ReaderAppearanceCubit(
      preferencesService: preferences,
      sourceId: book.id,
    );
  });

  tearDown(() async {
    await bloc.close();
    await comicBloc.close();
    await articleBloc.close();
    await uiCubit.close();
    await selectionCubit.close();
    await appearanceCubit.close();
    preferences.dispose();
  });

  Future<List<double>> pump(
    WidgetTester tester, {
    ReaderBloc? source,
    bool dark = false,
    bool rtl = false,
    bool disableAnimations = false,
    double textScale = 1,
    double bottomInset = 0,
    ReaderThemePreset theme = ReaderThemePreset.paper,
    Size size = const Size(390, 844),
    Locale locale = const Locale('en'),
    List<String>? pressed,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final seeks = <double>[];
    void record(String name) => pressed?.add(name);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: source ?? bloc),
            BlocProvider.value(value: uiCubit),
            BlocProvider.value(value: selectionCubit),
            BlocProvider.value(value: appearanceCubit),
          ],
          child: Scaffold(
            body: Stack(
              children: [
                ReaderBottomChromeDriver(
                  readerTheme: theme.data,
                  onTocPressed: () => record('toc'),
                  onFontPressed: () => record('font'),
                  onPageTurnPressed: () => record('pageTurn'),
                  onBookmarkPressed: () => record('bookmark'),
                  onSearchPressed: () => record('search'),
                  onSeekFraction: seeks.add,
                ),
                const ReaderPageBookmarkIndicatorDriver(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return seeks;
  }

  Finder capsuleButtons() => find.descendant(
    of: find.byKey(_capsuleKey),
    matching: find.byType(AppPlainIconButton),
  );

  List<String> capsuleTooltips(WidgetTester tester) => [
    for (final button in tester.widgetList<AppPlainIconButton>(
      capsuleButtons(),
    ))
      button.tooltip,
  ];

  group('capsule geometry', () {
    for (final bottomInset in [0.0, 34.0]) {
      testWidgets('60dp stadium on 16dp margins, inset=$bottomInset', (
        tester,
      ) async {
        await pump(tester, bottomInset: bottomInset);
        const width = 390.0;
        const height = 844.0;
        final rect = tester.getRect(find.byKey(_capsuleKey));
        expect(rect.height, 60);
        expect(rect.left, AppSpacing.lg);
        expect(width - rect.right, AppSpacing.lg);
        expect(height - rect.bottom, math.max(AppSpacing.lg, bottomInset));
        // The shared capsule paints the decoration.
        expect(
          tester.widget<AppFloatingCapsule>(find.byKey(_capsuleKey)).height,
          60,
        );
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(_capsuleKey),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(30));
        expect(decoration.boxShadow, AppShadows.popover);
        final context = tester.element(find.byType(Scaffold));
        expect(
          decoration.color,
          context.colors.surface.withValues(alpha: 0.92),
        );
        final border = decoration.border! as Border;
        expect(border.top.color, context.colors.outlineVariant);
        expect(border.top.width, 1 / tester.view.devicePixelRatio);
      });
    }

    for (final rtl in [false, true]) {
      testWidgets('five 48dp targets spaced evenly rtl=$rtl', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, rtl: rtl);
        final l10n = tester.element(find.byType(Scaffold)).l10n;
        expect(capsuleTooltips(tester), [
          l10n.readerBack,
          l10n.readerContents,
          l10n.readerFontAction,
          l10n.readerRemoveBookmark,
          l10n.readerSearchAction,
        ]);
        final capsule = tester.getRect(find.byKey(_capsuleKey));
        final centers = <double>[];
        for (final tooltip in capsuleTooltips(tester)) {
          final rect = tester.getRect(find.byTooltip(tooltip));
          expect(rect.width, closeTo(48, 0.01), reason: tooltip);
          expect(rect.height, closeTo(48, 0.01), reason: tooltip);
          expect(rect.center.dy, closeTo(capsule.center.dy, 0.01));
          expect(rect.left, greaterThanOrEqualTo(capsule.left));
          expect(rect.right, lessThanOrEqualTo(capsule.right));
          centers.add(rect.center.dx);
        }
        // Back leads in the reading direction of the UI.
        for (var i = 1; i < centers.length; i++) {
          final step = centers[i] - centers[i - 1];
          expect(step, closeTo((rtl ? -1 : 1) * capsule.width / 5, 0.01));
        }
        final firstSlotCenter = rtl
            ? capsule.right - capsule.width / 10
            : capsule.left + capsule.width / 10;
        expect(centers.first, closeTo(firstSlotCenter, 0.01));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('caps its width and centres on wide screens', (tester) async {
      await pump(tester, size: const Size(1024, 600));
      final rect = tester.getRect(find.byKey(_capsuleKey));
      expect(rect.width, 560 - AppSpacing.lg * 2);
      expect(rect.center.dx, closeTo(512, 0.01));
    });

    testWidgets('actions reach their callbacks', (tester) async {
      final pressed = <String>[];
      await pump(tester, pressed: pressed);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      for (final tooltip in [
        l10n.readerContents,
        l10n.readerFontAction,
        l10n.readerRemoveBookmark,
        l10n.readerSearchAction,
      ]) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump();
      }
      expect(pressed, ['toc', 'font', 'bookmark', 'search']);
    });
  });

  group('page turn', () {
    for (final (name, sourceId) in [('book', 'book'), ('article', 'article')]) {
      testWidgets('$name toolbar has no page-turn toggle', (tester) async {
        await pump(tester, source: name == 'book' ? bloc : articleBloc);
        expect(sourceId, isNotEmpty);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppPlainIconButton &&
                (widget.icon == AppIcons.pageTurnHorizontal ||
                    widget.icon == AppIcons.pageTurnVertical),
          ),
          findsNothing,
        );
        expect(capsuleButtons(), findsNWidgets(5));
      });
    }

    // Comics have no Appearance action; the toggle stays their only route to
    // the page-turn setting.
    testWidgets('comics keep their page-turn control in the capsule', (
      tester,
    ) async {
      final pressed = <String>[];
      await pump(tester, source: comicBloc, pressed: pressed);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(capsuleTooltips(tester), [
        l10n.readerBack,
        l10n.readerContents,
        l10n.readerPageTurnHorizontal,
        l10n.readerRemoveBookmark,
      ]);
      await tester.tap(find.byTooltip(l10n.readerPageTurnHorizontal));
      expect(pressed, ['pageTurn']);
    });
  });

  for (final dark in [false, true]) {
    testWidgets('capsule glyphs use the action foreground dark=$dark', (
      tester,
    ) async {
      await pump(tester, source: comicBloc, dark: dark);
      final context = tester.element(find.byType(Scaffold));
      final l10n = context.l10n;
      final pageTurn = tester.widget<AppPlainIconButton>(
        find.ancestor(
          of: find.byTooltip(l10n.readerPageTurnHorizontal),
          matching: find.byType(AppPlainIconButton),
        ),
      );
      expect(pageTurn.color, context.actionForeground);
      final bookmark = tester.widget<AppPlainIconButton>(
        find.ancestor(
          of: find.byTooltip(l10n.readerRemoveBookmark),
          matching: find.byType(AppPlainIconButton),
        ),
      );
      expect(bookmark.color, context.actionForeground);
      final back = tester.widget<AppPlainIconButton>(
        find.ancestor(
          of: find.byTooltip(l10n.readerBack),
          matching: find.byType(AppPlainIconButton),
        ),
      );
      expect(back.color, context.colors.onSurface);
    });
  }

  group('progress row', () {
    testWidgets('the slider spans the row; the labels end 8dp above the '
        'capsule', (tester) async {
      await update(tester, bloc, _chapterPosition('Chapter 2'));
      await pump(tester);
      final capsule = tester.getRect(find.byKey(_capsuleKey));
      final slider = tester.getRect(find.byType(Slider));
      final start = tester.getRect(find.byKey(_startLabelKey));
      final page = tester.getRect(find.byKey(_pageLabelKey));
      // Full width inside the 28dp inset, right above the labels.
      expect(slider.left, AppSpacing.lg + AppSpacing.md);
      expect(390 - slider.right, AppSpacing.lg + AppSpacing.md);
      expect(slider.height, AppSizes.buttonHeight);
      expect(start.top, closeTo(slider.bottom, .01));
      expect(page.top, closeTo(slider.bottom, .01));
      // The labels start and end with the track, not the slider's box.
      expect(start.left, slider.left + readerProgressTrackInset);
      expect(page.right, slider.right - readerProgressTrackInset);
      expect(start.center.dy, closeTo(page.center.dy, .5));
      expect(
        capsule.top - math.max(start.bottom, page.bottom),
        AppSpacing.sm,
      );
    });

    testWidgets('books name the current chapter, never a time', (
      tester,
    ) async {
      await update(
        tester,
        bloc,
        _chapterPosition('Chapter 2', minutesLeft: 4.2),
      );
      await pump(tester);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(
        tester.widget<Text>(find.byKey(_startLabelKey)).data,
        'Chapter 2',
      );
      expect(find.textContaining('min'), findsNothing);
      expect(
        find.text('20% · ${l10n.readerPageOfTotal(1, 16)}'),
        findsOneWidget,
      );
      final start = tester.getRect(find.byKey(_startLabelKey));
      final page = tester.getRect(find.byKey(_pageLabelKey));
      expect(
        start.right,
        lessThanOrEqualTo(page.left - readerProgressLabelGap),
      );
    });

    testWidgets('a long chapter keeps one line and truncates before the page '
        'label', (tester) async {
      await update(
        tester,
        bloc,
        _chapterPosition(
          'Chapter 12. The Long Road Home and Everything That Came After',
        ),
      );
      await pump(tester);
      final start = find.byKey(_startLabelKey);
      final page = find.byKey(_pageLabelKey);
      expect(tester.widget<Text>(start).maxLines, 1);
      expect(
        tester.renderObject<RenderParagraph>(start).didExceedMaxLines,
        isTrue,
      );
      expect(
        tester.renderObject<RenderParagraph>(page).didExceedMaxLines,
        isFalse,
      );
      expect(
        tester.getRect(start).right,
        lessThanOrEqualTo(tester.getRect(page).left - readerProgressLabelGap),
      );
      // The page label keeps its line height: one line, beside the chapter.
      expect(
        tester.getRect(page).height,
        closeTo(tester.getRect(start).height, .5),
      );
    });

    testWidgets('a book without a chapter title shows only the page label', (
      tester,
    ) async {
      await update(
        tester,
        bloc,
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.2,
          chapterCurrentPage: 1,
          chapterTotalPages: 16,
          minutesLeft: 3,
          currentPageBookmarked: true,
        ),
      );
      await pump(tester);
      expect(find.byKey(_startLabelKey), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(
        390 - tester.getRect(find.byKey(_pageLabelKey)).right,
        AppSpacing.lg + AppSpacing.md + readerProgressTrackInset,
      );
    });

    testWidgets('articles show the time left in the article', (tester) async {
      await update(
        tester,
        articleBloc,
        const ReaderBookPositionUpdated(
          cfi: 'readflex-html-position:x',
          progress: 0.4,
          chapterTitle: 'Intro',
          minutesLeft: 11.5,
        ),
      );
      await pump(tester, source: articleBloc);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(find.text(l10n.readingTimeLeftMinutes(12)), findsOneWidget);
      expect(find.text('Intro'), findsNothing);
      final start = tester.getRect(find.byKey(_startLabelKey));
      expect(
        start.top,
        closeTo(tester.getRect(find.byType(Slider)).bottom, .01),
      );
    });

    for (final minutes in [null, 0.0]) {
      testWidgets('articles fall back to the section title when '
          'minutes=$minutes', (tester) async {
        await update(
          tester,
          articleBloc,
          ReaderBookPositionUpdated(
            cfi: 'readflex-html-position:y',
            progress: 0.4,
            chapterTitle: 'Methods',
            minutesLeft: minutes,
          ),
        );
        await pump(tester, source: articleBloc);
        expect(find.text('Methods'), findsOneWidget);
        expect(find.textContaining('min'), findsNothing);
      });
    }

    testWidgets('comics show neither time nor the file name', (tester) async {
      await update(
        tester,
        comicBloc,
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/8)',
          progress: 0.2,
          chapterTitle: 'IMG_0004.jpg',
          chapterCurrentPage: 3,
          chapterTotalPages: 16,
          minutesLeft: 3,
          currentPageBookmarked: true,
        ),
      );
      await pump(tester, source: comicBloc);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(find.text('IMG_0004.jpg'), findsNothing);
      expect(find.byKey(_startLabelKey), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(find.text(l10n.readerPageOfTotal(4, 16)), findsOneWidget);
    });

    testWidgets('page label uses the localized page-of-total format', (
      tester,
    ) async {
      await pump(tester, locale: const Locale('ru'));
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(l10n.localeName, 'ru');
      expect(
        find.text('20% · ${l10n.readerPageOfTotal(1, 16)}'),
        findsOneWidget,
      );
    });

    for (final preset in ReaderThemePreset.values) {
      testWidgets('labels and slider use page ink on ${preset.id}', (
        tester,
      ) async {
        await update(
          tester,
          bloc,
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/2)',
            progress: 0.2,
            chapterTitle: 'Chapter 2',
            chapterCurrentPage: 1,
            chapterTotalPages: 16,
            minutesLeft: 2,
            currentPageBookmarked: true,
          ),
        );
        await pump(tester, theme: preset);
        final page = preset.data.backgroundColor;
        final ink = readerChromeInkColor(preset.data);
        for (final key in [_startLabelKey, _pageLabelKey]) {
          final color = tester.widget<Text>(find.byKey(key)).style!.color!;
          expect(color, ink);
          expect(_contrast(color, page), greaterThanOrEqualTo(4.5));
        }
        final slider = tester.widget<SliderTheme>(find.byType(SliderTheme));
        expect(slider.data.activeTrackColor, ink);
        expect(slider.data.thumbColor, ink);
        expect(slider.data.trackHeight, 3);
        expect(
          slider.data.inactiveTrackColor,
          readerChromeTrackColor(preset.data),
        );
        // The row reads against a page-coloured band, not the page text.
        final bands = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
        expect(bands.map((band) => band.color), contains(page));
      });
    }

    testWidgets('slider drag previews locally and seeks once on release', (
      tester,
    ) async {
      final seeks = await pump(tester);
      final slider = find.byType(Slider);
      final rect = tester.getRect(slider);
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * 0.25, rect.center.dy),
      );
      await tester.pump();
      await gesture.moveTo(
        Offset(rect.left + rect.width * 0.6, rect.center.dy),
      );
      await tester.pump();
      // Dragging shows the preview percent without the page counter.
      final dragging = tester.widget<Text>(find.byKey(_pageLabelKey)).data!;
      expect(dragging, isNot(contains('·')));
      expect(seeks, isEmpty, reason: 'no JS call per drag tick');
      await gesture.up();
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single, greaterThan(0.4));
      expect(seeks.single, lessThanOrEqualTo(1));
      // The preview survives until the WebView reports the new location.
      expect(
        tester.widget<Text>(find.byKey(_pageLabelKey)).data,
        isNot(contains('·')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<Text>(find.byKey(_pageLabelKey)).data,
        contains('·'),
      );
    });

    testWidgets('dragging rebuilds only the progress row', (tester) async {
      await pump(tester);
      final capsule = tester.element(find.byKey(_capsuleKey));
      final before = capsule.widget;
      final rect = tester.getRect(find.byType(Slider));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(
        identical(tester.element(find.byKey(_capsuleKey)).widget, before),
        isTrue,
      );
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    });

    for (final rtl in [false, true]) {
      testWidgets('follows the book page progression rtl=$rtl', (
        tester,
      ) async {
        await update(
          tester,
          bloc,
          ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/2)',
            progress: 0.2,
            chapterTitle: 'Chapter $rtl',
            chapterCurrentPage: 1,
            chapterTotalPages: 16,
            minutesLeft: 3,
            pageProgressionRtl: rtl,
            currentPageBookmarked: true,
          ),
        );
        // The UI direction is the opposite one: the row follows the book.
        await pump(tester, rtl: !rtl);
        final start = tester.getRect(find.byKey(_startLabelKey));
        final page = tester.getRect(find.byKey(_pageLabelKey));
        expect(start.center.dx < page.center.dx, !rtl);
        final sliderDirection = Directionality.of(
          tester.element(find.byType(Slider)),
        );
        expect(sliderDirection, rtl ? TextDirection.rtl : TextDirection.ltr);
        // The chapter is book content and follows the book's direction.
        expect(
          tester.widget<Text>(find.byKey(_startLabelKey)).textDirection,
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        // Both labels sit under the full-width slider.
        final slider = tester.getRect(find.byType(Slider));
        expect(start.top, closeTo(slider.bottom, .01));
        expect(page.top, closeTo(slider.bottom, .01));
      });
    }
  });

  for (final rtl in [false, true]) {
    testWidgets('2x text gives each label its own line under the slider '
        'rtl=$rtl', (tester) async {
      await update(
        tester,
        bloc,
        _chapterPosition('Chapter 12. The Long Road Home'),
      );
      await pump(tester, textScale: 2, rtl: rtl, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final start = tester.getRect(find.byKey(_startLabelKey));
      final slider = tester.getRect(find.byType(Slider));
      final page = tester.getRect(find.byKey(_pageLabelKey));
      final capsule = tester.getRect(find.byKey(_capsuleKey));
      // The slider keeps the whole row; chapter, then page, below it.
      expect(slider.width, 320 - (AppSpacing.lg + AppSpacing.md) * 2);
      expect(start.top, closeTo(slider.bottom, .01));
      expect(page.top, closeTo(start.bottom, .01));
      expect(capsule.top - page.bottom, AppSpacing.sm);
      // The page label ends on the row's end edge in the UI direction.
      const labelInset =
          AppSpacing.lg + AppSpacing.md + readerProgressTrackInset;
      if (rtl) {
        expect(page.left, closeTo(labelInset, .01));
      } else {
        expect(320 - page.right, closeTo(labelInset, .01));
      }
      expect(tester.widget<Text>(find.byKey(_startLabelKey)).maxLines, 2);
      final pageParagraph = tester.renderObject<RenderParagraph>(
        find.byKey(_pageLabelKey),
      );
      expect(pageParagraph.didExceedMaxLines, isFalse);
      expect(capsule.height, 60);
      for (final button in tester.widgetList<AppPlainIconButton>(
        capsuleButtons(),
      )) {
        expect(
          tester.getSize(find.byTooltip(button.tooltip)),
          const Size.square(48),
        );
      }
    });
  }

  for (final textScale in [1.0, 1.3]) {
    testWidgets('keeps one label line at ${textScale}x on a small phone', (
      tester,
    ) async {
      await update(tester, bloc, _chapterPosition('Chapter 2', pages: 2));
      await pump(tester, textScale: textScale, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final start = tester.getRect(find.byKey(_startLabelKey));
      final slider = tester.getRect(find.byType(Slider));
      final page = tester.getRect(find.byKey(_pageLabelKey));
      expect(slider.width, 320 - (AppSpacing.lg + AppSpacing.md) * 2);
      expect(start.center.dy, closeTo(page.center.dy, 0.5));
      expect(start.top, closeTo(slider.bottom, .01));
      expect(
        start.right,
        lessThanOrEqualTo(page.left - readerProgressLabelGap),
      );
      expect(
        page.right,
        closeTo(slider.right - readerProgressTrackInset, .01),
      );
    });
  }

  testWidgets('chrome hides in one frame under reduced motion', (tester) async {
    await pump(tester, disableAnimations: true);
    for (final slide in tester.widgetList<AnimatedSlide>(
      find.byType(AnimatedSlide),
    )) {
      expect(slide.duration, Duration.zero);
    }
    const height = 844.0;
    final capsule = find.byKey(_capsuleKey);
    expect(tester.getRect(capsule).bottom, height - AppSpacing.lg);
    uiCubit.hideChrome();
    // One frame delivers the cubit state, the next lays out the result;
    // nothing tweens in between.
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(capsule).top, greaterThanOrEqualTo(height));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: capsule, matching: find.byType(AnimatedOpacity)),
          )
          .duration,
      Duration.zero,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('chrome keeps a tween with motion enabled', (tester) async {
    await pump(tester);
    final bottom = tester.widget<AnimatedSlide>(
      find.ancestor(
        of: find.byKey(_capsuleKey),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(bottom.duration, AppMotion.short);
  });

  testWidgets('toasts avoid the slider and the capsule only while the chrome '
      'shows', (tester) async {
    await pump(tester);
    final area = find.ancestor(
      of: find.byKey(_capsuleKey),
      matching: find.byType(ToastAvoidArea),
    );
    expect(area, findsOneWidget);
    expect(tester.widget<ToastAvoidArea>(area).enabled, isTrue);
    // The marked area starts at the slider, under the backdrop's fade.
    expect(
      find.descendant(of: area, matching: find.byType(Slider)),
      findsOneWidget,
    );
    uiCubit.hideChrome();
    await tester.pumpAndSettle();
    expect(tester.widget<ToastAvoidArea>(area).enabled, isFalse);
  });

  testWidgets('hidden chrome ignores pointers', (tester) async {
    final pressed = <String>[];
    await pump(tester, pressed: pressed);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final search = tester.getCenter(find.byTooltip(l10n.readerSearchAction));
    uiCubit.hideChrome();
    await tester.pumpAndSettle();
    await tester.tapAt(search);
    expect(pressed, isEmpty);
  });

  for (final rtl in [false, true]) {
    testWidgets('page bookmark indicator sits at the trailing edge rtl=$rtl', (
      tester,
    ) async {
      await pump(tester, rtl: rtl);
      uiCubit.hideChrome();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold));
      final label = context.l10n.readerPageBookmarked;
      final indicator = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == label,
      );
      expect(find.byType(PositionedDirectional), findsOneWidget);
      final rect = tester.getRect(indicator);
      final width = tester.getSize(find.byType(Scaffold)).width;
      expect(rtl ? rect.left : width - rect.right, AppSpacing.lg);
      final glyph = tester.widget<CustomPaint>(
        find.descendant(of: indicator, matching: find.byType(CustomPaint)),
      );
      // The private painter exposes its color; the indicator is drawn with
      // the surface accent, not the filled-control primary.
      expect((glyph.painter as dynamic).color, context.actionForeground);
    });
  }
}
