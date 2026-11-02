import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/pdf_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// PDF pages on pagecraft (pdfium) in the real app: denser than the screen
/// when trimmed, double-tap zoom that ends sharp, theme colors with margin
/// crops, search, a saved highlight and page previews.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF pages zoom sharp and follow the theme', (tester) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final book = await addPdfFixture(app);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${book.id}')));
    await waitForFixedPage(tester);

    final pages = find.byType(FixedPagesView);
    FixedPagesView view() => tester.widget<FixedPagesView>(pages);
    FixedPagePainter painter() =>
        tester
                .widget<CustomPaint>(
                  find
                      .byWidgetPredicate(
                        (w) =>
                            w is CustomPaint && w.painter is FixedPagePainter,
                      )
                      .first,
                )
                .painter!
            as FixedPagePainter;
    final bloc = tester.element(pages).read<ReaderBloc>();
    final l10n = tester.element(pages).l10n;

    Future<void> doubleTap() async {
      final centre = tester.getCenter(pages);
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 450));
    }

    // Defaults: margins trimmed, rendered denser than the screen so the
    // crop stays sharp.
    final screenWidth = tester.view.physicalSize.width;
    await waitForUi(
      tester,
      () => painter().visible.left > 0 && painter().image.width > screenWidth,
      description: 'trimmed page rendered denser than the screen',
    );
    expect(view().controller.page, 0);

    await doubleTap();
    await waitForUi(
      tester,
      () => view().controller.isZoomed && painter().tile != null,
      description: 'sharp tile',
    );
    expect(view().controller.page, 0, reason: 'zoom keeps the page');
    await _screenshot(binding, 'pdf-zoomed');

    await doubleTap();
    await waitForUi(
      tester,
      () => !view().controller.isZoomed && painter().tile == null,
      description: 'tile dropped at page fit',
    );

    // A dark theme recolours the trimmed page.
    await app.preferencesService.update(
      (p) => p.copyWith(readerThemeId: ReaderThemePreset.night.id),
    );
    await waitForUi(
      tester,
      () => view().pageColors != null && painter().visible.left > 0,
      description: 'dark theme and margin crop',
    );
    await _screenshot(binding, 'pdf-dark-cropped');

    // The real Appearance sheet turns both off for this book.
    tester.element(pages).read<ReaderUiCubit>().showChrome();
    await tester.pump(const Duration(milliseconds: 400));
    await tapUi(tester, find.byTooltip(l10n.readerAppearanceTitle));
    await tapUi(tester, find.text(l10n.readerPdfMarginsWhole));
    await tapUi(tester, find.text(l10n.readerPdfPageColorsOriginal));
    await waitForUi(
      tester,
      () =>
          view().visibleRectOf == null &&
          view().pageColors == null &&
          painter().visible.left == 0,
      description: 'whole page in original colors',
    );
    Navigator.of(tester.element(find.text(l10n.readerPdfMargins))).pop();
    await tester.pumpAndSettle();

    // Search finds the line on its page.
    tester.element(pages).read<ReaderUiCubit>().showChrome();
    await tester.pump(const Duration(milliseconds: 400));
    await tapUi(tester, find.byTooltip(l10n.readerSearchAction).first);
    await tester.enterText(
      find.byType(TextField).hitTestable(),
      'Line 7 of page 3:',
    );
    final search = tester
        .element(find.byType(TextField).hitTestable())
        .read<ReaderSearchCubit>();
    await waitForUi(
      tester,
      () => search.state.query.isNotEmpty && !search.state.isLoading,
      description: 'search completed',
      timeout: const Duration(seconds: 30),
    );
    expect(search.state.results, hasLength(1));
    await dismissSheet(tester);

    // A word on the page, saved as a highlight, is drawn on it. The chrome
    // that came back with the closed panel takes page input; hide it.
    tester.element(pages).read<ReaderUiCubit>().hideChrome();
    await tester.pump(const Duration(milliseconds: 400));
    // The page's centre can fall between two lines: press a little higher
    // or lower until a word is under the finger.
    final highlight = find.byTooltip('Highlight');
    for (final dy in const [0.0, -5.0, 5.0, -10.0, 10.0]) {
      await tester.longPressAt(tester.getCenter(pages) + Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 400));
      if (highlight.hitTestable().evaluate().isNotEmpty) break;
    }
    await _screenshot(binding, 'pdf-selection');
    await tapUi(tester, highlight);
    await waitForUi(
      tester,
      () => bloc.state.highlights.isNotEmpty,
      description: 'saved highlight',
    );
    await waitForUi(
      tester,
      () => find
          .byType(PdfTextOverlay)
          .evaluate()
          .any((e) => (e.widget as PdfTextOverlay).highlights.isNotEmpty),
      description: 'the highlight drawn on its page',
    );
    await _screenshot(binding, 'pdf-highlight');

    // Contents previews the pages at preview width.
    tester.element(pages).read<ReaderUiCubit>().openTocDrawer();
    await tester.pumpAndSettle();
    await tapUi(tester, find.text(l10n.readerPages));
    final grid = find.byType(ReaderPageGrid);
    final previews = find.descendant(of: grid, matching: find.byType(RawImage));
    await waitForUi(
      tester,
      () =>
          previews.evaluate().isNotEmpty &&
          previews.evaluate().every(
            (e) => (e.widget as RawImage).image != null,
          ),
      description: 'page previews',
      timeout: const Duration(seconds: 30),
    );
    final preview = tester.widget<RawImage>(previews.first).image!;
    expect(preview.width, lessThan(painter().image.width));
    await _screenshot(binding, 'pdf-previews');

    expect(tester.takeException(), isNull);
    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  if (Platform.isAndroid) {
    await captureAndroidScreenshot(name);
  } else {
    await binding.takeScreenshot(name);
  }
}
