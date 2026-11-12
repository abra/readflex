import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:native_text_selection/native_text_selection.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart';

import '../packages/pagecraft/test/fixtures/pdf/unembedded_cyrillic_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/pdf_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// PDF pages on pagecraft (pdfium) in the real app: denser than the screen
/// when trimmed, double-tap zoom that ends sharp, theme colors with margin
/// crops, search, Flutter fallback handles, a saved highlight and page previews.
/// Native activation is covered separately by native_selection_controls_test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF pages zoom sharp and follow the theme', (tester) async {
    _useFlutterSelectionFallback(tester);
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final book = await addPdfFixture(app);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            (widget is LibraryContinueReadingCard &&
                widget.source.id == book.id) ||
            widget.key == ValueKey('library-grid-${book.id}') ||
            widget.key == ValueKey('library-row-${book.id}'),
      ),
    );
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
    final doubleTaps = <Map<String, Object>>[];
    (binding.reportData ??= {})['pdfDoubleTaps'] = doubleTaps;

    Future<void> doubleTap() async {
      final centre = tester.getCenter(pages);
      final scaleBefore = view().controller.zoomScale;
      final elapsed = Stopwatch()..start();
      await tester.tapAt(centre);
      // A live frame can exceed the double-tap window on a slow emulator.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      final interTapMs = elapsed.elapsedMilliseconds;
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 450));
      doubleTaps.add({
        'interTapMs': interTapMs,
        'scaleBefore': scaleBefore,
        'scaleAfter': view().controller.zoomScale,
        'chromeVisible': tester
            .element(pages)
            .read<ReaderUiCubit>()
            .state
            .chromeVisible,
      });
    }

    // Each page follows its painted physical size, including in a spread;
    // the full-page bitmap remains bounded by the renderer's pixel budget.
    await waitForUi(
      tester,
      () {
        final page = painter();
        final physicalWidth =
            page.imageRect.width * tester.view.devicePixelRatio;
        final expectedWidth = boundedPdfRenderWidth(
          physicalWidth.ceil(),
          page.image.width / page.image.height,
        );
        return page.visible.left > 0 && page.image.width >= expectedWidth - 2;
      },
      description: 'trimmed page raster matches its painted physical size',
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

    // Selection must preserve the light PDF glyphs over the themed dark page.
    await waitForUi(
      tester,
      () => _visibleWord(tester, pages, minimumFollowingCharacters: 4) != null,
      description: 'selectable text on the dark PDF page',
    );
    final darkTarget = _visibleWord(
      tester,
      pages,
      minimumFollowingCharacters: 4,
    )!;
    await tester.longPressAt(darkTarget.point);
    await waitForUi(
      tester,
      () => find.byTooltip('Highlight').hitTestable().evaluate().isNotEmpty,
      description: 'dark PDF selection action',
    );
    expect(darkTarget.overlay.darkPage, isTrue);
    expect(darkTarget.overlay.selection.range, darkTarget.range);
    await _screenshot(binding, 'pdf-dark-selection');
    await _moveSelectionBoundary(
      tester,
      binding,
      darkTarget,
      initialRange: darkTarget.range,
      characterDelta: 4,
      screenshot: 'pdf-dark-selection-adjusting',
    );
    darkTarget.overlay.selection.clear();
    darkTarget.overlay.controller.lockInput(false);
    tester.element(pages).read<ReaderSelectionCubit>().deselect();
    await tester.pumpAndSettle();

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
      find.byType(AppTextField).hitTestable(),
      'Line 7 of page 3:',
    );
    final search = tester
        .element(find.byType(AppTextField).hitTestable())
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
    await waitForUi(
      tester,
      () => _visibleWord(tester, pages, minimumFollowingCharacters: 4) != null,
      description: 'selectable text on the current PDF page',
    );
    // A landscape spread's viewport centre can be its gutter. Press a glyph
    // from the actual page text layer, transformed into screen coordinates.
    final target = _visibleWord(
      tester,
      pages,
      minimumFollowingCharacters: 4,
    )!;
    final highlight = find.byTooltip('Highlight');
    await tester.longPressAt(target.point);
    await waitForUi(
      tester,
      () => highlight.hitTestable().evaluate().isNotEmpty,
      description: 'PDF text selection action',
    );
    expect(target.overlay.selection.page, target.overlay.page);
    expect(target.overlay.selection.range, target.range);
    await _screenshot(binding, 'pdf-selection');

    // Grip the handle below the glyphs and move horizontally: this used to
    // hit-test below the text line and leave the boundary stuck in place.
    final extended = await _moveSelectionBoundary(
      tester,
      binding,
      target,
      initialRange: target.range,
      characterDelta: 4,
      screenshot: 'pdf-selection-adjusting',
    );
    final adjusted = await _moveSelectionBoundary(
      tester,
      binding,
      target,
      initialRange: extended,
      startHandle: true,
      characterDelta: 1,
      screenshot: 'pdf-selection-start-adjusting',
    );
    final selectionCubit = tester.element(pages).read<ReaderSelectionCubit>();
    expect(
      selectionCubit.state.selectedText,
      target.overlay.layer!.textOf(adjusted),
    );
    expect(
      selectionCubit.state.cfiRange,
      pdfTextCfi(target.overlay.page, adjusted),
    );
    await _screenshot(binding, 'pdf-selection-adjusted');

    // Repeat while the page is enlarged; target size and drag distance are
    // screen-space values, independent of the PDF's fitted scale.
    target.overlay.selection.clear();
    target.overlay.controller.lockInput(false);
    selectionCubit.deselect();
    await tester.pumpAndSettle();
    await doubleTap();
    await waitForUi(
      tester,
      () => view().controller.isZoomed && painter().tile != null,
      description: 'zoomed PDF before selection adjustment',
    );
    final zoomed = _visibleWord(
      tester,
      pages,
      minimumFollowingCharacters: 4,
    )!;
    await tester.longPressAt(zoomed.point);
    await waitForUi(
      tester,
      () => highlight.hitTestable().evaluate().isNotEmpty,
      description: 'zoomed PDF selection action',
    );
    final zoomedRange = await _moveSelectionBoundary(
      tester,
      binding,
      zoomed,
      initialRange: zoomed.range,
      characterDelta: 4,
      screenshot: 'pdf-selection-zoomed-adjusting',
    );
    expect(
      selectionCubit.state.selectedText,
      zoomed.overlay.layer!.textOf(zoomedRange),
    );
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

  testWidgets('Cyrillic OCR selection covers the visible raster text', (
    tester,
  ) async {
    _useFlutterSelectionFallback(tester);
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    await app.preferencesService.update(
      (preferences) => preferences.copyWith(readerTrimPageMargins: false),
    );
    final book = (await tester.runAsync(() async {
      final file = File('${app.directory.path}/original-cyrillic.pdf');
      await file.writeAsBytes(unembeddedCyrillicFixtureBytes());
      return importBookFile(
        sourceFile: file,
        bookRepository: app.bookRepository,
        logger: app.logger,
      );
    }))!;
    expect(book.format, BookFormat.pdf);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            (widget is LibraryContinueReadingCard &&
                widget.source.id == book.id) ||
            widget.key == ValueKey('library-grid-${book.id}') ||
            widget.key == ValueKey('library-row-${book.id}'),
      ),
    );
    await waitForFixedPage(tester);
    final pages = find.byType(FixedPagesView);
    final context = tester.element(pages);
    final bloc = context.read<ReaderBloc>();
    final selection = context.read<ReaderSelectionCubit>();
    context.read<ReaderUiCubit>().hideChrome();
    await tester.pump(const Duration(milliseconds: 400));
    await waitForUi(
      tester,
      () => find
          .byType(PdfTextOverlay)
          .evaluate()
          .any(
            (element) =>
                (element.widget as PdfTextOverlay).page == 0 &&
                (element.widget as PdfTextOverlay).layer?.text.startsWith(
                      'Проверка',
                    ) ==
                    true,
          ),
      description: 'unembedded Cyrillic text cells',
    );
    final element = find
        .byType(PdfTextOverlay)
        .evaluate()
        .firstWhere(
          (element) => (element.widget as PdfTextOverlay).page == 0,
        );
    final overlay = element.widget as PdfTextOverlay;
    final layer = overlay.layer!;
    final render = element.renderObject! as RenderBox;
    final scale = overlay.imageRect.width / overlay.pageWidth;
    Offset toGlobal(Offset point) => render.localToGlobal(
      overlay.imageRect.topLeft + point * scale,
    );
    final cell = layer.charBoxes[2];
    expect(cell.height, greaterThan(9));
    await tester.longPressAt(
      toGlobal(
        Offset((cell.left + cell.right) / 2, (cell.top + cell.bottom) / 2),
      ),
    );
    await waitForUi(
      tester,
      () => selection.state.selectedText == 'Проверка',
      description: 'visible Cyrillic word selected',
    );
    expect(overlay.selection.range, const PdfTextRange(0, 8));
    await _screenshot(binding, 'pdf-cyrillic-word-selection');

    final handle = find.byKey(const ValueKey('pdf-selection-end-handle-0'));
    expect(handle.hitTestable(), findsOneWidget);
    expect(tester.getSize(handle), const Size(48, 48));
    final from = layer.caretAt(8, upstream: true)!.box;
    final until = layer.caretAt(layer.text.length, upstream: true)!.box;
    final start = tester.getCenter(handle);
    final delta =
        toGlobal(Offset(until.left, (until.top + until.bottom) / 2)) -
        toGlobal(Offset(from.left, (from.top + from.bottom) / 2));
    final gesture = await tester.startGesture(start);
    try {
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump();
      await gesture.moveTo(start + delta);
      await tester.pump(const Duration(milliseconds: 150));
      expect(overlay.selection.range, PdfTextRange(0, layer.text.length));
      expect(selection.state.isAdjusting, isTrue);
      expect(find.byType(RawMagnifier), findsOneWidget);
      await _screenshot(binding, 'pdf-cyrillic-multiline-adjusting');
    } finally {
      await gesture.up();
    }
    await tester.pumpAndSettle();
    await waitForUi(
      tester,
      () => selection.state.selectedText == layer.text,
      description: 'multiline Cyrillic range reported',
    );
    expect(
      selection.state.cfiRange,
      pdfTextCfi(0, PdfTextRange(0, layer.text.length)),
    );
    expect(selection.state.isAdjusting, isFalse);
    expect(
      layer.boxesOf(overlay.selection.range!).every((box) => box.height > 9),
      isTrue,
    );
    await _screenshot(binding, 'pdf-cyrillic-multiline-selection');
    await tapUi(tester, find.byTooltip('Highlight'));
    await waitForUi(
      tester,
      () => bloc.state.highlights.isNotEmpty,
      description: 'Cyrillic highlight saved',
    );
    expect(bloc.state.highlights.single.text, layer.text);
    await _screenshot(binding, 'pdf-cyrillic-saved-highlight');
    (binding.reportData ??= {})['pdfCyrillicSelection'] = {
      'fixtureSha256': unembeddedCyrillicFixtureSha256,
      'text': layer.text,
      'cellHeight': cell.height,
      'selectedLineHeights': [
        for (final box in layer.boxesOf(PdfTextRange(0, layer.text.length)))
          box.height,
      ],
      'cfi': pdfTextCfi(0, PdfTextRange(0, layer.text.length)),
    };
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _useFlutterSelectionFallback(WidgetTester tester) {
  const channel = MethodChannel(
    'io.github.abra.native_text_selection/capabilities',
  );
  // These tests drag Flutter's 48dp grips and assert its magnifier. A ready
  // native view owns different controls; it has its own integration coverage.
  final messenger = tester.binding.defaultBinaryMessenger;
  NativeSelectionPlatform.resetAvailability();
  messenger.setMockMethodCallHandler(channel, (_) async => false);
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    NativeSelectionPlatform.resetAvailability();
  });
}

