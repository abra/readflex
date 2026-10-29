import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_focus_cubit.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:vellum/all_formats.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

/// A saved article as the import writes it: blocks with ids, each
/// sentence in a span, a heading per part, and three links.
String articleHtml() => [
  '<h1 id="block-0" data-rf-block-id="block-0">'
      '<span id="block-0-s0" data-rf-sentence="0">The Article</span></h1>',
  '<p id="block-1" data-rf-block-id="block-1">'
      '<span id="block-1-s0" data-rf-sentence="0">Opening words with '
      '<a href="https://example.com/x">a web link</a>, '
      '<a href="#block-40">a jump</a> and <a href="other.html">a path</a>.'
      '</span> '
      '<span id="block-1-s1" data-rf-sentence="1">The quick brown fox '
      'jumps over the lazy dog.</span></p>',
  for (var i = 2; i < 80; i++) ...[
    if (i == 40)
      '<h2 id="block-$i" data-rf-block-id="block-$i">'
          '<span id="block-$i-s0" data-rf-sentence="0">Part Two</span></h2>'
    else
      '<p id="block-$i" data-rf-block-id="block-$i">'
          '<span id="block-$i-s0" data-rf-sentence="0">Paragraph $i has '
          'enough words to wrap over two lines here.</span></p>',
  ],
].join('\n');

