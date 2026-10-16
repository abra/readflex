import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/pdf_fixture.dart';
import '../support/reader_test_platform.dart';
import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// Reader text layout end to end: the window size and the Appearance choice
/// reach the WebView style as text columns, line length and text size, and
/// phones never change.
void main() {
  const phone = Size(390, 844);
  const phoneLandscape = Size(844, 390);
  const tabletLandscape = Size(1376, 1032);
  const tabletPortrait = Size(1032, 1376);
  // A one-third Split View on iPad Pro 13".
  const splitViewThird = Size(375, 1032);

  late UiTestApp app;
  setUp(() async {
    app = await UiTestApp.create();
    await app.readerServer.start();
    await app.articleRepository.addExtractedArticle(ReadingFixture.article);
  });
  tearDown(() => app.dispose());

  /// Opens a source from the Library at [window], finishes its load and
  /// returns the scripts the WebView receives.
  Future<List<String>> open(
    WidgetTester tester,
    Finder source, {
    Size window = phone,
  }) async {
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = InAppWebViewPlatform.instance;
    final platform = ReaderTestPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
    await tester.pumpWidget(app.widget);
    await tapUi(tester, source);
    await waitForUi(
      tester,
      () =>
          platform.views.isNotEmpty &&
          platform.views.single.controller.handlers.containsKey('onLoadEnd'),
      description: 'reader platform mounted',
    );
    final bridge = platform.views.single.controller;
    bridge.handlers['onLoadEnd']!([]);
    await tester.pumpAndSettle();
    return bridge.scripts;
  }

  Future<void> resize(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }

  ({int columns, double? lineEm}) bookStyle(WidgetTester tester) {
    final style = tester
        .widget<BookReaderWebView>(find.byType(BookReaderWebView))
        .foliateStyle;
    return (columns: style.maxColumnCount, lineEm: style.maxLineWidthEm);
  }

  FoliateStyle articleStyle(WidgetTester tester) => tester
      .widget<ArticleHtmlReaderWebView>(find.byType(ArticleHtmlReaderWebView))
      .foliateStyle;

  Future<void> closeSheetAndUnmount(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    await unmountUi(tester);
  }

  Iterable<String> styleScripts(List<String> scripts) =>
      scripts.where((script) => script.contains('changeStyle'));

  testWidgets('a book follows the window and the Columns choice', (
    tester,
  ) async {
    final scripts = await open(
      tester,
      find.byKey(ValueKey('library-grid-${app.book!.id}')),
    );
    expect(bookStyle(tester), (columns: 1, lineEm: null), reason: 'phone');

    scripts.clear();
    await resize(tester, tabletLandscape);
    expect(bookStyle(tester), (columns: 0, lineEm: 32.0));
    expect(
      styleScripts(scripts).where(
        (script) =>
            script.contains('"maxColumnCount":0') &&
            script.contains('"maxLineWidthEm":32'),
      ),
      isNotEmpty,
      reason: 'the WebView receives the wide style',
    );

    // Rotation keeps the same style; foliate re-lays the page itself.
    scripts.clear();
    await resize(tester, tabletPortrait);
    expect(bookStyle(tester), (columns: 0, lineEm: 32.0));
    expect(styleScripts(scripts), isEmpty);

    final readerContext = tester.element(find.byType(BookReaderWebView));
    final l10n = readerContext.l10n;
    readerContext.read<ReaderUiCubit>().showChrome();
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.readerFontAction));
    final control = find.byKey(const ValueKey('reader-columns-control'));
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tapUi(
      tester,
      find.descendant(of: control, matching: find.text(l10n.readerColumnsTwo)),
    );
    expect(bookStyle(tester), (columns: 2, lineEm: 32.0));
    expect(
      app.preferencesService.readerAppearanceOverrideFor(app.book!.id)?.columns,
      ReaderColumns.two,
    );
    Navigator.of(tester.element(control)).pop();
    await tester.pumpAndSettle();

    // A narrow window ignores the tablet choice.
    await resize(tester, phoneLandscape);
    expect(bookStyle(tester), (columns: 1, lineEm: null));
    await resize(tester, tabletLandscape);
    expect(bookStyle(tester), (columns: 2, lineEm: 32.0));
    await unmountUi(tester);
  });

  testWidgets('an article keeps one column at the measure in a wide window', (
    tester,
  ) async {
    await open(tester, find.text(ReadingFixture.articleTitle));
    FoliateStyle style() => articleStyle(tester);
    expect(style().maxLineWidthEm, isNull);

    await resize(tester, tabletLandscape);
    expect(style().maxColumnCount, 1);
    expect(style().maxLineWidthEm, 32);

    final readerContext = tester.element(find.byType(ArticleHtmlReaderWebView));
    readerContext.read<ReaderUiCubit>().showChrome();
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(readerContext.l10n.readerFontAction));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-columns-control')), findsNothing);
    await closeSheetAndUnmount(tester);
  });

  testWidgets('book and article text get the window side insets', (
    tester,
  ) async {
    FoliateStyle bookStyle() => tester
        .widget<BookReaderWebView>(find.byType(BookReaderWebView))
        .foliateStyle;
    // iPhone 17 Pro in landscape: the cutout side and the opposite side both
    // report 62pt.
    const cutout = FakeViewPadding(left: 62, right: 62, bottom: 21);
    for (final (source, style) in [
      (find.byKey(ValueKey('library-grid-${app.book!.id}')), bookStyle),
      (find.text(ReadingFixture.articleTitle), () => articleStyle(tester)),
    ]) {
      tester.view.padding = cutout;
      addTearDown(tester.view.resetPadding);
      await open(tester, source, window: const Size(874, 402));
      expect((style().safeAreaLeft, style().safeAreaRight), (62.0, 62.0));

      // Back in portrait the sides are free again.
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      await resize(tester, phone);
      expect((style().safeAreaLeft, style().safeAreaRight), (0.0, 0.0));
      await unmountUi(tester);
    }
  });

  group('text size', () {
    // iOS renders the reader's 100% as 16px; Android adds its own WebView
    // correction, covered by the readerDeviceFontScale unit tests.
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    FoliateStyle bookFoliateStyle(WidgetTester tester) => tester
        .widget<BookReaderWebView>(find.byType(BookReaderWebView))
        .foliateStyle;

    testWidgets(
      'book text is 12.5% larger in a tablet-sized window',
      (tester) async {
        final scripts = await open(
          tester,
          find.byKey(ValueKey('library-grid-${app.book!.id}')),
        );
        expect(bookFoliateStyle(tester).fontSize, 1.0, reason: 'phone');

        scripts.clear();
        await resize(tester, tabletPortrait);
        expect(bookFoliateStyle(tester).fontSize, 1.125);
        expect(
          styleScripts(scripts).where(
            (script) => script.contains('"fontSize":1.125'),
          ),
          isNotEmpty,
          reason: 'the WebView receives the tablet size',
        );

        // Rotation keeps the size, so the page is not restyled.
        scripts.clear();
        await resize(tester, tabletLandscape);
        expect(bookFoliateStyle(tester).fontSize, 1.125);
        expect(styleScripts(scripts), isEmpty);

        // Narrow windows read like a phone.
        await resize(tester, splitViewThird);
        expect(bookFoliateStyle(tester).fontSize, 1.0);
        await resize(tester, phoneLandscape);
        expect(bookFoliateStyle(tester).fontSize, 1.0);

        // The multiplier is the renderer's: the reader's own size stays 100%.
        expect(bookFoliateStyle(tester).textScale, 1.0);
        expect(app.preferencesService.current.readerTextScale, 1.0);
        await unmountUi(tester);
      },
      variant: ios,
    );

    testWidgets(
      'the reader size applies on top of the tablet size',
      (tester) async {
        await app.preferencesService.update(
          (p) => p.copyWith(readerTextScale: 1.2),
        );
        await open(
          tester,
          find.byKey(ValueKey('library-grid-${app.book!.id}')),
          window: tabletPortrait,
        );
        expect(bookFoliateStyle(tester).fontSize, 1.125);
        expect(bookFoliateStyle(tester).textScale, 1.2);
        await unmountUi(tester);
      },
      variant: ios,
    );

    testWidgets(
      'article text is larger in a tablet-sized window',
      (tester) async {
        await open(tester, find.text(ReadingFixture.articleTitle));
        expect(articleStyle(tester).fontSize, 1.0);

        await resize(tester, tabletLandscape);
        expect(articleStyle(tester).fontSize, 1.125);
        await resize(tester, tabletPortrait);
        expect(articleStyle(tester).fontSize, 1.125);
        await unmountUi(tester);
      },
      variant: ios,
    );
  });

  testWidgets('PDF pages keep their layout and offer no columns', (
    tester,
  ) async {
    final pdf = (await tester.runAsync(() => addPdfFixture(app)))!;
    await open(
      tester,
      find.byKey(ValueKey('library-grid-${pdf.id}')),
      window: tabletLandscape,
    );
    expect(bookStyle(tester), (columns: 1, lineEm: null));

    final readerContext = tester.element(find.byType(BookReaderWebView));
    readerContext.read<ReaderUiCubit>().showChrome();
    await tester.pumpAndSettle();
    await tapUi(
      tester,
      find.byTooltip(readerContext.l10n.readerAppearanceTitle),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-columns-control')), findsNothing);
    await closeSheetAndUnmount(tester);
  });
}