({Offset point, PdfTextOverlay overlay, PdfTextRange range})? _visibleWord(
  WidgetTester tester,
  Finder pages, {
  int minimumFollowingCharacters = 0,
}) {
  final viewport = tester.getRect(pages).deflate(24);
  final wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);
  ({Offset point, PdfTextOverlay overlay, PdfTextRange range})? nearest;
  var distance = double.infinity;
  for (final element in find.byType(PdfTextOverlay).evaluate()) {
    final overlay = element.widget as PdfTextOverlay;
    final layer = overlay.layer;
    if (!overlay.enabled ||
        layer == null ||
        overlay.page != overlay.controller.page) {
      continue;
    }
    final render = element.renderObject! as RenderBox;
    if (!render.hasSize) continue;
    final scale = overlay.imageRect.width / overlay.pageWidth;
    for (var index = 0; index < layer.text.length; index++) {
      final box = layer.charBoxes[index];
      if (box.isEmpty || !wordCharacter.hasMatch(layer.text[index])) continue;
      final range = layer.wordAt(index);
      if (range == null) continue;
      if (minimumFollowingCharacters > 0) {
        if (range.length < 2) continue;
        final line = layer.lines.where(
          (line) =>
              line.range.start <= range.start &&
              range.end + minimumFollowingCharacters <= line.range.end,
        );
        if (line.isEmpty ||
            layer
                .charBoxes[range.end + minimumFollowingCharacters - 1]
                .isEmpty) {
          continue;
        }
      }
      final local =
          overlay.imageRect.topLeft +
          Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2) *
              scale;
      final point = render.localToGlobal(local);
      if (!viewport.contains(point)) continue;
      final candidateDistance = (point - viewport.center).distanceSquared;
      if (candidateDistance < distance) {
        distance = candidateDistance;
        nearest = (point: point, overlay: overlay, range: range);
      }
    }
  }
  return nearest;
}

