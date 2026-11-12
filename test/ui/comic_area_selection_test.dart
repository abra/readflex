import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart'
    show AppColorSwatchButton;
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';

import '../support/comic_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final (name, profile, size, scale) in const [
    ('phone', VisualProfile.phone, Size(390, 844), 1.0),
    ('dark', VisualProfile.dark, Size(390, 844), 1.0),
    ('phone-rtl-large', VisualProfile.tabletRtl, Size(390, 844), 2.0),
    ('tablet-landscape', VisualProfile.phone, Size(1280, 800), 1.0),
  ]) {
    testWidgets('comic area editing stays coherent in Reader $name', (
      tester,
    ) async {
      final app = (await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      ))!;
      addTearDown(app.dispose);
      final comic = (await tester.runAsync(() => addComicFixture(app)))!;
      await tester.runAsync(
        () => app.preferencesService.update(
          (preferences) => preferences.copyWith(
            readerThemeId: profile.brightness == Brightness.dark
                ? 'mist'
                : 'paper',
          ),
        ),
      );
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => const Scaffold(body: Text('Reader parent route')),
        surfaceSize: size,
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: ReaderScreen(
                sourceId: comic.id,
                bookRepository: app.bookRepository,
                highlightRepository: app.highlightRepository,
                preferencesService: app.preferencesService,
                screenControlService: app.screenControlService,
                textActions: const [],
                initialSource: comic,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await waitForFixedPage(tester);
      await tester.pumpAndSettle();
      if (size.width > size.height) {
        await waitForUi(
          tester,
          () =>
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is FixedPagePainter,
                  )
                  .evaluate()
                  .length >=
              2,
          description: 'the landscape comic spread',
        );
        await tester.pumpAndSettle();
      }
      final layer = find.byWidgetPredicate(
        (widget) => widget is ComicImageAreaLayer && widget.page == 0,
      );
      expect(layer, findsOneWidget);
      final selection = tester.element(layer).read<ReaderImageSelectionCubit>();
      final pages = tester.widget<FixedPagesView>(find.byType(FixedPagesView));
      final controls = find.byType(ReaderHighlightControls).hitTestable();
      final l10n = tester.element(layer).l10n;
      final image = _imageBounds(tester, layer);

      final longPress = await tester.startGesture(image.center);
      await tester.pump(const Duration(milliseconds: 550));
      expect(_draft(tester, layer).isActive, isTrue);
      expect(selection.state.isAdjusting, isTrue);
      expect(controls, findsNothing);
      expect(pages.controller.inputLocked, isTrue);
      await _capture(tester, name, '01-holding');
      await longPress.up();
      await tester.pumpAndSettle();
      expect(selection.state.isAdjusting, isFalse);
      expect(controls, findsOneWidget);
      await _capture(tester, name, '02-released');

      await tapUi(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is AppColorSwatchButton &&
              widget.tooltip == l10n.highlightColorBlue,
        ),
      );
      final controlsElement = tester.element(controls);
      final blue = _draft(tester, layer).color;
      expect(
        tester.widget<ReaderHighlightControls>(controls).selectedColor,
        HighlightColor.blue,
      );
      final beforeMove = _draftBounds(tester, layer);
      final move = await tester.startGesture(beforeMove.center);
      await move.moveBy(const Offset(30, 40));
      await tester.pump();
      expect(selection.state.isAdjusting, isTrue);
      expect(controls, findsNothing);
      expect(_draft(tester, layer).color, blue);
      await _capture(tester, name, '03-moving');
      await move.up();
      await tester.pumpAndSettle();
      expect(_draftBounds(tester, layer).topLeft, isNot(beforeMove.topLeft));
      expect(selection.state.isAdjusting, isFalse);
      expect(tester.element(controls), same(controlsElement));
      expect(
        tester.widget<ReaderHighlightControls>(controls).selectedColor,
        HighlightColor.blue,
      );

      // Exercise Reader hit testing from the triangular corner region.
      final beforeResize = _draftBounds(tester, layer);
      final resize = await tester.startGesture(
        _gripCenters(tester, layer).bottomRight,
      );
      await tester.pump(const Duration(milliseconds: 550));
      await resize.moveBy(const Offset(40, 65));
      await tester.pump();
      expect(selection.state.isAdjusting, isTrue);
      expect(controls, findsNothing);
      expect(_draft(tester, layer).color, blue);
      await _capture(tester, name, '04-resizing');
      await resize.up();
      await tester.pumpAndSettle();
      final resized = _draftBounds(tester, layer);
      expect(resized.width, greaterThan(beforeResize.width + 15));
      expect(resized.height, greaterThan(beforeResize.height + 30));
      expect(_draft(tester, layer).color, blue);
      await _capture(tester, name, '04-resized');

      // A tall crop keeps a 48dp square around each corner clear of the popup.
      final southEastGrip = _gripCenters(tester, layer).bottomRight;
      await tester.dragFrom(
        southEastGrip,
        image.bottomRight + const Offset(20, 20) - southEastGrip,
      );
      await tester.pumpAndSettle();
      final northWestGrip = _gripCenters(tester, layer).topLeft;
      await tester.dragFrom(
        northWestGrip,
        image.topLeft - const Offset(20, 20) - northWestGrip,
      );
      await tester.pumpAndSettle();
      final tall = _draftBounds(tester, layer);
      expect(tall.height, greaterThan(image.height * .8));
      expect(tall.width, greaterThan(image.width * .8));
      expect(_draft(tester, layer).rect, const Rect.fromLTWH(0, 0, 1, 1));
      final popup = tester.getRect(controls);
      for (final corner in [
        tall.topLeft,
        tall.topRight,
        tall.bottomLeft,
        tall.bottomRight,
      ]) {
        expect(
          popup.overlaps(
            Rect.fromCenter(center: corner, width: 48, height: 48),
          ),
          isFalse,
          reason: '$name popup must leave the complete corner target usable',
        );
      }
      await _capture(tester, name, '05-tall-crop');

      // The triangular corner stays usable when the crop reaches the page edge.
      final edgeResize = await tester.startGesture(
        _gripCenters(tester, layer).bottomRight,
      );
      await tester.pump(const Duration(milliseconds: 550));
      await edgeResize.moveBy(const Offset(-32, -44));
      await tester.pump();
      expect(selection.state.isAdjusting, isTrue);
      expect(controls, findsNothing);
      await edgeResize.up();
      await tester.pumpAndSettle();
      final fromEdge = _draftBounds(tester, layer);
      expect(fromEdge.topLeft, tall.topLeft);
      expect(fromEdge.width, lessThan(tall.width - 20));
      expect(fromEdge.height, lessThan(tall.height - 30));
      expect(_draft(tester, layer).color, blue);
      expect(controls, findsOneWidget);
      await _capture(tester, name, '05-edge-grip-resized');

      await tapUi(tester, find.byTooltip(l10n.commonCancel));
      expect(_draft(tester, layer).isActive, isFalse);
      expect(selection.state.hasSelection, isFalse);
      expect(pages.controller.inputLocked, isFalse);
      expect(find.byType(ReaderScreen), findsOneWidget);

      // No delayed clear-protection window after changing a colour.
      await tester.longPressAt(image.center);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppColorSwatchButton &&
              widget.tooltip == l10n.highlightColorBlue,
        ),
      );
      await tester.pump();
      await tester.tapAt(image.topLeft + const Offset(20, 40));
      await tester.pump();
      expect(_draft(tester, layer).isActive, isFalse);
      expect(selection.state.hasSelection, isFalse);
      expect(controls, findsNothing);
      expect(pages.controller.inputLocked, isFalse);

      await tester.longPressAt(image.center);
      await tester.pumpAndSettle();
      expect(selection.state.hasSelection, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('Reader parent route').hitTestable(), findsNothing);
      expect(_draft(tester, layer).isActive, isFalse);
      expect(selection.state.hasSelection, isFalse);
      expect(pages.controller.inputLocked, isFalse);
      await _capture(tester, name, '06-back-cleared');
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    });
  }
}

