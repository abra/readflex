import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:vellum/testing.dart';
import 'package:vellum/vellum.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  late Directory tempDir;
  late PreferencesService preferences;
  late FakeBookRepository books;
  late FakeHighlightRepository highlights;
  late Book comic;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    // Widget tests run in a fake async zone where real file I/O never
    // completes; the fixture is written synchronously.
    tempDir = Directory.systemTemp.createTempSync('reader_comic_');
    final path = '${tempDir.path}/issue.cbz';
    File(path).writeAsBytesSync(buildComicArchive(portraitPages(5)));
    books = FakeBookRepository();
    highlights = FakeHighlightRepository();
    comic = Book(
      id: 'comic-1',
      title: 'Issue 1',
      filePath: path,
      format: BookFormat.cbz,
      addedAt: DateTime(2026, 1, 1),
      comicPageOrderVersion: 1,
    );
    books.seedBook(comic);
  });

  tearDown(() {
    preferences.dispose();
    tempDir.deleteSync(recursive: true);
  });

  /// Lets the archive open and the visible page decode. Both are chains of
  /// real I/O: each step completes on the real event loop and continues on
  /// the next pump, so the two alternate until the page is on screen.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        final frames = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is FixedPagePainter,
        );
        if (frames.evaluate().isNotEmpty) break;
      }
    });
    await tester.pump();
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
          sourceId: comic.id,
          serverBaseUri: Uri.parse('http://127.0.0.1:8080'),
          bookRepository: books,
          highlightRepository: highlights,
          preferencesService: preferences,
          screenControlService: _ScreenControlService(),
          textActions: const [],
          nativeFormats: const {BookFormat.cbz},
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  ReadflexLocalizations l10n(WidgetTester tester) =>
      tester.element(find.byType(FixedPagesView)).l10n;

  /// Shows the chrome when it is hidden (a centre tap, after the
  /// double-tap window) and returns the tappable control with [tooltip].
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

  testWidgets('opens a comic on the native engine, without a WebView', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(FixedPagesView), findsOneWidget);
    expect(find.byType(BookReaderWebView), findsNothing);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(1)),
      findsOneWidget,
    );

    // The opening position is reported and persisted as the WebView's would be.
    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, 'epubcfi(/6/2)');
    expect(books.updatedBook?.readingProgress, closeTo(0.2, 1e-9));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a swipe turns the page and persists the new position', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(2)),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, 'epubcfi(/6/4)');
    expect(books.updatedBook?.readingProgress, closeTo(0.4, 1e-9));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the vertical page turn swipes pages up and down', (
    tester,
  ) async {
    await pumpReader(tester);
    final element = tester.element(find.byType(FixedPagesView));
    await element.read<ReaderAppearanceCubit>().setPageTurnStyle(
      ReaderPageTurnStyle.vertical,
    );
    await tester.pump();
    await tester.pump();
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(1)),
      findsOneWidget,
      reason: 'a sideways swipe does nothing',
    );
    await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(2)),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the chrome bookmark button bookmarks the page on screen', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = l10n(tester);
    await tester.tap(await chromeControl(tester, strings.readerBookmark));
    await tester.pumpAndSettle();

    final saved = books.bookmarksBySourceId[comic.id]!.single;
    expect(saved.cfi, 'epubcfi(/6/2)');
    expect(saved.anchorSectionIndex, 0);
    expect(saved.anchorSectionPage, 0);
    expect(saved.content, 'Page 1 / 5');
    expect(saved.progress, closeTo(0.2, 1e-9));
    // The page's bookmark state reaches the chrome through the position.
    expect(
      find.byTooltip(strings.readerRemoveBookmark).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(
      find.byTooltip(strings.readerRemoveBookmark).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(books.bookmarksBySourceId[comic.id], isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a long press starts an image-area selection with controls', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.longPressAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final selection = tester
        .element(find.byType(FixedPagesView))
        .read<ReaderImageSelectionCubit>()
        .state;
    expect(selection.hasSelection, isTrue);
    expect(selection.pageIndex, 0);
    expect(
      selection.rect!.width,
      closeTo(ComicImageAreaGeometry.defaultWidth, 1e-6),
    );
    expect(selection.position, isNotNull);
    expect(find.byType(ReaderHighlightControls), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a tap outside the draft cancels it without turning the page', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.longPressAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ReaderHighlightControls), findsOneWidget);

    // In the left edge zone, where a plain tap turns back a page.
    await tester.tapAt(const Offset(30, 700));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(FixedPagesView));
    expect(
      element.read<ReaderImageSelectionCubit>().state.hasSelection,
      isFalse,
    );
    expect(find.byType(ReaderHighlightControls), findsNothing);
    expect(
      tester
          .widget<FixedPagesView>(find.byType(FixedPagesView))
          .controller
          .page,
      0,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Contents shows the page grid with engine previews', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = l10n(tester);
    await tester.tap(await chromeControl(tester, strings.readerContents));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPageGrid), findsOneWidget);
    await settle(tester);
    expect(find.byType(RawImage), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
