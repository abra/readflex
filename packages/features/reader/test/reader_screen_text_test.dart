import 'dart:convert';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:pagecraft/testing.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

/// An FB2 book on the native text engine: two chapters long enough to
/// turn pages in, a note and a web link.
String fb2() =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" '
    'xmlns:l="http://www.w3.org/1999/xlink">'
    '<description><title-info><book-title>Native</book-title>'
    '<lang>en</lang></title-info></description>'
    '<body>'
    '<section id="c1"><title><p>Chapter One</p></title>'
    '<p>Opening words with a note<a l:href="#n1" type="note">1</a> '
    'and <a l:href="https://example.com/x">a web link</a> here.</p>'
    '<p>Hello there. The quick brown fox jumps over the lazy dog.</p>'
    '${List.generate(30, (i) => '<p>First chapter paragraph $i has enough words to wrap over lines.</p>').join()}'
    '</section>'
    '<section id="c2"><title><p>Chapter Two</p></title>'
    '${List.generate(30, (i) => '<p>Second chapter paragraph $i has enough words to wrap too.</p>').join()}'
    '</section>'
    '</body>'
    '<body name="notes"><section id="n1"><title><p>1</p></title>'
    '<p>The note text.</p></section></body>'
    '</FictionBook>';

/// EPUB 2 with misleading Malay metadata and no explicit spine direction.
/// The first chapter is Malay; most of the book is Arabic styled through CSS.
List<int> mixedLanguageArabicEpub() {
  const container =
      '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">'
      '<rootfiles><rootfile full-path="OEBPS/content.opf" '
      'media-type="application/oebps-package+xml"/></rootfiles></container>';
  final archive = ZipBuilder()
    ..add('mimetype', utf8.encode('application/epub+zip'))
    ..add('META-INF/container.xml', utf8.encode(container))
    ..add(
      'OEBPS/content.opf',
      utf8.encode(
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0" '
        'unique-identifier="book-id">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="book-id">mixed-language-fixture</dc:identifier>'
        '<dc:title>Mixed language fixture</dc:title><dc:language>ms</dc:language>'
        '</metadata><manifest>'
        '<item id="intro" href="intro.xhtml" media-type="application/xhtml+xml"/>'
        '${List.generate(3, (i) => '<item id="arabic-${i + 1}" href="arabic-${i + 1}.xhtml" media-type="application/xhtml+xml"/>').join()}'
        '<item id="style" href="book.css" media-type="text/css"/>'
        '<item id="ncx" href="book.ncx" media-type="application/x-dtbncx+xml"/>'
        '</manifest><spine toc="ncx"><itemref idref="intro"/>'
        '${List.generate(3, (i) => '<itemref idref="arabic-${i + 1}"/>').join()}'
        '</spine></package>',
      ),
    )
    ..add(
      'OEBPS/book.css',
      utf8.encode('.quranb { direction: rtl; text-align: right; }'),
    )
    ..add(
      'OEBPS/book.ncx',
      utf8.encode(
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
        '<head/><docTitle><text>Mixed language fixture</text></docTitle><navMap>'
        '<navPoint id="intro" playOrder="1"><navLabel><text>Pengenalan</text>'
        '</navLabel><content src="intro.xhtml"/></navPoint>'
        '${List.generate(3, (i) => '<navPoint id="arabic-${i + 1}" playOrder="${i + 2}"><navLabel><text>الفصل ${i + 1}</text></navLabel><content src="arabic-${i + 1}.xhtml"/></navPoint>').join()}'
        '</navMap></ncx>',
      ),
    )
    ..add(
      'OEBPS/intro.xhtml',
      utf8.encode(
        '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ms">'
        '<head><title>Pengenalan</title><link rel="stylesheet" href="book.css"/>'
        '</head><body><h1>Pengenalan</h1>'
        '<p>Ini pengenalan ringkas dalam bahasa Melayu sebelum bab bahasa Arab.</p>'
        '</body></html>',
      ),
    );
  for (var i = 1; i <= 3; i++) {
    archive.add(
      'OEBPS/arabic-$i.xhtml',
      utf8.encode(
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>الفصل $i</title>'
        '<link rel="stylesheet" href="book.css"/></head><body>'
        '<h1 class="quranb">الفصل $i</h1>'
        '${List.generate(30, (p) => '<p class="quranb">هذا نص عربي لاختبار اتجاه القراءة. يبدأ القارئ من اليمين ويواصل إلى الصفحة التالية. هذه فقرة طويلة تحمل معلومات واضحة عن الكتاب والقراءة. ${p + 1}</p>').join()}'
        '</body></html>',
      ),
    );
  }
  return archive.build();
}