Future<PdfTextRange> _moveSelectionBoundary(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  ({Offset point, PdfTextOverlay overlay, PdfTextRange range}) target, {
  required PdfTextRange initialRange,
  required int characterDelta,
  bool startHandle = false,
  required String screenshot,
}) async {
  final overlay = target.overlay;
  final layer = overlay.layer!;
  final initialOffset = startHandle ? initialRange.start : initialRange.end;
  final nextOffset = initialOffset + characterDelta;
  final expected = startHandle
      ? PdfTextRange(nextOffset, initialRange.end)
      : PdfTextRange(initialRange.start, nextOffset);
  final element = find
      .byType(PdfTextOverlay)
      .evaluate()
      .singleWhere(
        (element) =>
            identical(
              (element.widget as PdfTextOverlay).selection,
              overlay.selection,
            ) &&
            (element.widget as PdfTextOverlay).page == overlay.page,
      );
  final render = element.renderObject! as RenderBox;
  final scale = overlay.imageRect.width / overlay.pageWidth;
  Offset globalBoundary(int offset) {
    final box = layer.charBoxes[startHandle ? offset : offset - 1];
    return render.localToGlobal(
      overlay.imageRect.topLeft +
          Offset(startHandle ? box.left : box.right, box.bottom) * scale,
    );
  }

  final handle = find.byKey(
    ValueKey(
      'pdf-selection-${startHandle ? 'start' : 'end'}-handle-${overlay.page}',
    ),
  );
  expect(handle.hitTestable(), findsOneWidget);
  final handleRect = tester.getRect(handle);
  expect(handleRect.width, closeTo(48, .1));
  expect(handleRect.height, closeTo(48, .1));
  final start = handleRect.center;
  final delta = globalBoundary(nextOffset) - globalBoundary(initialOffset);
  final gesture = await tester.startGesture(start);
  try {
    // Holding an existing handle must never start a new word selection.
    await tester.pump(const Duration(milliseconds: 400));
    // Cross touch slop before returning to the exact requested character edge.
    await gesture.moveTo(start + const Offset(8, 0));
    await tester.pump();
    await gesture.moveTo(start + delta);
    await tester.pump(const Duration(milliseconds: 150));
    final drags = (binding.reportData ??= {}).putIfAbsent(
      'pdfSelectionDrags',
      () => <Map<String, Object?>>[],
    ) as List<Map<String, Object?>>;
    drags.add({
      'screenshot': screenshot,
      'zoom': overlay.controller.zoomScale,
      'grip': [start.dx, start.dy],
      'delta': [delta.dx, delta.dy],
      'expectedRange': [expected.start, expected.end],
      'actualRange': [
        overlay.selection.range?.start,
        overlay.selection.range?.end,
      ],
    });
    await _screenshot(binding, screenshot);
    expect(overlay.selection.range, expected);
    expect(find.byTooltip('Highlight').hitTestable(), findsNothing);
    expect(find.byType(RawMagnifier), findsOneWidget);
  } finally {
    await gesture.up();
  }
  await tester.pumpAndSettle();
  expect(find.byType(RawMagnifier), findsNothing);
  expect(find.byTooltip('Highlight').hitTestable(), findsOneWidget);
  return expected;
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