ComicImageAreaDraft _draft(WidgetTester tester, Finder layer) =>
    tester.widget<ComicImageAreaLayer>(layer).draft;

Rect _imageBounds(WidgetTester tester, Finder layer) => _globalRect(
  tester,
  layer,
  tester.widget<ComicImageAreaLayer>(layer).imageRect,
);

Rect _draftBounds(WidgetTester tester, Finder layer) {
  return _globalRect(tester, layer, _localDraftBounds(tester, layer));
}

Rect _localDraftBounds(WidgetTester tester, Finder layer) {
  final image = tester.widget<ComicImageAreaLayer>(layer).imageRect;
  final draft = _draft(tester, layer).rect!;
  return Rect.fromLTWH(
    image.left + draft.left * image.width,
    image.top + draft.top * image.height,
    draft.width * image.width,
    draft.height * image.height,
  );
}

Rect _gripCenters(WidgetTester tester, Finder layer) {
  final widget = tester.widget<ComicImageAreaLayer>(layer);
  final box = tester.renderObject<RenderBox>(layer);
  final centers = ComicImageAreaGeometry.gripCenters(
    _localDraftBounds(tester, layer),
    widget.controller.zoomScale,
    bounds: Offset.zero & box.size,
  );
  return _globalRect(tester, layer, centers);
}

Rect _globalRect(WidgetTester tester, Finder layer, Rect local) {
  final box = tester.renderObject<RenderBox>(layer);
  return Rect.fromPoints(
    box.localToGlobal(local.topLeft),
    box.localToGlobal(local.bottomRight),
  );
}

Future<void> _capture(WidgetTester tester, String profile, String state) async {
  final directory = Platform.environment['READFLEX_VISUAL_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(goldenBoundary),
  );
  await tester.runAsync(() async {
    final frame = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await frame.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/comic-area/$profile/$state.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      frame.dispose();
    }
  });
}
