import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:pagecraft/all_formats.dart';

import '../test/support/reading_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';
import '../test/support/ui_test_services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late UiTestApp app;

  setUp(() async {
    app = await UiTestApp.create();
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

  Future<void> capture(WidgetTester tester, String name) async {
    // Finish short overlay transitions before capturing the native compositor.
    await tester.pump(const Duration(milliseconds: 350));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    binding.reportData ??= {};
    binding.reportData!['viewport'] = {
      'width': size.width,
      'height': size.height,
    };
    if (Platform.isAndroid) {
      await captureAndroidScreenshot(name);
    } else {
      await binding.takeScreenshot(name).timeout(const Duration(seconds: 20));
    }
  }

  final pages = find.byType(TextPagesView);

  ReaderBloc readerBloc(WidgetTester tester) =>
      tester.element(pages).read<ReaderBloc>();

  void expectTrailingActionAligned(
    WidgetTester tester,
    Finder action, {
    required IconData iconData,
  }) {
    final close = tester.getRect(find.byIcon(AppIcons.close).hitTestable());
    final icon = tester.getRect(
      find.descendant(of: action, matching: find.byIcon(iconData)),
    );
    final button = find.ancestor(
      of: action,
      matching: find.byType(IconButton),
    );
    final field = tester.getRect(find.byType(SearchField).hitTestable());
    // Global rectangles include fractional native viewport transforms.
    expect(icon.width, closeTo(close.width, .01));
    expect(icon.height, closeTo(close.height, .01));
    expect(icon.center.dx, closeTo(close.center.dx, .01));
    expect(icon.right, closeTo(field.right, .01));
    expect(tester.getSize(button), const Size(48, 48));
  }

  /// The first paragraph on the page that contains [text], with the page
  /// it is drawn on.
  ({Finder page, TextColumnPage widget, ColumnText item})? paragraphWith(
    WidgetTester tester,
    String text,
  ) {
    for (final element in find.byType(TextColumnPage).evaluate()) {
      final widget = element.widget as TextColumnPage;
      for (final item in widget.column.items.whereType<ColumnText>()) {
        if (item.rect.top < widget.page.top ||
            item.rect.bottom > widget.page.bottom ||
            !item.paragraph.box.text.contains(text)) {
          continue;
        }
        return (
          page: find.byWidget(widget),
          widget: widget,
          item: item,
        );
      }
    }
    return null;
  }

  Future<void> openBook(WidgetTester tester, {bool mount = true}) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    if (mount) await tester.pumpWidget(app.widget);
    // Keep the simulator's real size; the integration binding must not impose
    // an 800x600 tablet-sized test surface on a phone.
    // A started book leaves the grid for the Continue reading card.
    final tile = find.byKey(ValueKey('library-grid-${app.book!.id}'));
    final continueReading = find.byKey(
      const ValueKey('libraryContinueReadingCard'),
    );
    await waitForUi(
      tester,
      () =>
          tile.hitTestable().evaluate().isNotEmpty ||
          continueReading.hitTestable().evaluate().isNotEmpty,
      description: 'book in Library',
    );
    await tapUi(
      tester,
      tile.hitTestable().evaluate().isNotEmpty ? tile : continueReading,
    );
    await waitForUi(
      tester,
      () =>
          paragraphWith(tester, ReadingFixture.phrase) != null &&
          readerBloc(tester).state.chapterTitle != null,
      description: 'the book page with the fixture text',
      timeout: const Duration(seconds: 45),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Selects [text] the way a reader does: a long press on its first word,
  /// dragged to its last character, through the platform selection and the
  /// reader's action menu. On one page; a selection does not turn pages.
  Future<void> select(WidgetTester tester, String text) async {
    final selection = tester.element(pages).read<ReaderSelectionCubit>();
    if (selection.state.hasSelection) {
      // A tap on the page ends the selection there is; the reader then
      // presses the next word.
      await tester.tapAt(tester.getRect(pages).topCenter + const Offset(0, 24));
      await waitForUi(
        tester,
        () =>
            !selection.state.hasSelection &&
            find.text('Translate').hitTestable().evaluate().isEmpty,
        description: 'the previous selection cleared',
      );
    }
    final found = paragraphWith(tester, text);
    expect(found, isNotNull, reason: '"$text" on the page');
    final (:page, :widget, :item) = found!;
    final start = item.paragraph.box.text.indexOf(text);
    // [along] of the way across the character at [offset].
    Offset at(int offset, {double along = 0.5}) {
      final box = item.paragraph.boxesFor(offset, offset + 1).first.toRect();
      return tester.getTopLeft(page) +
          item.rect.topLeft -
          Offset(0, widget.page.top) +
          Offset(box.left + box.width * along, box.center.dy);
    }

    final gesture = await tester.startGesture(at(start));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 150));
    if (text.contains(' ')) {
      // Into the last character, before its middle: the word it ends, not
      // the space after it.
      await gesture.moveTo(at(start + text.length - 1, along: 0.25));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump();
    await waitForUi(
      tester,
      () => find.text('Translate').hitTestable().evaluate().isNotEmpty,
      description: 'selection action menu',
    );
    expect(selection.state.selectedText, text);
  }

  // A toast placed while chrome was hidden keeps the bottom edge, so the
  // capsule would come back under it (toast_service places a toast once).
  Future<void> waitForSaveToastGone(WidgetTester tester) => waitForUi(
    tester,
    () => find.text('Highlight saved').evaluate().isEmpty,
    description: 'save confirmation dismissed before showing chrome',
  );

  Future<void> showChrome(WidgetTester tester) async {
    if (find.byTooltip('Back').hitTestable().evaluate().isEmpty) {
      await tester.tapAt(tester.getCenter(pages));
    }
    await waitForUi(
      tester,
      () => find.byTooltip('Back').hitTestable().evaluate().isNotEmpty,
      description: 'reader chrome',
    );
  }

  /// Whether the saved highlight [id] paints on a page on screen.
  bool highlightDrawn(WidgetTester tester, String id) =>
      find.byType(TextColumnPage).evaluate().any((element) {
        final page = element.renderObject;
        return page is RenderTextColumnPage &&
            page.highlightRects(id).isNotEmpty;
      });

  /// The prose size the page draws: the fixture's sentence.
  double proseSize(WidgetTester tester) {
    final found = paragraphWith(tester, ReadingFixture.phrase)!;
    return found.item.paragraph.box.runs.first.style.fontSize;
  }

  testWidgets(
    'search UI navigates, remembers and clears a query',
    (tester) async {
      await openBook(tester);
      final originalPages = tester.state(pages);
      final originalBounds = tester.getRect(pages);
      final bloc = readerBloc(tester);
      await showChrome(tester);
      final originalProgress = bloc.state.document!.readingProgress;
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
      final origin = searchCubit.state.returnLocation;
      final cachedResults = searchCubit.state.results;
      expect(origin, isNotNull);
      expect(origin!.fraction, closeTo(originalProgress, 0.02));
      expect(searchCubit.state.activeResultIndex, 0);
      await tapUi(tester, find.byTooltip('Next match'));
      expect(searchCubit.state.activeResultIndex, 1);
      await tapUi(tester, find.byTooltip('Previous match'));
      expect(searchCubit.state.activeResultIndex, 0);
      expect(searchCubit.state.returnLocation, origin);
      expect(tester.state(pages), same(originalPages));
      expect(tester.getRect(pages), originalBounds);
      await capture(tester, 'book-search-navigation');
      await tapUi(tester, find.byKey(const ValueKey('reader-search-reopen')));
      expect(
        tester
            .widget<TextField>(find.byType(TextField).hitTestable())
            .controller!
            .text,
        'devices',
      );
      expect(identical(searchCubit.state.results, cachedResults), isTrue);
      expect(searchCubit.state.recentQueries, contains('devices'));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField).hitTestable(), findsNothing);
      expect(searchCubit.state.isNavigating, isTrue);
      await tapUi(tester, find.byKey(const ValueKey('reader-search-return')));
      await waitForUi(
        tester,
        () =>
            !searchCubit.state.isNavigating &&
            (bloc.state.document!.readingProgress - originalProgress).abs() <
                0.02,
        description: 'return to the pre-search reading position',
      );
      expect(searchCubit.state.returnLocation, isNull);
      expect(tester.state(pages), same(originalPages));
      expect(tester.getRect(pages), originalBounds);
      await capture(tester, 'book-search-returned');
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Search'));
      await tapUi(tester, find.text('devices'));
      await waitForUi(
        tester,
        () => !searchCubit.state.isLoading,
        description: 'new session from history',
      );
      await tapUi(tester, find.byTooltip('Clear search'));
      expect(searchCubit.state.results, isEmpty);
      expect(searchCubit.state.recentQueries, contains('devices'));
      expect(find.byTooltip('Remove from history'), findsNothing);
      await capture(tester, 'book-search-history');
      // History rows have no delete button; the row swipes end-to-start.
      await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(searchCubit.state.recentQueries, isEmpty);
      // Re-focus the retained field through a real gesture; enterText alone
      // reuses the test binding's old EditableText connection after unfocus.
      await tapUi(tester, find.byType(TextField).hitTestable());
      await tester.enterText(
        find.byType(TextField).hitTestable(),
        'zzzznotinthebook',
      );
      expect(searchCubit.state.query, 'zzzznotinthebook');
      await waitForUi(
        tester,
        () => !searchCubit.state.isLoading,
        description: 'empty query scan completed',
      );
      expect(searchCubit.state.errorMessage, isNull);
      await capture(tester, 'book-search-empty');
      await waitForUi(
        tester,
        () => find.text('No results found').evaluate().isNotEmpty,
        description: 'empty search result',
      );
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'bookmark persists, has icon-only Undo and discards Undo on closing Contents',
    (tester) async {
      await openBook(tester);
      final bloc = readerBloc(tester);
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Bookmark'));
      await waitForUi(
        tester,
        () => bloc.state.bookmarks.length == 1,
        description: 'bookmark saved',
      );
      final cfi = bloc.state.bookmarks.single.cfi;
      final original = bloc.state.bookmarks.single;
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      final reopened = readerBloc(tester);
      expect(reopened.state.bookmarks.single.cfi, cfi);
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Contents'));
      await tapUi(tester, find.text('Bookmarks'));
      expect(find.byTooltip('Delete bookmark'), findsNothing);
      await capture(tester, 'book-bookmarks');
      // Bookmark rows have no delete button; the row swipes end-to-start.
      await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      await waitForUi(
        tester,
        () => reopened.state.bookmarks.isEmpty,
        description: 'bookmark deleted',
      );
      expect(find.text('No bookmarks yet'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expectTrailingActionAligned(
        tester,
        find.byTooltip('Undo'),
        iconData: AppIcons.undo,
      );
      await capture(tester, 'book-bookmark-undo');
      await tapUi(tester, find.byTooltip('Undo'));
      await waitForUi(
        tester,
        () =>
            reopened.state.bookmarks.length == 1 &&
            reopened.state.currentPageBookmarked,
        description: 'bookmark and current-page badge restored',
      );
      expect(reopened.state.bookmarks.single, original);
      // Bookmark rows have no delete button; the row swipes end-to-start.
      await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      await waitForUi(
        tester,
        () => reopened.state.bookmarks.isEmpty,
        description: 'bookmark deleted again',
      );
      await tapUi(tester, find.byTooltip('Close'));
      await waitForUi(
        tester,
        () => reopened.state.bookmarkEdits.removed.isEmpty,
        description: 'Undo expires on Contents close',
      );
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      expect(readerBloc(tester).state.bookmarks, isEmpty);
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );

  testWidgets(
    'appearance reaches the page, persists per book and resets',
    (tester) async {
      await openBook(tester);
      final originalPages = tester.state(pages);
      final before = proseSize(tester);
      expect(before, greaterThan(0));
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Font'));
      await tapUi(tester, find.text('Night'));
      final appearanceBounds = tester.getRect(find.byType(BottomSheet));
      await tapUi(tester, find.byKey(const ValueKey('reader-font-picker')));
      expect(tester.getRect(find.byType(BottomSheet)), appearanceBounds);
      await tapUi(tester, find.byKey(const ValueKey('reader-font-sans')));
      expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
      await capture(tester, 'book-font');
      await tapUi(tester, find.byTooltip('Back'));
      expect(tester.getRect(find.byType(BottomSheet)), appearanceBounds);
      await tapUi(tester, find.byTooltip('Increase text size'));
      final vertical = find.text('Vertical');
      await tester.ensureVisible(vertical);
      await tapUi(tester, vertical);
      await waitForUi(tester, () {
        final appearance = app.preferencesService.readerAppearanceOverrideFor(
          app.book!.id,
        );
        // "Night" is the near-black preset, stored as `mist`.
        return appearance?.themeId == 'mist' &&
            appearance?.fontId == 'sans' &&
            (appearance?.textScale ?? 1) > 1 &&
            appearance?.pageTurnStyle == ReaderPageTurnStyle.vertical;
      }, description: 'appearance preferences persisted');
      await capture(tester, 'book-appearance');
      await dismissSheet(tester);
      expect(tester.state(pages), same(originalPages));
      await waitForUi(
        tester,
        () =>
            paragraphWith(tester, ReadingFixture.phrase) != null &&
            proseSize(tester) > before,
        description: 'font size did not reach the page',
      );
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      await waitForUi(
        tester,
        () => proseSize(tester) > before,
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
      await waitForUi(
        tester,
        () =>
            paragraphWith(tester, ReadingFixture.phrase) != null &&
            (proseSize(tester) - before).abs() < 0.1,
        description: 'reset did not restore the font size',
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
      final originalReader = tester.state(pages);
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
      expect(tester.state(pages), same(originalReader));
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
      final originalReader = tester.state(pages);
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
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('translation-source-language')),
          matching: find.text('English'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await capture(tester, 'book-translation-language-changed');
      await dismissSheet(tester);
      expect(tester.state(pages), same(originalReader));
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
      await waitForUi(
        tester,
        () => readerBloc(tester).state.highlights.isNotEmpty,
        description: 'saved highlight',
      );
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
      await waitForSaveToastGone(tester);
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      final highlights = readerBloc(tester).state.highlights;
      expect(highlights, hasLength(1));
      expect(highlights.single.cfiRange, cfi);
      await waitForUi(
        tester,
        () => highlightDrawn(tester, highlights.single.id),
        description: 'Saved highlight never rendered after reopening the book',
      );
      await capture(tester, 'book-highlight-reopened');
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Contents'));
      await tapUi(tester, find.text('Highlights'));
      final rows = find.byType(ReaderHighlightListTile);
      expect(rows, findsOneWidget);
      for (final icon in [
        AppIcons.copy,
        AppIcons.arrowLeft,
        AppIcons.arrowRight,
      ]) {
        expect(
          find.descendant(of: rows, matching: find.byIcon(icon)),
          findsNothing,
        );
      }
      await capture(tester, 'book-highlights-list');
      await tapUi(tester, find.text(ReadingFixture.phrase));
      expect(find.byType(ReaderHighlightListTile).hitTestable(), findsNothing);
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
          final highlights = readerBloc(tester).state.highlights;
          return highlights.length == count &&
              highlights.any((highlight) => highlight.text == text) &&
              highlights.every((h) => highlightDrawn(tester, h.id)) &&
              find.byType(ReaderHighlightControls).evaluate().isEmpty;
        }, description: 'highlight saved, drawn and menu dismissed');
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

      await waitForSaveToastGone(tester);
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Back'));
      await openBook(tester, mount: false);
      final reopened = readerBloc(tester).state.highlights.single;
      expect(reopened.cfiRange, merged.cfiRange);
      await waitForUi(
        tester,
        () => highlightDrawn(tester, reopened.id),
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
      final state = tester.state(pages);
      final bloc = readerBloc(tester);
      final initialPosition = bloc.state.document?.currentCfi;
      await showChrome(tester);
      await tapUi(tester, find.byTooltip('Search'));
      await tester.enterText(find.byType(TextField).hitTestable(), 'devices');
      final results = find.byType(ReaderSearchResultTile).hitTestable();
      await waitForUi(
        tester,
        () => results.evaluate().isNotEmpty,
        description: 'search results',
      );
      await tapUi(tester, results.last);
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
        tester.state(pages),
        same(state),
        reason: 'Ordinary resume must not recreate the book pages',
      );
      expect(bloc.state.document?.currentCfi, before);
      expect(find.byType(TextColumnPage), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, 'book-resumed');
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['native'],
  );
}