void main() {
  late Directory tempDir;
  late PreferencesService preferences;
  late FakeBookRepository books;
  late FakeArticleRepository articles;
  late FakeHighlightRepository highlights;
  late Article article;
  late List<String> externalLinks;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    tempDir = Directory.systemTemp.createTempSync('reader_article_');
    File('${tempDir.path}/content.html').writeAsStringSync(articleHtml());
    books = FakeBookRepository();
    articles = FakeArticleRepository();
    highlights = FakeHighlightRepository();
    externalLinks = [];
    article = Article(
      id: 'article-1',
      title: 'The Article',
      url: 'https://example.com/article',
      contentPath: '${tempDir.path}/article.json',
      addedAt: DateTime(2026, 1, 1),
    );
    articles.seedArticle(article);
  });

  tearDown(() {
    preferences.dispose();
    tempDir.deleteSync(recursive: true);
  });

  ReaderBloc bloc(WidgetTester tester) =>
      tester.element(find.byType(TextScrollView)).read<ReaderBloc>();

  TextScrollController controller(WidgetTester tester) =>
      tester.widget<TextScrollView>(find.byType(TextScrollView)).controller;

  /// The article opens and lays out on the real event loop: alternate
  /// with frames until [done].
  Future<void> settle(WidgetTester tester, [bool Function()? done]) async {
    bool ready() =>
        done?.call() ??
        find.byType(TextColumnPage).evaluate().isNotEmpty &&
            bloc(tester).state.document?.currentCfi != null &&
            bloc(tester).state.tocItems.any(
              (item) => item.startPercentage != null,
            );
    for (var i = 0; i < 300 && !ready(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ready(), isTrue, reason: 'timed out');
  }

  Future<void> pumpReader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: ReaderScreen(
          sourceId: article.id,
          bookRepository: books,
          articleRepository: articles,
          highlightRepository: highlights,
          preferencesService: preferences,
          screenControlService: _ScreenControlService(),
          textActions: [_FakeHighlightAction()],
          onOpenExternalLink: externalLinks.add,
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
    // Selectables in a scrollable join the selection area in a microtask
    // after the frame that built them.
    await tester.pump();
  }

  /// Where character [offset] of the paragraph containing [text] is on
  /// screen, in whichever slice shows it.
  Offset at(WidgetTester tester, String text, int offset) {
    for (final element in find.byType(TextColumnPage).evaluate()) {
      final page = element.widget as TextColumnPage;
      final box = element.renderObject! as RenderBox;
      for (final item in page.column.items.whereType<ColumnText>()) {
        if (!item.paragraph.box.text.contains(text)) continue;
        final glyph = item.paragraph
            .boxesFor(offset, offset + 1)
            .first
            .toRect();
        final local =
            page.padding.topLeft +
            item.rect.topLeft -
            Offset(0, page.page.top) +
            glyph.center;
        if (!(Offset.zero & box.size).contains(local)) continue;
        return box.localToGlobal(local);
      }
    }
    throw StateError('"$text" is not on screen');
  }

  int offsetOf(WidgetTester tester, String paragraph, String word) => tester
      .widget<TextColumnPage>(find.byType(TextColumnPage).first)
      .column
      .items
      .whereType<ColumnText>()
      .firstWhere((t) => t.paragraph.box.text.contains(paragraph))
      .paragraph
      .box
      .text
      .indexOf(word);

  Future<Finder> chromeControl(WidgetTester tester, String tooltip) async {
    var control = find.byTooltip(tooltip).hitTestable();
    if (control.evaluate().isEmpty) {
      await tester.tapAt(const Offset(195, 600));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      control = find.byTooltip(tooltip).hitTestable();
    }
    expect(control, findsOneWidget);
    return control;
  }

  /// Lets the position save its pause, then closes the reader.
  Future<void> close(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('opens on vellum with its contents and the sentence read', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(TextScrollView), findsOneWidget);
    final state = bloc(tester).state;
    expect(state.documentFeatures?.format, 'html');
    expect(state.documentFeatures?.hasSearchableText, isTrue);
    expect(state.tocItems.map((i) => (i.label, i.href, i.level)), [
      ('The Article', '#block-0', 1),
      ('Part Two', '#block-40', 2),
    ]);
    // Below the top margin, as the shell measured it.
    expect(state.tocItems.first.startPercentage, closeTo(0, 0.02));
    expect(state.tocItems.last.startPercentage, inExclusiveRange(0.3, 0.7));
    final anchor = ArticleAnchor.decode(state.document!.currentCfi)!;
    expect(anchor.blockId, startsWith('block-'));
    expect(state.chapterTitle, 'The Article');
    expect(state.minutesLeft, greaterThan(0));
    await close(tester);
  });

  testWidgets('scrolling moves the position; the heading follows', (
    tester,
  ) async {
    await pumpReader(tester);
    final first = bloc(tester).state.document!.currentCfi;
    await tester.fling(
      find.byType(TextScrollView),
      const Offset(0, -2400),
      3000,
    );
    await tester.pumpAndSettle();
    await settle(tester, () => bloc(tester).state.chapterTitle == 'Part Two');
    final state = bloc(tester).state;
    expect(state.document!.currentCfi, isNot(first));
    expect(state.document!.readingProgress, greaterThan(0.3));
    // Saved after a pause, as books are.
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(articles.updatedArticle?.currentCfi, state.document!.currentCfi);
    await close(tester);
  });

  testWidgets('reopens at the saved sentence, centred', (tester) async {
    final doc = ContentDocument.parseHtml(
      '<main id="article-content">${articleHtml()}</main>',
    );
    final saved = ArticleAnchor.forSentence(
      doc,
      doc.elementIndexById('block-60-s0'),
    )!;
    articles.articles[0] = article.copyWith(
      currentCfi: saved.encode(),
      readingProgress: 0.7,
    );
    await pumpReader(tester);
    final anchor = ArticleAnchor.decode(
      bloc(tester).state.document!.currentCfi,
    );
    // The shell's anchor names the sentence's own id as its block.
    expect(anchor?.blockId, 'block-60-s0');
    expect(controller(tester).scroll.offset, greaterThan(0));
    await close(tester);
  });

  testWidgets('the bookmark button bookmarks the sentence read', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = tester.element(find.byType(TextScrollView)).l10n;
    await tester.tap(await chromeControl(tester, strings.readerBookmark));
    await tester.pumpAndSettle();
    final saved = books.bookmarksBySourceId[article.id]!.single;
    final anchor = ArticleAnchor.decode(saved.cfi)!;
    expect(saved.cfi, bloc(tester).state.document!.currentCfi);
    expect(saved.anchorExact, anchor.sentenceText);
    expect(saved.content, anchor.sentenceText);
    await settle(
      tester,
      () => find.byTooltip(strings.readerRemoveBookmark).evaluate().isNotEmpty,
    );
    await close(tester);
  });

  testWidgets('a long press selects with the sentence as context and an '
      'article anchor', (tester) async {
    await pumpReader(tester);
    final quick = offsetOf(tester, 'The quick brown', 'quick');
    final where = at(tester, 'The quick brown', quick + 1);
    await tester.longPressAt(where);
    await tester.pumpAndSettle();
    final selection = tester
        .element(find.byType(TextScrollView))
        .read<ReaderSelectionCubit>()
        .state;
    expect(selection.hasSelection, isTrue);
    expect(selection.selectedText, 'quick');
    expect(
      selection.markedContextText,
      'The [[quick]] brown fox jumps over the lazy dog.',
    );
    final anchor = ArticleAnchor.decode(selection.cfiRange)!;
    expect(anchor.rangeRootId, 'block-1-s1');
    expect(anchor.matchText, 'quick');
    expect(selection.chapterTitle, 'The Article');
    await close(tester);
  });

  testWidgets('saved highlights are tinted on their text; a tap focuses '
      'one', (tester) async {
    final doc = ContentDocument.parseHtml(
      '<main id="article-content">${articleHtml()}</main>',
    );
    final text = doc.elementIndexById('block-1-s1') + 1;
    // "quick brown", saved while the article was read in the WebView.
    final saved = ArticleSelection.of(
      doc,
      TextPointRange(TextPoint(text, 4), TextPoint(text, 15)),
    )!;
    highlights.seedHighlights(article.id, [
      Highlight(
        id: 'h1',
        sourceId: article.id,
        sourceType: SourceType.article,
        text: saved.text,
        cfiRange: saved.cfi,
        createdAt: DateTime(2026, 1, 1),
      ),
      Highlight(
        id: 'gone',
        sourceId: article.id,
        sourceType: SourceType.article,
        text: 'no longer there',
        cfiRange: 'readflex-html-position:%7B%22blockId%22%3A%22x%22%7D',
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);
    await pumpReader(tester);
    await settle(
      tester,
      () => tester
          .widget<TextScrollView>(find.byType(TextScrollView))
          .highlights
          .isNotEmpty,
    );
    final tints = tester
        .widget<TextScrollView>(find.byType(TextScrollView))
        .highlights;
    expect(tints.map((t) => t.id), ['h1']);
    final shown = controller(tester).section!.prepared.document;
    expect(shown.textOfRange(tints.single.range), 'quick brown');

    final quick = offsetOf(tester, 'The quick brown', 'quick');
    await tester.tapAt(at(tester, 'The quick brown', quick + 2));
    await tester.pumpAndSettle();
    final focus = tester
        .element(find.byType(TextScrollView))
        .read<ReaderHighlightFocusCubit>()
        .state;
    expect(focus.highlightId, 'h1');
    expect(focus.contextText, 'quick brown');
    await close(tester);
  });

  testWidgets('links: a web link asks first, a fragment jumps, a path is '
      'inert', (tester) async {
    await pumpReader(tester);
    final web = offsetOf(tester, 'Opening words', 'web link');
    await tester.tapAt(at(tester, 'Opening words', web + 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('example.com'), findsWidgets);
    expect(externalLinks, isEmpty);
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();

    final path = offsetOf(tester, 'Opening words', 'a path');
    final before = controller(tester).scroll.offset;
    await tester.tapAt(at(tester, 'Opening words', path + 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('other.html'), findsNothing);
    expect(controller(tester).scroll.offset, before);

    final jump = offsetOf(tester, 'Opening words', 'a jump');
    await tester.tapAt(at(tester, 'Opening words', jump + 3));
    await settle(tester, () => bloc(tester).state.chapterTitle == 'Part Two');
    expect(controller(tester).scroll.offset, greaterThan(before));
    await close(tester);
  });

  testWidgets('search finds sentences under their headings, tints every '
      'hit and opens one', (tester) async {
    await pumpReader(tester);
    final strings = tester.element(find.byType(TextScrollView)).l10n;
    await tester.tap(await chromeControl(tester, strings.readerSearchAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'paragraph 7');
    final search = tester
        .element(find.byType(TextScrollView))
        .read<ReaderSearchCubit>();
    await settle(
      tester,
      () => !search.state.isLoading && search.state.results.length == 11,
    );
    // Paragraph 7 is before the second heading, 70 to 79 after it.
    expect(search.state.results.first.chapterTitle, 'The Article');
    expect(
      search.state.results.skip(1).map((r) => r.chapterTitle).toSet(),
      {'Part Two'},
    );
    expect(search.state.results.first.excerpt.match, 'Paragraph 7');
    List<TextHighlight> tints() =>
        tester.widget<TextScrollView>(find.byType(TextScrollView)).highlights;
    expect(tints(), hasLength(11), reason: 'every hit tinted');

    // The first result: Paragraph 7, marked apart from the others.
    await tester.tap(find.textContaining('7 has', findRichText: true).first);
    await settle(
      tester,
      () => controller(tester).position!.reason == TextScrollReason.navigation,
    );
    await tester.pumpAndSettle();
    final colors = tints().map((t) => t.color).toList();
    final active = colors.where((c) => c != colors.first).toList();
    expect(colors, hasLength(11));
    expect(active, hasLength(1), reason: 'one hit marked as opened');
    final doc = controller(tester).section!.prepared.document;
    final opened = tints().firstWhere((t) => t.color == active.single);
    expect(doc.textOfRange(opened.range), 'Paragraph 7');
    await close(tester);
  });
}

class _ScreenControlService implements ScreenControlService {
  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}

  @override
  Future<double?> readApplicationBrightness() async => 0.5;

  @override
  Future<void> setApplicationBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationBrightness() async {}
}

/// The highlight action, which the selection popup needs to appear.
class _FakeHighlightAction extends ColorHighlightTextAction {
  @override
  String get label => 'Highlight';

  @override
  IconData get icon => Icons.brush;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {}

  @override
  Future<void> onExecuteWithColor(
    BuildContext context,
    TextSelectionContext selection,
    HighlightColor color,
  ) async {}
}
