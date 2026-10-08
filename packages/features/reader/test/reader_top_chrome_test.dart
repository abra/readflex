import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_chrome_colors.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

const _lineKey = ValueKey('readerTopChromeLine');
const _titleButtonKey = ValueKey('readerArticleTitleButton');

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
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.close();
    }
    blocs.clear();
    await uiCubit.close();
    await selectionCubit.close();
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
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
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
          ],
          child: Scaffold(
            body: Stack(
              children: [
                ReaderTopChromeDriver(
                  readerTheme: theme.data,
                  onArticleTitlePressed: onArticleTitlePressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder topChrome() => find.ancestor(
    of: find.byKey(_lineKey),
    matching: find.byType(AnimatedSlide),
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
    expect(tester.widget<InkWell>(button).onTap, isNotNull);
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
    final bloc =
        await tester.runAsync(() => loadBloc(chapterTitle: 'Intro'))
            as ReaderBloc;
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
    final bloc =
        await tester.runAsync(
              () => loadBloc(source: book, chapterTitle: 'Book One'),
            )
            as ReaderBloc;
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
    final bloc =
        await tester.runAsync(
              () => loadBloc(source: comic, chapterTitle: 'IMG_0004.jpg'),
            )
            as ReaderBloc;
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
      final bloc =
          await tester.runAsync(
                () => loadBloc(source: book, chapterTitle: 'One'),
              )
              as ReaderBloc;
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
      final bloc =
          await tester.runAsync(
                () => loadBloc(source: long, chapterTitle: 'Chapter One'),
              )
              as ReaderBloc;
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
    final bloc =
        await tester.runAsync(
              () => loadBloc(source: book, chapterTitle: 'Book One'),
            )
            as ReaderBloc;
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