void main() {
  late Directory tempDir;
  late PreferencesService preferences;
  late FakeBookRepository books;
  late FakeHighlightRepository highlights;
  late Book book;
  late List<String> externalLinks;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    tempDir = Directory.systemTemp.createTempSync('reader_text_');
    final path = '${tempDir.path}/book.fb2';
    File(path).writeAsStringSync(fb2());
    books = FakeBookRepository();
    highlights = FakeHighlightRepository();
    externalLinks = [];
    book = Book(
      id: 'fb2-1',
      title: 'Native',
      filePath: path,
      format: BookFormat.fb2,
      addedAt: DateTime(2026, 1, 1),
    );
    books.seedBook(book);
  });

  tearDown(() {
    preferences.dispose();
    tempDir.deleteSync(recursive: true);
  });

  /// The book opens and lays out on the real event loop: alternate with
  /// frames until [done].
  Future<void> settle(WidgetTester tester, [bool Function()? done]) async {
    bool ready() =>
        done?.call() ??
        find.byType(TextColumnPage).evaluate().isNotEmpty &&
            tester
                    .element(find.byType(TextPagesView))
                    .read<ReaderBloc>()
                    .state
                    .chapterTitle !=
                null;
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
          sourceId: book.id,
          bookRepository: books,
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
  }

  ReaderBloc bloc(WidgetTester tester) =>
      tester.element(find.byType(TextPagesView)).read<ReaderBloc>();

  ReadflexLocalizations l10n(WidgetTester tester) =>
      tester.element(find.byType(TextPagesView)).l10n;

  /// Where character [offset] of the first paragraph containing [text]
  /// on the page is on screen.
  Offset at(WidgetTester tester, String text, int offset) {
    final page = find.byType(TextColumnPage).first;
    final widget = tester.widget<TextColumnPage>(page);
    final item = widget.column.items.whereType<ColumnText>().firstWhere(
      (t) => t.paragraph.box.text.contains(text),
    );
    final box = item.paragraph.boxesFor(offset, offset + 1).first.toRect();
    return tester.getTopLeft(page) +
        item.rect.topLeft -
        Offset(0, widget.page.top) +
        box.center;
  }

  int offsetOf(WidgetTester tester, String paragraph, String word) {
    final widget = tester.widget<TextColumnPage>(
      find.byType(TextColumnPage).first,
    );
    return widget.column.items
        .whereType<ColumnText>()
        .firstWhere((t) => t.paragraph.box.text.contains(paragraph))
        .paragraph
        .box
        .text
        .indexOf(word);
  }

  Future<Finder> chromeControl(WidgetTester tester, String tooltip) async {
    var control = find.byTooltip(tooltip).hitTestable();
    if (control.evaluate().isEmpty) {
      await tester.tapAt(const Offset(195, 422));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      control = find.byTooltip(tooltip).hitTestable();
    }
    expect(control, findsOneWidget);
    return control;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('opens an FB2 on the native engine with its contents', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(TextPagesView), findsOneWidget);
    final state = bloc(tester).state;
    // fb2.js lists the notes body's sections too.
    expect(state.tocItems.map((i) => i.label), [
      'Chapter One',
      'Chapter Two',
      '1',
    ]);
    expect(state.documentFeatures?.format, 'fb2');
    expect(state.documentFeatures?.hasSearchableText, isTrue);
    expect(state.documentFeatures?.hasTableOfContents, isTrue);
    expect(state.chapterTitle, 'Chapter One');
    // The book's media queries see this window and screen.
    final media = tester
        .widget<TextPagesView>(find.byType(TextPagesView))
        .controller
        .layout
        .style
        .media;
    expect(media.viewportWidth, 390);
    expect(media.viewportHeight, 844);
    expect(media.darkColorScheme, isFalse);

    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, startsWith('epubcfi(/6/'));
    await close(tester);
  });

  testWidgets('a book pagecraft does not lay out yet fails to open', (
    tester,
  ) async {
    // A fixed-layout EPUB: pages of a fixed size.
    const container =
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">'
        '<rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>';
    final path = '${tempDir.path}/fixed.epub';
    File(path).writeAsBytesSync(
      (ZipBuilder()
            ..add('mimetype', 'application/epub+zip'.codeUnits)
            ..add('META-INF/container.xml', container.codeUnits)
            ..add(
              'content.opf',
              '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
                      '<metadata><meta property="rendition:layout">pre-paginated</meta></metadata>'
                      '<manifest><item id="p" href="p.xhtml" media-type="application/xhtml+xml"/></manifest>'
                      '<spine><itemref idref="p"/></spine></package>'
                  .codeUnits,
            )
            ..add(
              'p.xhtml',
              '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>Page</p></body></html>'
                  .codeUnits,
            ))
          .build(),
    );
    book = Book(
      id: 'fixed-1',
      title: 'Fixed',
      filePath: path,
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 1),
    );
    books.seedBook(book);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: ReaderScreen(
          sourceId: book.id,
          bookRepository: books,
          highlightRepository: highlights,
          preferencesService: preferences,
          screenControlService: _ScreenControlService(),
          textActions: const [],
        ),
      ),
    );
    await tester.pump();
    await settle(tester, () => find.byType(ErrorState).evaluate().isNotEmpty);
    expect(find.byType(TextPagesView), findsNothing);
    await close(tester);
  });

  testWidgets('a swipe turns the page and persists the position', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(bloc(tester).state.chapterCurrentPage, 1);
    await tester.pump(const Duration(milliseconds: 700));
    final before = books.updatedBook?.currentCfi;
    await tester.fling(
      find.byType(TextPagesView),
      const Offset(-300, 0),
      1000,
    );
    await settle(tester, () => bloc(tester).state.chapterCurrentPage == 2);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, isNot(before));
    expect(books.updatedBook?.readingProgress, greaterThan(0));
    await close(tester);
  });

  for (final (animation, effect) in [
    (ReaderPageAnimation.slide, PageTurnAnimation.slide),
    (ReaderPageAnimation.cover, PageTurnAnimation.cover),
  ]) {
    testWidgets(
      'Arabic EPUB content sets RTL navigation despite Malay metadata: $animation',
      (tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        final path = '${tempDir.path}/mixed-language.epub';
        File(path).writeAsBytesSync(mixedLanguageArabicEpub());
        book = Book(
          id: 'mixed-language-epub',
          title: 'Mixed language fixture',
          filePath: path,
          format: BookFormat.epub,
          addedAt: DateTime(2026, 1, 1),
        );
        books.seedBook(book);
        await preferences.update(
          (prefs) => prefs.copyWith(readerPageAnimation: animation),
        );
        await pumpReader(tester);
        await tester.pumpAndSettle();
        final pages = find.byType(TextPagesView);
        final view = tester.widget<TextPagesView>(pages);
        final controller = view.controller;
        expect(view.pageTurnAnimation, effect);
        expect(
          controller.source.rtl,
          isFalse,
          reason: 'The EPUB omits its spine progression direction',
        );
        expect(controller.rtl, isTrue);
        expect(bloc(tester).state.pageProgressionRtl, isTrue);
        expect(
          Localizations.localeOf(tester.element(pages)).languageCode,
          'en',
        );
        expect(
          Directionality.of(tester.element(find.byType(ReaderScreen))),
          TextDirection.ltr,
        );
        expect(controller.position!.section, 0);
        expect(controller.position!.spread, 0);

        final viewport = tester.getRect(pages);
        await tester.tapAt(Offset(viewport.left + 24, viewport.center.dy));
        await settle(tester, () => controller.position!.section == 1);
        await tester.pumpAndSettle();
        expect(
          controller.position!.spread,
          0,
          reason: 'The left edge advances to the first Arabic chapter',
        );
        expect(bloc(tester).state.pageProgressionRtl, isTrue);

        await tester.tapAt(Offset(viewport.right - 24, viewport.center.dy));
        await settle(tester, () => controller.position!.section == 0);
        await tester.pumpAndSettle();
        expect(
          controller.position!.spread,
          0,
          reason: 'The right edge returns to the Malay introduction',
        );
        expect(
          controller.rtl,
          isTrue,
          reason: 'Book progression must not flip with chapter language',
        );

        await tester.fling(pages, const Offset(300, 0), 1000);
        await settle(tester, () => controller.position!.section == 1);
        await tester.pumpAndSettle();
        expect(
          controller.position!.spread,
          0,
          reason: 'A rightward horizontal swipe advances an RTL book',
        );
        expect(bloc(tester).state.pageProgressionRtl, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 700));
        await close(tester);
      },
    );
  }

  testWidgets(
    'global page animation switches live without relayout or lost selection',
    (
      tester,
    ) async {
      await preferences.update(
        (prefs) =>
            prefs.copyWith(readerPageAnimation: ReaderPageAnimation.slide),
      );
      await pumpReader(tester);
      final pages = find.byType(TextPagesView);
      final controller = tester.widget<TextPagesView>(pages).controller;
      expect(
        tester.widget<TextPagesView>(pages).pageTurnAnimation,
        PageTurnAnimation.slide,
      );
      await tester.runAsync(controller.next);
      await tester.pumpAndSettle();
      expect(controller.position!.spread, greaterThan(0));

      final page = find.byType(TextColumnPage).first;
      final pageWidget = tester.widget<TextColumnPage>(page);
      final paragraph = pageWidget.column.items
          .whereType<ColumnText>()
          .firstWhere(
            (item) =>
                item.rect.top >= pageWidget.page.top &&
                item.rect.bottom <= pageWidget.page.bottom,
          );
      final character = paragraph.paragraph.boxesFor(0, 1).first.toRect();
      final point =
          tester.getTopLeft(page) +
          paragraph.rect.topLeft -
          Offset(0, pageWidget.page.top) +
          character.center;
      await tester.longPressAt(point);
      await tester.pumpAndSettle();
      final selection = tester.element(pages).read<ReaderSelectionCubit>();
      expect(selection.state.hasSelection, isTrue);
      final range = selection.state.cfiRange;
      final cfi = controller.position!.cfi;
      final layout = controller.spreadAt(0)!.layout;
      final renderedPage = tester.renderObject(page);
      final appearance = tester.element(pages).read<ReaderAppearanceCubit>();

      void expectStablePage(PageTurnAnimation animation) {
        final view = tester.widget<TextPagesView>(pages);
        expect(view.pageTurnAnimation, animation);
        expect(view.controller, same(controller));
        expect(controller.spreadAt(0)!.layout, same(layout));
        expect(tester.renderObject(page), same(renderedPage));
        expect(controller.position!.cfi, cfi);
        expect(selection.state.cfiRange, range);
      }

      await preferences.update(
        (prefs) =>
            prefs.copyWith(readerPageAnimation: ReaderPageAnimation.cover),
      );
      await tester.pumpAndSettle();
      expectStablePage(PageTurnAnimation.cover);
      expect(preferences.readerAppearanceOverrideFor(book.id), isNull);

      await preferences.update(
        (prefs) =>
            prefs.copyWith(readerPageAnimation: ReaderPageAnimation.slide),
      );
      await tester.pumpAndSettle();
      expectStablePage(PageTurnAnimation.slide);
      await appearance.reset();
      await tester.pumpAndSettle();
      expectStablePage(PageTurnAnimation.slide);
      expect(
        preferences.current.readerPageAnimation,
        ReaderPageAnimation.slide,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await close(tester);
    },
  );

  testWidgets('reopens at the saved position and keeps it on close', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.fling(
      find.byType(TextPagesView),
      const Offset(-300, 0),
      1000,
    );
    await settle(tester, () => bloc(tester).state.chapterCurrentPage == 2);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    await close(tester);
    final saved = books.books.single;
    expect(saved.readingProgress, greaterThan(0));

    await pumpReader(tester);
    expect(bloc(tester).state.chapterCurrentPage, 2);
    await tester.pump(const Duration(milliseconds: 700));
    await close(tester);
    expect(books.books.single.currentCfi, saved.currentCfi);
    expect(books.books.single.readingProgress, saved.readingProgress);
  });

  testWidgets('the chrome bookmark button bookmarks the first word', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = l10n(tester);
    await tester.tap(await chromeControl(tester, strings.readerBookmark));
    await tester.pumpAndSettle();
    final saved = books.bookmarksBySourceId[book.id]!.single;
    expect(saved.anchorVersion, 2);
    expect(saved.cfi, contains(','), reason: 'a precise range');
    expect(saved.anchorExact, 'Chapter');
    expect(saved.content, startsWith('Chapter One'));
    expect(
      find.byTooltip(strings.readerRemoveBookmark).hitTestable(),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('the reader text size scales prose and headings', (
    tester,
  ) async {
    await pumpReader(tester);
    double sizeOf(String text) => tester
        .widget<TextColumnPage>(find.byType(TextColumnPage).first)
        .column
        .items
        .whereType<ColumnText>()
        .firstWhere((t) => t.paragraph.box.text.contains(text))
        .paragraph
        .box
        .runs
        .first
        .style
        .fontSize;
    final prose = sizeOf('Opening words');
    final heading = sizeOf('Chapter One');
    expect(heading, closeTo(prose * 1.8, 0.01), reason: 'h1 is 1.8 × prose');

    await preferences.update((p) => p.copyWith(readerTextScale: 1.25));
    await settle(tester, () => sizeOf('Opening words') != prose);
    expect(sizeOf('Opening words'), closeTo(prose * 1.25, 0.01));
    expect(sizeOf('Chapter One'), closeTo(heading * 1.25, 0.01));
    // The relaid page saves its position after a pause.
    await tester.pump(const Duration(seconds: 1));
    await close(tester);
  });

  testWidgets(
    'lines are WebKit\'s where the WebView reader was WebKit',
    (tester) async {
      await pumpReader(tester);
      final style = tester
          .widget<TextPagesView>(find.byType(TextPagesView))
          .controller
          .layout
          .style;
      final webKit = defaultTargetPlatform == TargetPlatform.iOS;
      expect(style.wholePixelLineHeights, webKit);
      expect(style.glyphLineBoxes, webKit);
      // The WebView reader's hyphenation limits were WebKit-only.
      expect(
        style.hyphenation,
        webKit
            ? const TextHyphenation(minBefore: 3, minAfter: 2, maxLines: 2)
            : const TextHyphenation(),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await close(tester);
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('the layout preset hyphenates prose, as foliate-js did', (
    tester,
  ) async {
    await pumpReader(tester);
    BookStyle style() => tester
        .widget<TextPagesView>(find.byType(TextPagesView))
        .controller
        .layout
        .style;
    expect(style().hyphenate, isFalse, reason: 'Standard does not');
    await preferences.update(
      (p) => p.copyWith(readerLayoutId: BookLayoutPreset.comfortable.id),
    );
    await settle(tester, () => style().hyphenate);
    expect(style().hyphenate, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await close(tester);
  });

  testWidgets('a long press selects a word with its sentence as context', (
    tester,
  ) async {
    await pumpReader(tester);
    final quick = offsetOf(tester, 'Hello there', 'quick');
    await tester.longPressAt(at(tester, 'Hello there', quick + 1));
    await tester.pumpAndSettle();
    final selection = tester
        .element(find.byType(TextPagesView))
        .read<ReaderSelectionCubit>()
        .state;
    expect(selection.hasSelection, isTrue);
    expect(selection.selectedText, 'quick');
    expect(
      selection.markedContextText,
      'The [[quick]] brown fox jumps over the lazy dog.',
    );
    expect(selection.cfiRange, startsWith('epubcfi(/6/'));
    expect(selection.position, isNotNull);
    expect(selection.chapterTitle, 'Chapter One');
    await close(tester);
  });

  testWidgets('an edge tap takes the selection to the next page; a tap '
      'in the middle clears it', (tester) async {
    await pumpReader(tester);
    final selections = tester
        .element(find.byType(TextPagesView))
        .read<ReaderSelectionCubit>();
    final quick = offsetOf(tester, 'Hello there', 'quick');
    await tester.longPressAt(at(tester, 'Hello there', quick + 1));
    await tester.pumpAndSettle();
    expect(selections.state.selectedText, 'quick');
    final start = selections.state.cfiRange!;

    await tester.tapAt(const Offset(370, 422));
    await settle(
      tester,
      () =>
          bloc(tester).state.chapterCurrentPage == 2 &&
          selections.state.selectedText != 'quick',
    );
    await tester.pumpAndSettle();
    final state = selections.state;
    expect(state.hasSelection, isTrue);
    expect(state.isAdjusting, isFalse);
    expect(state.selectedText, startsWith('quick brown fox'));
    expect(state.selectedText.length, greaterThan(100), reason: 'two pages');
    // The same start, a later end.
    // `epubcfi(parent,start,end)`: the parent is what both ends share.
    String startOf(String cfi) {
      final parts = cfi.substring('epubcfi('.length, cfi.length - 1).split(',');
      return parts[0] + parts[1];
    }

    expect(startOf(state.cfiRange!), startOf(start));
    expect(state.cfiRange, isNot(start));

    await tester.tapAt(const Offset(195, 600));
    await tester.pumpAndSettle();
    expect(selections.state.hasSelection, isFalse);
    expect(bloc(tester).state.chapterCurrentPage, 2);
    await close(tester);
  });

  testWidgets('links: a note opens over the page, a web link asks first', (
    tester,
  ) async {
    await pumpReader(tester);
    final web = offsetOf(tester, 'Opening words', 'web link');
    await tester.tapAt(at(tester, 'Opening words', web + 1));
    await tester.pumpAndSettle();
    // The link sheet names the host before anything opens.
    expect(find.textContaining('example.com'), findsWidgets);
    expect(externalLinks, isEmpty);
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();

    final note = offsetOf(tester, 'Opening words', 'note') + 'note'.length;
    await tester.tapAt(at(tester, 'Opening words', note));
    await settle(
      tester,
      () => find.byType(TextFragmentView).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    final fragment = find.descendant(
      of: find.byType(TextFragmentView),
      matching: find.byType(TextColumnPage),
    );
    final page = tester.widget<TextColumnPage>(fragment);
    expect(
      [
        for (final t in page.column.items.whereType<ColumnText>())
          t.paragraph.box.text,
      ],
      contains('The note text.'),
    );
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
