import 'dart:convert';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader_webview/reader_webview.dart';

import '../test/support/reading_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';
import '../test/support/ui_test_services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late UiTestApp app;

  setUp(() async {
    app = await UiTestApp.create(nativeReader: true);
  });
  tearDown(() async => app.dispose());
  tearDownAll(() {
    binding.reportData ??= {};
    binding.reportData!['platform'] = Platform.operatingSystem;
    binding.reportData!['completedAt'] = DateTime.now()
        .toUtc()
        .toIso8601String();
    binding.reportData!['tests'] = binding.results.map(
      (name, result) => MapEntry(name, result.toString()),
    );
  });

  var screenshotSurfaceReady = false;
  setUp(() => screenshotSurfaceReady = false);
  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.isAndroid && !screenshotSurfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      screenshotSurfaceReady = true;
    }
    await tester.pump();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    binding.reportData ??= {};
    binding.reportData!['viewport'] = {
      'width': size.width,
      'height': size.height,
    };
    await binding.takeScreenshot(name);
  }

  BookReaderWebViewState bookState(WidgetTester tester) =>
      tester.state<BookReaderWebViewState>(find.byType(BookReaderWebView));

  Future<void> waitForBookDom(
    WidgetTester tester,
    String condition, {
    required String description,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (true) {
      final ready = await bookState(tester).debugController!.evaluateJavascript(
        source: condition,
      );
      if (ready == true) return;
      if (DateTime.now().isAfter(deadline)) fail(description);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openBook(WidgetTester tester, {bool mount = true}) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    if (mount) await tester.pumpWidget(app.widget);
    // Keep the simulator's real size; the integration binding must not impose
    // an 800x600 tablet-sized test surface on a phone.
    await tapUi(tester, find.byKey(ValueKey('library-grid-${app.book!.id}')));
    await waitForUi(
      tester,
      () {
        final element = find.byType(BookReaderWebView).evaluate().firstOrNull;
        return element != null && bookState(tester).debugIsReady;
      },
      description: 'native book renderer ready',
      timeout: const Duration(seconds: 45),
    );
    await waitForBookDom(
      tester,
      '''(window.reader?.view?.renderer?.getContents?.() ?? [])
          .some(({doc}) => doc.body?.textContent.includes(${jsonEncode(ReadingFixture.phrase)}))''',
      description: 'Book DOM never became readable',
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> select(
    WidgetTester tester,
    String text, {
    bool article = false,
  }) async {
    final controller = article
        ? tester
              .state<ArticleHtmlReaderWebViewState>(
                find.byType(ArticleHtmlReaderWebView),
              )
              .debugController!
        : bookState(tester).debugController!;
    // DOM selection intentionally tests JS -> Flutter -> action routing.
    // It does not pretend to drag iOS/Android native selection handles.
    final selected = await controller.evaluateJavascript(
      source:
          '''(() => {
      const text = ${jsonEncode(text)};
      const contents = ${article ? '[{doc: document}]' : 'window.reader.view.renderer.getContents()'};
      const doc = contents.find(({doc}) => doc.body.textContent.includes(text))?.doc;
      if (!doc) return {error: 'No matching document', documents: contents.length};
      const root = doc.querySelector('#article-content') ?? doc.body;
      const walker = doc.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      const nodes = [];
      let fullText = '';
      let node;
      while ((node = walker.nextNode())) {
        nodes.push({node, start: fullText.length, end: fullText.length + node.length});
        fullText += node.textContent;
      }
      const start = fullText.indexOf(text);
      const end = start + text.length;
      const first = nodes.find(entry => start >= entry.start && start < entry.end);
      const last = nodes.find(entry => end > entry.start && end <= entry.end);
      if (!first || !last) return {error: 'No matching range', text: fullText.slice(0, 100)};
      const range = doc.createRange();
      range.setStart(first.node, start - first.start);
      range.setEnd(last.node, end - last.start);
      doc.dispatchEvent(new Event('selectstart'));
      const selection = doc.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      doc.dispatchEvent(new Event('selectionchange'));
      // Android delivers the long-press action through contextmenu; WebKit
      // delivers it through selectionchange. Keep both production handlers.
      if (${Platform.isAndroid && !article}) {
        doc.dispatchEvent(new MouseEvent('contextmenu', {bubbles: true}));
      }
      return selection.toString();
    })()''',
    );
    expect(selected, text);
    await waitForUi(
      tester,
      () => find.text('Translate').hitTestable().evaluate().isNotEmpty,
      description: 'selection action menu',
    );
  }

  Future<void> showChrome(WidgetTester tester) async {
    if (find.byTooltip('Back').hitTestable().evaluate().isEmpty) {
      await bookState(tester).debugController!.evaluateJavascript(
        source:
            "void window.flutter_inappwebview.callHandler('onClick', {x: 0.5, y: 0.5})",
      );
    }
    await waitForUi(
      tester,
      () => find.byTooltip('Back').hitTestable().evaluate().isNotEmpty,
      description: 'reader chrome',
    );
  }

  testWidgets(
    'search UI navigates, remembers and clears a query',
    (tester) async {
      await openBook(tester);
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Search'));
      await tester.enterText(find.byType(TextField).hitTestable(), 'devices');
      await waitForUi(
        tester,
        () => find
            .byType(ReaderSearchResultTile)
            .hitTestable()
            .evaluate()
            .isNotEmpty,
        description: 'search results from the actual book',
      );
      final searchCubit = tester
          .element(find.byType(TextField).hitTestable())
          .read<ReaderSearchCubit>();
      await waitForUi(
        tester,
        () => !searchCubit.state.isLoading,
        description: 'search completed',
      );
      expect(searchCubit.state.results.length, greaterThan(10));
      final tile = find.byType(ReaderSearchResultTile).hitTestable().first;
      final destination = tester
          .widget<ReaderSearchResultTile>(tile)
          .result
          .cfi;
      expect(destination, isNotEmpty);
      await capture(tester, 'book-search-results');
      await tapUi(tester, tile);
      await waitForUi(
        tester,
        () => find.byType(TextField).hitTestable().evaluate().isEmpty,
        description: 'search drawer closes on navigation',
      );
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Search'));
      expect(searchCubit.state.recentQueries, contains('devices'));
      await tapUi(tester, find.text('devices'));
      await waitForUi(
        tester,
        () => !searchCubit.state.isLoading,
        description: 'recent query rerun',
      );
      await tapUi(tester, find.bySemanticsLabel('Clear search'));
      expect(searchCubit.state.results, isEmpty);
      expect(searchCubit.state.recentQueries, contains('devices'));
      await tapUi(tester, find.byTooltip('Remove from history'));
      expect(searchCubit.state.recentQueries, isEmpty);
      await tester.enterText(
        find.byType(TextField).hitTestable(),
        'zzzznotinthebook',
      );
      await waitForUi(
        tester,
        () => find.text('No results found').evaluate().isNotEmpty,
        description: 'empty search result',
      );
      await capture(tester, 'book-search-empty');
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'bookmark creates, survives reopening and deletes from contents',
    (tester) async {
      await openBook(tester);
      final bloc = tester
          .element(find.byType(BookReaderWebView))
          .read<ReaderBloc>();
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Bookmark'));
      await waitForUi(
        tester,
        () => bloc.state.bookmarks.length == 1,
        description: 'bookmark saved',
      );
      final cfi = bloc.state.bookmarks.single.cfi;
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      final reopened = tester
          .element(find.byType(BookReaderWebView))
          .read<ReaderBloc>();
      expect(reopened.state.bookmarks.single.cfi, cfi);
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Contents'));
      await tapUi(tester, find.text('Bookmarks'));
      await capture(tester, 'book-bookmarks');
      await tapUi(tester, find.byTooltip('Delete bookmark'));
      await waitForUi(
        tester,
        () => reopened.state.bookmarks.isEmpty,
        description: 'bookmark deleted',
      );
      expect(find.text('No bookmarks yet'), findsOneWidget);
      await tapUi(tester, find.byTooltip('Close'));
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      expect(
        tester
            .element(find.byType(BookReaderWebView))
            .read<ReaderBloc>()
            .state
            .bookmarks,
        isEmpty,
      );
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'appearance reaches the DOM, persists per book and resets',
    (tester) async {
      await openBook(tester);
      final originalState = bookState(tester);
      const paragraphSize = '''(() => {
      const doc = window.reader.view.renderer.getContents()[0]?.doc;
      const paragraph = doc?.querySelector('p');
      return paragraph ? parseFloat(doc.defaultView.getComputedStyle(paragraph).fontSize) : 0;
    })()''';
      final before =
          await originalState.debugController!.evaluateJavascript(
                source: paragraphSize,
              )
              as num;
      expect(before, greaterThan(0));
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Font'));
      await tapUi(tester, find.text('Night'));
      await tapUi(tester, find.text('Open Sans'));
      await tapUi(tester, find.byTooltip('Increase text size'));
      final vertical = find.byTooltip('Vertical page turn');
      await tester.ensureVisible(vertical);
      await tapUi(tester, vertical);
      await waitForUi(tester, () {
        final appearance = app.preferencesService.readerAppearanceOverrideFor(
          app.book!.id,
        );
        return appearance?.themeId == 'night' &&
            appearance?.fontId == 'sans' &&
            (appearance?.textScale ?? 1) > 1 &&
            appearance?.pageTurnStyle == ReaderPageTurnStyle.vertical;
      }, description: 'appearance preferences persisted');
      await capture(tester, 'book-appearance');
      await dismissSheet(tester);
      expect(identical(bookState(tester), originalState), isTrue);
      await waitForBookDom(
        tester,
        '$paragraphSize > $before',
        description: 'font size did not reach the book DOM',
      );
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      await waitForBookDom(
        tester,
        '$paragraphSize > $before',
        description: 'font size not restored after reopening',
      );
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Font'));
      await tapUi(tester, find.text('Reset'));
      await waitForUi(
        tester,
        () =>
            app.preferencesService.readerAppearanceOverrideFor(app.book!.id) ==
            null,
        description: 'book override reset',
      );
      await dismissSheet(tester);
      await waitForBookDom(
        tester,
        'Math.abs($paragraphSize - $before) < 0.1',
        description: 'reset did not restore DOM font size',
      );
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'translation failure retries without reopening the selection menu',
    (tester) async {
      app.contextualTranslationService.failure =
          ContextualTranslationFailureReason.network;
      await openBook(tester);
      await select(tester, ReadingFixture.phrase);
      await tapUi(tester, find.text('Translate'));
      await waitForUi(
        tester,
        () => find.text('Translation failed').evaluate().isNotEmpty,
        description: 'translation failure',
      );
      expect(find.byType(ReaderHighlightControls), findsNothing);
      expect(
        app.contextualTranslationService.requests.single.selection.text,
        ReadingFixture.phrase,
      );
      await capture(tester, 'book-translation-error');
      app.contextualTranslationService.failure = null;
      await tapUi(tester, find.text('Retry'));
      await waitForUi(
        tester,
        () =>
            find.text(FixtureTranslation.translatedText).evaluate().isNotEmpty,
        description: 'translation retry success',
      );
      expect(app.contextualTranslationService.requests, hasLength(2));
      expect(
        app.contextualTranslationService.requests.last.selection.text,
        ReadingFixture.phrase,
      );
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'book selection uses latest range, copies and dismisses action menu',
    (
      tester,
    ) async {
      await openBook(tester);
      await capture(tester, 'book-ready');
      await select(tester, 'power');
      await select(tester, ReadingFixture.phrase);
      await capture(tester, 'book-selection');
      await tapUi(tester, find.text('Translate'));
      await waitForUi(
        tester,
        () =>
            find.text(FixtureTranslation.translatedText).evaluate().isNotEmpty,
        description: 'translation of expanded range',
      );
      expect(
        app.contextualTranslationService.requests.single.selection.text,
        ReadingFixture.phrase,
      );
      expect(
        find.byType(ReaderHighlightControls),
        findsNothing,
        reason: 'Selection menu must close before the modal sheet',
      );
      await capture(tester, 'book-translation');
      final passage =
          app.contextualTranslationService.requests.single.context.current!;
      expect(passage.text, ReadingFixture.sentence);
      expect(passage.markedText, 'The [[power bank]] keeps devices running.');
      expect(passage.normalizedMarkedText, passage.markedText);
      final sentencePreview = tester.widget<Text>(
        find.byKey(const ValueKey('translation-selection-preview-text')),
      );
      expect(sentencePreview.textSpan!.toPlainText(), ReadingFixture.sentence);
      await tapUi(tester, find.byTooltip('Copy'));
      expect(
        (await Clipboard.getData(Clipboard.kTextPlain))?.text,
        FixtureTranslation.translatedText,
      );
      expect(app.contextualTranslationService.requests, hasLength(1));
      await dismissSheet(tester);
      await select(tester, 'power');
      await tapUi(tester, find.text('Define'));
      await waitForUi(
        tester,
        () =>
            find.text('Energy used to operate a device.').evaluate().isNotEmpty,
        description: 'dictionary fallback',
      );
      expect(app.systemDictionaryService.requests, ['power']);
      expect(app.dictionaryLookupService.requests.single.term, 'power');
      expect(find.text('power'), findsOneWidget);
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await capture(tester, 'book-definition');
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'dictionary keeps word and expression copies in the same reader',
    (tester) async {
      app.dictionaryLookupService.entries = const [
        DictionaryLexicalEntry(
          lemma: 'shut',
          partOfSpeech: 'verb',
          definitions: [DictionaryDefinition(text: 'To close something.')],
        ),
        DictionaryLexicalEntry(
          lemma: 'shut off',
          partOfSpeech: 'phrasal verb',
          definitions: [
            DictionaryDefinition(
              text: 'To stop operating or to stop a supply.',
              examples: ['Shut off the display to save power.'],
            ),
          ],
        ),
      ];
      await openBook(tester);
      final originalReader = bookState(tester);
      await select(tester, 'shutting');
      await tapUi(tester, find.text('Define'));
      await waitForUi(
        tester,
        () => find.text('shut off').evaluate().isNotEmpty,
        description: 'word and contextual expression definitions',
      );
      expect(find.text('shutting'), findsOneWidget);
      expect(find.text('shut'), findsOneWidget);
      expect(find.text('In this context'), findsOneWidget);
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await capture(tester, 'book-definition-expression');
      final copies = find.byType(AppCopyButton);
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(copies.at(i));
        await tapUi(tester, copies.at(i));
        final entry = app.dictionaryLookupService.entries[i];
        expect(
          (await Clipboard.getData(Clipboard.kTextPlain))?.text,
          '${entry.lemma}\n1. ${entry.definitions.single.text}',
        );
      }
      expect(app.dictionaryLookupService.requests, hasLength(1));
      expect(app.dictionaryLookupService.requests.single.term, 'shutting');
      await dismissSheet(tester);
      expect(identical(bookState(tester), originalReader), isTrue);
      await select(tester, 'power');
      expect(find.byType(ReaderHighlightControls), findsOneWidget);
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'translation details and language changes keep the native reader intact',
    (tester) async {
      app.contextualTranslationService.includeLexicalDetails = true;
      await openBook(tester);
      final originalReader = bookState(tester);
      await select(tester, ReadingFixture.phrase);
      expect(find.byIcon(AppIcons.translate), findsOneWidget);
      await tapUi(tester, find.text('Translate'));
      await waitForUi(
        tester,
        () => find.text('Externer Akku').evaluate().isNotEmpty,
        description: 'contextual translation result',
      );
      expect(find.text('Zusatzakku'), findsNothing);
      final details = find.byType(ExpansionTile);
      await tester.ensureVisible(details);
      await tapUi(tester, details);
      await tester.ensureVisible(find.text('Ersatzakku'));
      await capture(tester, 'book-translation-details');
      expect(app.contextualTranslationService.requests, hasLength(1));

      final target = find.byKey(const ValueKey('translation-target-language'));
      await tester.ensureVisible(target);
      await tapUi(tester, target);
      final french = find.widgetWithText(MenuItemButton, 'Français');
      await tester.ensureVisible(french);
      await tapUi(tester, french);
      await waitForUi(
        tester,
        () =>
            app.contextualTranslationService.requests.length == 2 &&
            find.text('Externer Akku').evaluate().isNotEmpty,
        description: 'translation with the new target',
      );
      final request = app.contextualTranslationService.requests.last;
      expect(request.selection.text, ReadingFixture.phrase);
      expect(request.sourceLanguage, 'auto');
      expect(request.targetLanguage, 'fr');
      expect(find.text('Zusatzakku'), findsNothing);
      expect(find.text('Auto: English'), findsOneWidget);
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await capture(tester, 'book-translation-language-changed');
      await dismissSheet(tester);
      expect(identical(bookState(tester), originalReader), isTrue);
      await select(tester, 'power');
      expect(find.byType(ReaderHighlightControls), findsOneWidget);
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'highlight is explicit, persists and returns in reopened book',
    (
      tester,
    ) async {
      await openBook(tester);
      await select(tester, ReadingFixture.phrase);
      final palette = find.byType(ReaderHighlightControls);
      expect(palette, findsOneWidget);
      await tapUi(tester, find.byTooltip('Highlight'));
      await waitForUi(tester, () {
        final element = find.byType(BookReaderWebView).evaluate().firstOrNull;
        return element != null &&
            element.read<ReaderBloc>().state.highlights.isNotEmpty;
      }, description: 'saved highlight');
      final saved = await app.highlightRepository.getHighlightsBySource(
        app.book!.id,
      );
      expect(saved.single.text, ReadingFixture.phrase);
      final cfi = saved.single.cfiRange;
      expect(cfi, isNotEmpty);
      await waitForUi(
        tester,
        () => find.byType(ReaderHighlightControls).evaluate().isEmpty,
        description: 'highlight menu dismissed',
      );
      await bookState(tester).debugController!.evaluateJavascript(
        source:
            "void window.flutter_inappwebview.callHandler('onClick', {x: 0.5, y: 0.5})",
      );
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      final highlights = tester
          .widget<BookReaderWebView>(find.byType(BookReaderWebView))
          .highlights;
      expect(highlights, hasLength(1));
      expect(highlights.single.cfiRange, cfi);
      await waitForBookDom(
        tester,
        '''window.reader.view.renderer.getContents().some(({overlayer}) =>
          [...(overlayer?.element.querySelectorAll('rect') ?? [])].some(rect => {
            const bounds = rect.getBoundingClientRect();
            return bounds.width > 0 && bounds.height > 0;
          }))''',
        description: 'Saved highlight never rendered after reopening the book',
      );
      await capture(tester, 'book-highlight-reopened');
      final rendered = await bookState(tester).debugController!.evaluateJavascript(
        source:
            'window.reader.view.renderer.getContents()[0].doc.body.innerText.length',
      );
      expect(rendered, greaterThan(100));
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'selection over saved highlights translates and replaces only on save',
    (tester) async {
      await openBook(tester);

      Future<void> saveSelection(String text, int count) async {
        await select(tester, text);
        await tapUi(tester, find.byTooltip('Highlight'));
        await waitForUi(tester, () {
          final highlights = tester
              .element(find.byType(BookReaderWebView))
              .read<ReaderBloc>()
              .state
              .highlights;
          return highlights.length == count &&
              highlights.any((highlight) => highlight.text == text) &&
              find.byType(ReaderHighlightControls).evaluate().isEmpty;
        }, description: 'highlight saved and menu dismissed');
        await waitForBookDom(
          tester,
          'window.reader.annotationsById.size === $count',
          description: 'Saved annotations not synchronized with WebView',
        );
      }

      await saveSelection('power', 1);
      await saveSelection('devices', 2);
      final original = await app.highlightRepository.getHighlightsBySource(
        app.book!.id,
      );
      await waitForUi(
        tester,
        () => find.text('Highlight saved').evaluate().isEmpty,
        description: 'save confirmation dismissed before capturing selection',
      );
      await select(tester, ReadingFixture.sentence);
      await capture(tester, 'book-selection-over-highlights');
      await tapUi(tester, find.text('Translate'));
      await waitForUi(
        tester,
        () =>
            find.text(FixtureTranslation.translatedText).evaluate().isNotEmpty,
        description: 'wider selection translated',
      );
      expect(
        app.contextualTranslationService.requests.single.selection.text,
        ReadingFixture.sentence,
      );
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await dismissSheet(tester);
      expect(
        await app.highlightRepository.getHighlightsBySource(app.book!.id),
        unorderedEquals(original),
        reason: 'Translate must not replace highlights',
      );

      await saveSelection(ReadingFixture.sentence, 1);
      final merged = (await app.highlightRepository.getHighlightsBySource(
        app.book!.id,
      )).single;
      expect(merged.text, ReadingFixture.sentence);
      expect(
        original.map((highlight) => highlight.id),
        isNot(contains(merged.id)),
      );
      await app.highlightRepository.updateHighlightNote(
        merged.id,
        'Keep my note',
      );
      await saveSelection(ReadingFixture.sentence, 1);
      final repeated = (await app.highlightRepository.getHighlightsBySource(
        app.book!.id,
      )).single;
      expect(repeated.id, merged.id);
      expect(repeated.note, 'Keep my note');

      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      final reopened = tester
          .widget<BookReaderWebView>(find.byType(BookReaderWebView))
          .highlights
          .single;
      expect(reopened.cfiRange, merged.cfiRange);
      await waitForBookDom(
        tester,
        '''window.reader.annotationsById.size === 1 &&
          window.reader.view.renderer.getContents().some(({overlayer}) =>
            [...(overlayer?.element.querySelectorAll('rect') ?? [])].some(rect => {
              const bounds = rect.getBoundingClientRect();
              return bounds.width > 0 && bounds.height > 0;
            }))''',
        description: 'Merged highlight did not render after reopening',
      );
      await capture(tester, 'book-merged-highlight-reopened');
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'reader survives lifecycle callbacks and retains search navigation',
    (
      tester,
    ) async {
      await openBook(tester);
      final state = bookState(tester);
      final bloc = tester
          .element(find.byType(BookReaderWebView))
          .read<ReaderBloc>();
      final initialPosition = bloc.state.document?.currentCfi;
      final results = await state.searchBook('devices');
      expect(results, isNotEmpty);
      state.goToSearchResult(results.last.cfi);
      await waitForUi(
        tester,
        () {
          final position = bloc.state.document?.currentCfi;
          return position != null &&
              position.isNotEmpty &&
              position != initialPosition;
        },
        description: 'search navigation updates reading position',
      );
      final before = bloc.state.document!.currentCfi;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        identical(bookState(tester), state),
        isTrue,
        reason: 'Ordinary resume must not recreate the book WebView',
      );
      expect(bloc.state.document?.currentCfi, before);
      expect(
        await state.debugController!.evaluateJavascript(
          source:
              'window.reader.view.renderer.getContents()[0].doc.body.innerText.length',
        ),
        greaterThan(100),
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'book-resumed');
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'article imports locally and translates the complete selection',
    (tester) async {
      await app.articleRepository.addExtractedArticle(ReadingFixture.article);
      await tester.pumpWidget(app.widget);
      await tapUi(tester, find.text(ReadingFixture.articleTitle));
      await waitForUi(
        tester,
        () {
          final webView = find.byType(ArticleHtmlReaderWebView);
          return webView.evaluate().isNotEmpty &&
              tester.state<ArticleHtmlReaderWebViewState>(webView).debugIsReady;
        },
        description: 'native article renderer ready',
        timeout: const Duration(seconds: 45),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await select(tester, 'power', article: true);
      await select(tester, ReadingFixture.sentence, article: true);
      await tapUi(tester, find.text('Translate'));
      await waitForUi(
        tester,
        () =>
            find.text(FixtureTranslation.translatedText).evaluate().isNotEmpty,
        description: 'complete article selection translated',
      );
      expect(
        app.contextualTranslationService.requests.single.selection.text,
        ReadingFixture.sentence,
      );
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await capture(tester, 'article-translation');
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );
}
