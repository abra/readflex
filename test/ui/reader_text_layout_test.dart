import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:pagecraft/testing.dart' show preparePdfEngineForTests;

import '../support/pdf_fixture.dart';
import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// Reader text layout end to end: the window size and the Appearance
/// choices reach pagecraft's page settings and style as text columns, line
/// length and text size, and phones never change.
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
    await app.articleRepository.addExtractedArticle(ReadingFixture.article);
  });
  tearDown(() => app.dispose());

  /// Opens the fixture book from the Library at [window] and waits for
  /// its first page.
  Future<TextPagesController> open(
    WidgetTester tester, {
    Size window = phone,
  }) async {
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${app.book!.id}')));
    await waitForUi(
      tester,
      () => find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'the first page',
      timeout: const Duration(seconds: 30),
    );
    await tester.pumpAndSettle();
    return tester.widget<TextPagesView>(find.byType(TextPagesView)).controller;
  }

  /// Resizes the window and waits for the pages at the new size.
  Future<void> resize(
    WidgetTester tester,
    TextPagesController controller,
    Size window,
  ) async {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
    await waitForUi(
      tester,
      () =>
          controller.geometry?.viewport == window &&
          find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'pages at $window',
      timeout: const Duration(seconds: 30),
    );
    await tester.pumpAndSettle();
  }

  /// The reader's line measure for [controller]'s style: 32em of prose.
  double measure(TextPagesController controller, {double textScale = 1}) =>
      (32 * 16 * controller.layout.style.fontScale * textScale).roundToDouble();

  Future<void> leave(WidgetTester tester) async {
    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));
    await unmountUi(tester);
  }

  TextScrollController article(WidgetTester tester) =>
      tester.widget<TextScrollView>(find.byType(TextScrollView)).controller;

  /// Opens the article from the Library at [window]: it scrolls on
  /// pagecraft.
  Future<void> openArticle(WidgetTester tester, {Size window = phone}) async {
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.text(ReadingFixture.articleTitle));
    await waitForUi(
      tester,
      () =>
          find.byType(TextScrollView).evaluate().isNotEmpty &&
          article(tester).position != null,
      description: 'article laid out',
    );
  }

  /// Resizes the window under an article.
  Future<void> resizeArticle(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }

  /// Opens the reader's Appearance sheet over [page].
  Future<void> openAppearance(WidgetTester tester, Finder page) async {
    final readerContext = tester.element(page);
    readerContext.read<ReaderUiCubit>().showChrome();
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(readerContext.l10n.readerFontAction));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  }

  Future<void> closeSheetAndLeave(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    await leave(tester);
  }

  testWidgets('a book follows the window and the Columns choice', (
    tester,
  ) async {
    final controller = await open(tester);
    expect(controller.settings.maxColumnCount, 1, reason: 'phone');
    expect(controller.settings.measure, measure(controller));
    expect(controller.columns, 1);

    // A phone in landscape keeps one column at the measure.
    await resize(tester, controller, phoneLandscape);
    expect(controller.settings.maxColumnCount, 1);
    expect(controller.columns, 1);

    // A tablet: Auto, a spread in landscape, one column in portrait.
    await resize(tester, controller, tabletLandscape);
    expect(controller.settings.maxColumnCount, 0);
    expect(controller.settings.measure, measure(controller));
    expect(controller.columns, 2);
    await resize(tester, controller, tabletPortrait);
    expect(controller.columns, 1);

    // Two columns, chosen in Appearance.
    final readerContext = tester.element(find.byType(TextPagesView));
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
    await waitForUi(
      tester,
      () => controller.columns == 2,
      description: 'a spread in portrait',
      timeout: const Duration(seconds: 30),
    );
    expect(controller.settings.maxColumnCount, 2);
    expect(
      app.preferencesService.readerAppearanceOverrideFor(app.book!.id)?.columns,
      ReaderColumns.two,
    );
    Navigator.of(tester.element(control)).pop();
    await tester.pumpAndSettle();

    // A narrow window ignores the tablet choice.
    await resize(tester, controller, phoneLandscape);
    expect(controller.columns, 1);
    await leave(tester);
  });

  testWidgets('book pages keep clear of the window side insets', (
    tester,
  ) async {
    // iPhone 17 Pro in landscape: 62pt on both sides.
    tester.view.padding = const FakeViewPadding(
      left: 62,
      right: 62,
      bottom: 21,
    );
    addTearDown(tester.view.resetPadding);
    final controller = await open(tester, window: const Size(874, 402));
    expect(controller.settings.safeInlineInset, 62);

    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    await resize(tester, controller, phone);
    expect(controller.settings.safeInlineInset, 0);
    await leave(tester);
  });

  testWidgets('an article keeps one column at the measure in every window', (
    tester,
  ) async {
    await openArticle(tester);
    // One column the page's width less its margins, never wider than
    // 32 em of prose.
    final measure = article(tester).settings.measure!;
    expect(measure, greaterThan(32 * 16.0 - 1), reason: '32 em of prose');
    expect(article(tester).layout.columnWidth, lessThan(measure));
    await resizeArticle(tester, phoneLandscape);
    await waitForUi(
      tester,
      () => article(tester).layout.columnWidth == measure,
      description: 'landscape column at the measure',
    );

    await resizeArticle(tester, tabletLandscape);
    await waitForUi(
      tester,
      () =>
          article(tester).layout.columnWidth ==
          article(tester).settings.measure,
      description: 'tablet column at the measure',
    );

    await openAppearance(tester, find.byType(TextScrollView));
    expect(find.byKey(const ValueKey('reader-columns-control')), findsNothing);
    await closeSheetAndLeave(tester);
  });

  testWidgets('article text keeps clear of the side insets and the system '
      'bars', (tester) async {
    tester.view.padding = const FakeViewPadding(
      left: 62,
      right: 62,
      bottom: 21,
    );
    addTearDown(tester.view.resetPadding);
    await openArticle(tester, window: const Size(874, 402));
    expect(article(tester).settings.safeInlineInset, 62);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    await resizeArticle(tester, phone);
    await waitForUi(
      tester,
      () => article(tester).settings.safeInlineInset == 0,
      description: 'portrait insets',
    );
    // Its margins sit below the status bar and above the home indicator.
    expect(article(tester).topInset, 32 + 62);
    expect(article(tester).bottomInset, 40 + 34);
    // The relaid article saves its position after a pause.
    await tester.pump(const Duration(seconds: 2));
    await unmountUi(tester);
  });

  testWidgets('PDF pages keep their layout and offer no columns', (
    tester,
  ) async {
    await tester.runAsync(preparePdfEngineForTests);
    final pdf = (await tester.runAsync(() => addPdfFixture(app)))!;
    tester.view
      ..physicalSize = tabletLandscape
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${pdf.id}')));
    await waitForUi(
      tester,
      () => find.byType(FixedPagesView).evaluate().isNotEmpty,
      description: 'the PDF pages',
      timeout: const Duration(seconds: 30),
    );
    await waitForFixedPage(tester);
    await tester.pumpAndSettle();
    expect(find.byType(TextPagesView), findsNothing);

    final readerContext = tester.element(find.byType(FixedPagesView));
    readerContext.read<ReaderUiCubit>().showChrome();
    await tester.pumpAndSettle();
    await tapUi(
      tester,
      find.byTooltip(readerContext.l10n.readerAppearanceTitle),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-columns-control')), findsNothing);
    await closeSheetAndLeave(tester);
  });

  group('text size', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets(
      'book text is 12.5% larger in a tablet-sized window',
      (tester) async {
        final controller = await open(tester);
        final phoneScale = controller.layout.style.fontScale;

        await resize(tester, controller, tabletPortrait);
        expect(
          controller.layout.style.fontScale,
          closeTo(phoneScale * 1.125, 1e-9),
        );
        // Narrow windows read like a phone.
        await resize(tester, controller, splitViewThird);
        expect(controller.layout.style.fontScale, closeTo(phoneScale, 1e-9));
        await resize(tester, controller, phoneLandscape);
        expect(controller.layout.style.fontScale, closeTo(phoneScale, 1e-9));
        // The multiplier is the renderer's: the reader's own size stays 100%.
        expect(app.preferencesService.current.readerTextScale, 1.0);
        await leave(tester);
      },
      variant: ios,
    );

    testWidgets(
      'the reader size applies to prose on top of the tablet size',
      (tester) async {
        await app.preferencesService.update(
          (p) => p.copyWith(readerTextScale: 1.2),
        );
        final controller = await open(tester, window: tabletPortrait);
        final style = controller.layout.style;
        final prose = 16 * style.fontScale * 1.2;
        expect(
          style.readerStyleSheet,
          contains('font-size: ${prose.toStringAsFixed(2)}px !important'),
        );
        expect(
          controller.settings.measure,
          measure(controller, textScale: 1.2),
        );
        await leave(tester);
      },
      variant: ios,
    );

    testWidgets(
      'article text is larger in a tablet-sized window',
      (tester) async {
        await openArticle(tester);
        double scale() => article(tester).layout.style.fontScale;
        final phoneScale = scale();

        await resizeArticle(tester, tabletLandscape);
        await waitForUi(
          tester,
          () => scale() == phoneScale * 1.125,
          description: 'tablet text size',
        );
        await resizeArticle(tester, tabletPortrait);
        expect(scale(), phoneScale * 1.125);
        await tester.pump(const Duration(seconds: 2));
        await unmountUi(tester);
      },
      variant: ios,
    );
  });
}
