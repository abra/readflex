import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reader/src/reader_article_progress_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_chrome_colors.dart';
import 'package:reader/src/reader_screen_chrome.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

const _lineKey = ValueKey('readerTopChromeLine');
const _titleButtonKey = ValueKey('readerArticleTitleButton');
const _progressKey = ValueKey('readerArticleProgress');

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final article = Article(
    id: 'article-1',
    title: 'Saved Article',
    url: 'https://example.com/article',
    siteName: 'Example',
    contentPath: '/articles/article-1/article.json',
    addedAt: DateTime(2024, 1, 1),
  );
  final book = Book(
    id: 'book-1',
    title: 'Dune',
    filePath: '/books/dune.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2024, 1, 1),
  );
  final comic = Book(
    id: 'comic-1',
    title: 'Comic',
    filePath: '/books/comic.cbz',
    format: BookFormat.cbz,
    addedAt: DateTime(2024, 1, 1),
  );
  late ReaderUiCubit uiCubit;
  late ReaderSelectionCubit selectionCubit;
  late ReaderArticleProgressCubit articleProgressCubit;
  final blocs = <ReaderBloc>[];

  Future<ReaderBloc> loadBloc({
    Book? source,
    Article? savedArticle,
    String? chapterTitle,
  }) async {
    final bloc = ReaderBloc(
      bookRepository: FakeBookRepository()
        ..seedBook(
          source ??
              Book(
                id: 'x',
                title: '',
                filePath: '',
                format: BookFormat.epub,
                addedAt: DateTime(2024),
              ),
        ),
      articleRepository: FakeArticleRepository()
        ..seedArticle(savedArticle ?? article),
      highlightRepository: FakeHighlightRepository(),
    );
    blocs.add(bloc);
    bloc.add(
      ReaderSourceLoadRequested(sourceId: source?.id ?? article.id),
    );
    await bloc.stream
        .firstWhere((s) => s.status == ReaderStatus.ready)
        .timeout(const Duration(seconds: 3));
    if (chapterTitle != null) {
      bloc.add(
        ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.3,
          chapterTitle: chapterTitle,
        ),
      );
      await bloc.stream
          .firstWhere((s) => s.chapterTitle == chapterTitle)
          .timeout(const Duration(seconds: 3));
    }
    return bloc;
  }

  setUp(() {
    uiCubit = ReaderUiCubit()..showChrome();
    selectionCubit = ReaderSelectionCubit();
    articleProgressCubit = ReaderArticleProgressCubit();
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.close();
    }
    blocs.clear();
    await uiCubit.close();
    await selectionCubit.close();
    await articleProgressCubit.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required ReaderBloc bloc,
    void Function(String url, String title)? onArticleTitlePressed,
    ReaderThemePreset theme = ReaderThemePreset.paper,
    bool disableAnimations = false,
    bool rtl = false,
    double textScale = 1,
    double topInset = 0,
    Size size = const Size(390, 844),
    Locale locale = const Locale('en'),
    VoidCallback? onPageTap,
    bool settleAnimations = true,
  }) async {
    if (bloc.state.sourceType == SourceType.article) {
      articleProgressCubit.update(bloc.state.document!.readingProgress);
    }
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: readflexLocalizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(top: topInset),
            viewPadding: EdgeInsets.only(top: topInset),
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: uiCubit),
            BlocProvider.value(value: selectionCubit),
            BlocProvider.value(value: articleProgressCubit),
          ],
          child: Scaffold(
            body: Stack(
              children: [
                if (onPageTap != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onPageTap,
                    ),
                  ),
                ReaderTopChromeDriver(
                  readerTheme: theme.data,
                  onArticleTitlePressed: onArticleTitlePressed,
                ),
                ReaderArticleProgressDriver(readerTheme: theme.data),
              ],
            ),
          ),
        ),
      ),
    );
    if (settleAnimations) await tester.pumpAndSettle();
  }

  Finder topChrome() => find.ancestor(
    of: find.byKey(_lineKey),
    matching: find.byType(AnimatedSlide),
  );

  Future<void> reportProgress(
    WidgetTester tester,
    ReaderBloc bloc,
    double progress, {
    bool pageProgressionRtl = false,
    bool settleAnimations = true,
  }) async {
    await tester.runAsync(() async {
      final updated = bloc.stream.firstWhere(
        (state) =>
            state.document?.readingProgress == progress &&
            state.pageProgressionRtl == pageProgressionRtl,
      );
      bloc.add(
        ReaderBookPositionUpdated(
          cfi: 'article-progress:$progress',
          progress: progress,
          pageProgressionRtl: pageProgressionRtl,
        ),
      );
      await updated.timeout(const Duration(seconds: 3));
    });
    articleProgressCubit.update(progress);
    if (settleAnimations) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('article progress follows reading from start to end', (
    tester,
  ) async {
    final bloc = await tester.runAsync(loadBloc) as ReaderBloc;
    await pump(tester, bloc: bloc);
    for (final progress in [0.0, 0.42, 1.0]) {
      await reportProgress(tester, bloc, progress, pageProgressionRtl: true);
      expect(
        tester
            .widget<AppLinearProgressIndicator>(find.byKey(_progressKey))
            .value,
        progress,
      );
    }
    expect(
      Directionality.of(tester.element(find.byKey(_progressKey))),
      TextDirection.rtl,
      reason: 'progress follows the document even in an LTR app',
    );
  });

  testWidgets(
    'article progress follows each small movement before its position is saved',
    (tester) async {
      final bloc = await tester.runAsync(loadBloc) as ReaderBloc;
      await pump(tester, bloc: bloc);
      final reported = bloc.state.document!;
      for (final progress in [0.0005, 0.001, 0.0015, 0.002, 0.001]) {
        articleProgressCubit.update(progress);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester
              .widget<AppLinearProgressIndicator>(find.byKey(_progressKey))
              .value,
          progress,
        );
        expect(bloc.state.document!.readingProgress, reported.readingProgress);
        expect(bloc.state.document!.currentCfi, reported.currentCfi);
      }
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('article progress reset removes the previous reading position', (
    tester,
  ) async {
    await pump(tester, bloc: await tester.runAsync(loadBloc) as ReaderBloc);
    articleProgressCubit.update(0.8);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.widget<AppLinearProgressIndicator>(find.byKey(_progressKey)).value,
      0.8,
    );

    articleProgressCubit.reset();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(_progressKey), findsNothing);

    articleProgressCubit.update(0.1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.widget<AppLinearProgressIndicator>(find.byKey(_progressKey)).value,
      0.1,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('article progress updates immediately under reduced motion', (
    tester,
  ) async {
    final bloc = await tester.runAsync(loadBloc) as ReaderBloc;
    await pump(tester, bloc: bloc, disableAnimations: true);
    await reportProgress(tester, bloc, 0.8, settleAnimations: false);
    expect(
      tester.widget<AppLinearProgressIndicator>(find.byKey(_progressKey)).value,
      0.8,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('article progress opens directly at its saved fraction', (
    tester,
  ) async {
    final bloc = await tester.runAsync(
      () => loadBloc(
        savedArticle: article.copyWith(readingProgress: 0.65),
      ),
    ) as ReaderBloc;
    await pump(tester, bloc: bloc, settleAnimations: false);
    expect(
      tester.widget<AppLinearProgressIndicator>(find.byKey(_progressKey)).value,
      0.65,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('books and comics have no persistent article progress line', (
    tester,
  ) async {
    articleProgressCubit.update(0.8);
    for (final source in [book, comic]) {
      final bloc =
          await tester.runAsync(() => loadBloc(source: source)) as ReaderBloc;
      await pump(tester, bloc: bloc);
      expect(find.byKey(_progressKey), findsNothing);
    }
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'article progress remains at the safe top when chrome hides '
      'reducedMotion=$reducedMotion',
      (tester) async {
        await pump(
          tester,
          bloc: await tester.runAsync(loadBloc) as ReaderBloc,
          topInset: 47,
          disableAnimations: reducedMotion,
          onArticleTitlePressed: (_, _) {},
        );
        final progress = find.byKey(_progressKey);
        expect(
          tester.getTopLeft(progress).dy,
          tester.getBottomRight(find.byKey(_titleButtonKey)).dy,
        );
        expect(tester.getSize(progress).height, 3);

        uiCubit.hideChrome();
        if (reducedMotion) {
          await tester.pump();
          await tester.pump();
          expect(tester.hasRunningAnimations, isFalse);
        } else {
          await tester.pumpAndSettle();
        }
        expect(progress, findsOneWidget);
        expect(tester.getTopLeft(progress).dy, 47);

        uiCubit.showChrome();
        selectionCubit.select(text: 'Selected text');
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(progress).dy, 47);
        selectionCubit.deselect();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(progress).dy, 47 + 48);
      },
    );
  }

  testWidgets('article progress fits a small RTL phone in every reader theme', (
    tester,
  ) async {
    final bloc = await tester.runAsync(loadBloc) as ReaderBloc;
    for (final theme in ReaderThemePreset.values) {
      await pump(
        tester,
        bloc: bloc,
        theme: theme,
        rtl: true,
        textScale: 2,
        size: const Size(320, 640),
      );
      final progress = find.byKey(_progressKey);
      final indicator = tester.widget<AppLinearProgressIndicator>(progress);
      expect(indicator.color, readerChromeInkColor(theme.data));
      expect(indicator.backgroundColor, readerChromeTrackColor(theme.data));
      expect(tester.getSize(progress), const Size(320, 3));
      expect(
        Directionality.of(tester.element(progress)),
        TextDirection.ltr,
        reason: 'the article direction is independent of the app locale',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'article progress has localized semantics and passes taps through',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final bloc = await tester.runAsync(loadBloc) as ReaderBloc;
      var pageTaps = 0;
      await pump(
        tester,
        bloc: bloc,
        locale: const Locale('ru'),
        onPageTap: () => pageTaps++,
      );
      await reportProgress(tester, bloc, 0.42);
      final l10n = tester.element(find.byType(Scaffold)).l10n;
      expect(l10n.localeName, 'ru');
      final node = tester.getSemantics(
        find.bySemanticsLabel(l10n.librarySourcePercentRead(42)),
      );
      expect(node.value, '42');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      await tester.tapAt(tester.getCenter(find.byKey(_progressKey)));
      await tester.pump();
      expect(pageTaps, 1);
      semantics.dispose();
    },
  );

  testWidgets('article title is an accessible ink button', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <String>[];
    await pump(
      tester,
      bloc: await tester.runAsync(loadBloc) as ReaderBloc,
      onArticleTitlePressed: (url, _) => opened.add(url),
    );
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final button = find.byKey(_titleButtonKey);
    expect(button, findsOneWidget);
    expect(tester.widget<AppTappable>(button).onTap, isNotNull);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(
      find.bySemanticsLabel(l10n.readerOpenOriginalArticle),
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    expect(node.value, 'Saved Article');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      find.descendant(of: button, matching: find.byType(GestureDetector)),
      findsOneWidget,
      reason: 'only the ink response gesture, no bare GestureDetector',
    );
    await tester.tap(find.text('Saved Article'));
    await tester.pumpAndSettle();
    expect(opened, ['https://example.com/article']);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('the article button keeps its value with a chapter prefix', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final bloc = await tester.runAsync(
      () => loadBloc(chapterTitle: 'Intro'),
    ) as ReaderBloc;
    await pump(tester, bloc: bloc, onArticleTitlePressed: (_, _) {});
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    expect(find.text('Intro · Saved Article'), findsOneWidget);
    final node = tester.getSemantics(
      find.bySemanticsLabel(l10n.readerOpenOriginalArticle),
    );
    expect(node.value, 'Saved Article');
    semantics.dispose();
  });

  testWidgets('title is plain text without an opener', (tester) async {
    await pump(tester, bloc: await tester.runAsync(loadBloc) as ReaderBloc);
    expect(find.byKey(_titleButtonKey), findsNothing);
    expect(find.text('Saved Article'), findsOneWidget);
  });

  testWidgets('books show "chapter · title" once the chapter is known', (
    tester,
  ) async {
    final bloc = await tester.runAsync(
      () => loadBloc(source: book, chapterTitle: 'Book One'),
    ) as ReaderBloc;
    await pump(tester, bloc: bloc);
    expect(find.text('Book One · Dune'), findsOneWidget);
  });

  testWidgets('books show the title alone without a chapter', (tester) async {
    final bloc =
        await tester.runAsync(() => loadBloc(source: book)) as ReaderBloc;
    await pump(tester, bloc: bloc);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('comic file names never reach the top line', (tester) async {
    final bloc = await tester.runAsync(
      () => loadBloc(source: comic, chapterTitle: 'IMG_0004.jpg'),
    ) as ReaderBloc;
    await pump(tester, bloc: bloc);
    expect(find.text('Comic'), findsOneWidget);
    expect(find.textContaining('IMG_0004'), findsNothing);
  });

  testWidgets('the line is one muted, centred, ellipsized small line', (
    tester,
  ) async {
    await pump(tester, bloc: await tester.runAsync(loadBloc) as ReaderBloc);
    final context = tester.element(find.byType(Scaffold));
    final line = tester.widget<Text>(find.byKey(_lineKey));
    expect(line.maxLines, 1);
    expect(line.overflow, TextOverflow.ellipsis);
    expect(line.textAlign, TextAlign.center);
    expect(line.style!.fontSize, context.text.readerChromeLabel.fontSize);
    expect(
      line.style!.color,
      readerChromeInkColor(ReaderThemePreset.paper.data),
    );
  });

  for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('tablet title uses the large label role $size x$scale', (
        tester,
      ) async {
        await pump(
          tester,
          bloc: await tester.runAsync(loadBloc) as ReaderBloc,
          size: size,
          textScale: scale,
          locale: const Locale('ar'),
          rtl: true,
        );
        final line = tester.widget<Text>(find.byKey(_lineKey));
        final context = tester.element(find.byKey(_lineKey));
        expect(line.style!.fontSize, context.text.labelLarge.fontSize);
        expect(line.style!.height, context.text.labelLarge.height);
        expect(line.maxLines, 1);
        expect(
          tester.getSize(find.byKey(_lineKey)).height,
          lessThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('phone landscape keeps its original title role', (tester) async {
    await pump(
      tester,
      bloc: await tester.runAsync(loadBloc) as ReaderBloc,
      size: const Size(844, 390),
      rtl: true,
      textScale: 2,
    );
    final context = tester.element(find.byKey(_lineKey));
    final line = tester.widget<Text>(find.byKey(_lineKey));
    expect(line.style!.fontSize, context.text.readerChromeLabel.fontSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no panel plate, shadow or divider', (tester) async {
    await pump(tester, bloc: await tester.runAsync(loadBloc) as ReaderBloc);
    final decorated = tester.widgetList<DecoratedBox>(
      find.descendant(of: topChrome(), matching: find.byType(DecoratedBox)),
    );
    for (final box in decorated) {
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNull);
    }
    expect(
      find.descendant(of: topChrome(), matching: find.byType(Divider)),
      findsNothing,
    );
    // Only the page colour sits behind the line, so it reads as the page.
    final bands = tester.widgetList<ColoredBox>(
      find.descendant(of: topChrome(), matching: find.byType(ColoredBox)),
    );
    expect(bands, isNotEmpty);
    for (final band in bands) {
      expect(band.color, ReaderThemePreset.paper.data.backgroundColor);
    }
    expect(
      find.descendant(of: topChrome(), matching: find.byType(Material)),
      findsNothing,
      reason: 'books have no ink surface either',
    );
  });

  for (final preset in ReaderThemePreset.values) {
    testWidgets('line contrast is at least 4.5:1 on ${preset.id}', (
      tester,
    ) async {
      final bloc = await tester.runAsync(
        () => loadBloc(source: book, chapterTitle: 'One'),
      ) as ReaderBloc;
      await pump(tester, bloc: bloc, theme: preset);
      final line = tester.widget<Text>(find.byKey(_lineKey));
      expect(
        _contrast(line.style!.color!, preset.data.backgroundColor),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('keeps the safe-area top inset and a 48dp line', (
    tester,
  ) async {
    await pump(
      tester,
      bloc: await tester.runAsync(loadBloc) as ReaderBloc,
      topInset: 47,
      onArticleTitlePressed: (_, _) {},
    );
    final button = tester.getRect(find.byKey(_titleButtonKey));
    expect(button.top, greaterThanOrEqualTo(47));
    expect(button.height, 48);
    final line = tester.getRect(find.byKey(_lineKey));
    expect(line.center.dy, closeTo(47 + 24, 0.5));
  });

  testWidgets('top chrome keeps the 16dp content gutter like the bottom bar', (
    tester,
  ) async {
    await pump(tester, bloc: await tester.runAsync(loadBloc) as ReaderBloc);
    final padding = tester.widget<Padding>(
      find
          .ancestor(of: find.byKey(_lineKey), matching: find.byType(Padding))
          .first,
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
  });

  for (final rtl in [false, true]) {
    testWidgets('long titles stay on one line without overflow rtl=$rtl', (
      tester,
    ) async {
      final long = Book(
        id: 'long',
        title: List.filled(30, 'Phoenix Rising').join(' '),
        filePath: '/books/long.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2024),
      );
      final bloc = await tester.runAsync(
        () => loadBloc(source: long, chapterTitle: 'Chapter One'),
      ) as ReaderBloc;
      await pump(tester, bloc: bloc, rtl: rtl, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(_lineKey));
      expect(rect.left, greaterThanOrEqualTo(AppSpacing.lg));
      expect(rect.right, lessThanOrEqualTo(320 - AppSpacing.lg));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(_lineKey),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
    });
  }

  testWidgets('2x text keeps a single line without overflow', (tester) async {
    final bloc = await tester.runAsync(
      () => loadBloc(source: book, chapterTitle: 'Book One'),
    ) as ReaderBloc;
    await pump(tester, bloc: bloc, textScale: 2, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    final line = tester.widget<Text>(find.byKey(_lineKey));
    expect(line.maxLines, 1);
  });

  testWidgets('top chrome hides in one frame under reduced motion', (
    tester,
  ) async {
    await pump(
      tester,
      bloc: await tester.runAsync(loadBloc) as ReaderBloc,
      disableAnimations: true,
    );
    final slide = tester.widget<AnimatedSlide>(topChrome());
    expect(slide.duration, Duration.zero);
    uiCubit.hideChrome();
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(find.byType(SafeArea)).bottom, lessThanOrEqualTo(0));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('top chrome tweens with motion enabled', (tester) async {
    await pump(tester, bloc: await tester.runAsync(loadBloc) as ReaderBloc);
    expect(tester.widget<AnimatedSlide>(topChrome()).duration, AppMotion.short);
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(_lineKey),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.duration, AppMotion.short);
  });

  testWidgets('hidden chrome ignores pointers', (tester) async {
    final opened = <String>[];
    await pump(
      tester,
      bloc: await tester.runAsync(loadBloc) as ReaderBloc,
      onArticleTitlePressed: (url, _) => opened.add(url),
    );
    uiCubit.hideChrome();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 24));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });
}
