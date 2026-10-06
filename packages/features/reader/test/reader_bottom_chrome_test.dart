import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  final comic = Book(
    id: 'comic',
    title: 'Comic',
    filePath: '/comic.cbz',
    format: BookFormat.cbz,
    addedAt: DateTime(2026),
  );
  late PreferencesService preferences;
  late ReaderBloc bloc;
  late ReaderBloc comicBloc;
  late ReaderUiCubit uiCubit;
  late ReaderSelectionCubit selectionCubit;
  late ReaderAppearanceCubit appearanceCubit;

  // Blocs are loaded in real time; the widget bodies run under FakeAsync.
  Future<ReaderBloc> load(Book source) async {
    final loaded = ReaderBloc(
      bookRepository: FakeBookRepository()..seedBook(source),
      highlightRepository: FakeHighlightRepository(),
      initialSource: source,
    );
    loaded.add(ReaderSourceLoadRequested(sourceId: source.id));
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

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    bloc = await load(book);
    comicBloc = await load(comic);
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
    await uiCubit.close();
    await selectionCubit.close();
    await appearanceCubit.close();
    preferences.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    ReaderBloc? source,
    bool dark = false,
    bool rtl = false,
    bool disableAnimations = false,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
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
                  onTocPressed: () {},
                  onFontPressed: () {},
                  onPageTurnPressed: () {},
                  onBookmarkPressed: () {},
                  onSearchPressed: () {},
                  onSeekFraction: (_) {},
                ),
                const ReaderPageBookmarkIndicatorDriver(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bottom chrome keeps the 16dp content gutter', (tester) async {
    await pump(tester);
    // The top chrome asserts the same gutter in reader_top_chrome_test.dart.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('toolbar actions are shared plain icon buttons', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    for (final tooltip in [
      l10n.readerBack,
      l10n.readerContents,
      l10n.readerFontAction,
      l10n.readerRemoveBookmark,
      l10n.readerSearchAction,
    ]) {
      final button = find.byTooltip(tooltip);
      expect(
        find.ancestor(of: button, matching: find.byType(AppPlainIconButton)),
        findsOneWidget,
        reason: tooltip,
      );
      expect(tester.getSize(button), const Size.square(48), reason: tooltip);
    }
    expect(find.byType(AppPlainIconButton), findsNWidgets(5));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('bottom chrome glyphs use the action foreground dark=$dark', (
      tester,
    ) async {
      await pump(tester, source: comicBloc, dark: dark);
      final context = tester.element(find.byType(Scaffold));
      final l10n = context.l10n;
      final pageTurn = tester.widget<AppPlainIconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppPlainIconButton &&
              (widget.icon == AppIcons.pageTurnHorizontal ||
                  widget.icon == AppIcons.pageTurnVertical),
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
      final slider = tester.widget<SliderTheme>(find.byType(SliderTheme));
      expect(slider.data.activeTrackColor, context.colors.primary);
      if (dark) {
        expect(context.actionForeground, isNot(context.colors.primary));
      }
    });
  }

  testWidgets('page label uses the localized page-of-total format', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('ru'));
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    expect(l10n.localeName, 'ru');
    expect(find.text('20% · ${l10n.readerPageOfTotal(1, 16)}'), findsOneWidget);
  });

  testWidgets('comic header shows the page counter, not the file name', (
    tester,
  ) async {
    // Blocs run in real time; drive them outside FakeAsync before pumping.
    await tester.runAsync(() async {
      final updated = comicBloc.stream.firstWhere(
        (s) => s.chapterTitle == 'IMG_0004.jpg',
      );
      comicBloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/8)',
          progress: 0.2,
          chapterTitle: 'IMG_0004.jpg',
          chapterCurrentPage: 3,
          chapterTotalPages: 16,
        ),
      );
      await updated.timeout(const Duration(seconds: 3));
    });
    await pump(tester, source: comicBloc);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    expect(find.text('IMG_0004.jpg'), findsNothing);
    expect(find.text(l10n.readerPageOfTotal(4, 16)), findsOneWidget);

    // Text books keep their chapter title in the header.
    await tester.runAsync(() async {
      final updated = bloc.stream.firstWhere(
        (s) => s.chapterTitle == 'Chapter 2',
      );
      bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.2,
          chapterTitle: 'Chapter 2',
          chapterCurrentPage: 1,
          chapterTotalPages: 16,
        ),
      );
      await updated.timeout(const Duration(seconds: 3));
    });
    await pump(tester);
    expect(find.text('Chapter 2'), findsOneWidget);
  });

  testWidgets('chrome hides in one frame under reduced motion', (tester) async {
    await pump(tester, disableAnimations: true);
    for (final slide in tester.widgetList<AnimatedSlide>(
      find.byType(AnimatedSlide),
    )) {
      expect(slide.duration, Duration.zero);
    }
    final height = tester.getSize(find.byType(Scaffold)).height;
    final panel = find.byType(AppBottomSafeArea);
    expect(tester.getRect(panel).bottom, height);
    uiCubit.hideChrome();
    // One frame delivers the cubit state, the next lays out the result;
    // nothing tweens in between.
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(panel).top, greaterThanOrEqualTo(height));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: panel, matching: find.byType(AnimatedOpacity)),
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
        of: find.byType(AppBottomSafeArea),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(bottom.duration, AppMotion.short);
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
