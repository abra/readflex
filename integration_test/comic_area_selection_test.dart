import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';

import '../test/support/comic_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() {
    binding.reportData ??= {};
    binding.reportData!.addAll({
      'platform': Platform.operatingSystem,
      'tests': binding.results.map(
        (name, value) => MapEntry(name, value.toString()),
      ),
    });
  });

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 100));
    binding.reportData ??= {};
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    binding.reportData!['viewport'] = {
      'width': viewport.width,
      'height': viewport.height,
    };
    if (Platform.isAndroid) {
      await captureAndroidScreenshot(name);
    } else {
      await binding.takeScreenshot(name).timeout(const Duration(seconds: 20));
    }
  }

  testWidgets('native comic draft resize, cancellation and exact save', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final comic = await addComicFixture(app);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${comic.id}')));
    await waitForFixedPage(tester);
    await tester.pumpAndSettle();
    final layer = find.byWidgetPredicate(
      (widget) => widget is ComicImageAreaLayer && widget.page == 0,
    );
    final selection = tester.element(layer).read<ReaderImageSelectionCubit>();
    final controls = find.byType(ReaderHighlightControls).hitTestable();
    final pages = tester.widget<FixedPagesView>(find.byType(FixedPagesView));
    final l10n = tester.element(layer).l10n;
    final image = _imageBounds(tester, layer);

    final create = await tester.startGesture(image.center);
    await tester.pump(const Duration(milliseconds: 550));
    expect(_draft(tester, layer).isActive, isTrue);
    expect(selection.state.isAdjusting, isTrue);
    expect(controls, findsNothing);
    await capture(tester, 'comic-area-holding');
    await create.up();
    await tester.pumpAndSettle();
    expect(controls, findsOneWidget);

    // Hold the triangular corner before moving: Android/iOS must still resize
    // the same draft when its long-press recognizer also reaches the timeout.
    final before = _draftBounds(tester, layer);
    final resize = await tester.startGesture(
      _gripCenters(tester, layer).bottomRight,
    );
    await tester.pump(const Duration(milliseconds: 550));
    await resize.moveBy(const Offset(40, 65));
    await tester.pump();
    expect(selection.state.isAdjusting, isTrue);
    expect(controls, findsNothing);
    expect(_draftBounds(tester, layer).width, greaterThan(before.width + 15));
    await capture(tester, 'comic-area-resizing');
    await resize.up();
    await tester.pumpAndSettle();
    expect(selection.state.isAdjusting, isFalse);
    expect(_draftBounds(tester, layer).height, greaterThan(before.height + 30));
    await capture(tester, 'comic-area-resized');

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
    expect(pages.controller.inputLocked, isFalse);
    expect(controls, findsNothing);

    await tester.longPressAt(image.center);
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.commonCancel));
    expect(selection.state.hasSelection, isFalse);
    expect(_draft(tester, layer).isActive, isFalse);
    expect(find.byType(ReaderScreen), findsOneWidget);
    await tester.longPressAt(image.center);
    await tester.pumpAndSettle();
    await binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(selection.state.hasSelection, isFalse);
    expect(_draft(tester, layer).isActive, isFalse);
    expect(pages.controller.inputLocked, isFalse);

    await tester.longPressAt(image.center);
    await tester.pumpAndSettle();
    final growthBounds = _draftBounds(tester, layer);
    final growingGrip = _gripCenters(tester, layer).bottomRight;
    final grabInset = growthBounds.bottomRight - growingGrip;
    final edgeEndpoint = image.bottomRight - grabInset;
    final viewport =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    expect(
      viewport.contains(edgeEndpoint),
      isTrue,
      reason:
          'The native corner endpoint $edgeEndpoint must stay inside $viewport',
    );
    final beforeGrowth = _draft(tester, layer).rect!;
    // Preserve the initial grab offset as the triangle grows, keeping the
    // pointer inside the view while the crop reaches the page edge.
    final growth = await tester.startGesture(growingGrip);
    final growthDelta = edgeEndpoint - growingGrip;
    // Gradual movement must win against the parent zoom recognizer too.
    await growth.moveBy(growthDelta / growthDelta.distance * 20);
    await tester.pump();
    await growth.moveTo(edgeEndpoint);
    await tester.pump();
    final adjustingDuringGrowth = selection.state.isAdjusting;
    await growth.up();
    await tester.pumpAndSettle();
    final grown = _draft(tester, layer).rect!;
    expect(adjustingDuringGrowth, isTrue);
    expect(
      grown.right,
      closeTo(1, 1e-9),
      reason: 'Quick drag from $growingGrip to the page edge at $edgeEndpoint',
    );
    expect(grown.bottom, closeTo(1, 1e-9));
    expect(grown.width, greaterThan(beforeGrowth.width + .2));
    expect(grown.height, greaterThan(beforeGrowth.height + .2));
    final atEdge = _draftBounds(tester, layer);
    final edgeResize = await tester.startGesture(
      _gripCenters(tester, layer).bottomRight,
    );
    await tester.pump(const Duration(milliseconds: 550));
    await edgeResize.moveBy(const Offset(-32, -45));
    await tester.pump();
    expect(selection.state.isAdjusting, isTrue);
    expect(controls, findsNothing);
    await capture(tester, 'comic-area-edge-resizing');
    await edgeResize.up();
    await tester.pumpAndSettle();
    final edgeResized = _draftBounds(tester, layer);
    expect(edgeResized.topLeft, atEdge.topLeft);
    expect(edgeResized.width, lessThan(atEdge.width - 20));
    expect(edgeResized.height, lessThan(atEdge.height - 30));
    expect(selection.state.isAdjusting, isFalse);
    expect(controls, findsOneWidget);
    await capture(tester, 'comic-area-edge-resized');
    final exact = _draft(tester, layer).rect!;
    await tapUi(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is AppColorSwatchButton &&
            widget.tooltip == l10n.highlightColorBlue,
      ),
    );
    await tapUi(tester, find.byTooltip(l10n.highlightAction));
    await tapUi(tester, find.text(l10n.readerSkip));
    await waitForUi(
      tester,
      () => !selection.state.hasSelection,
      description: 'saved image area',
    );
    final saved = (await app.highlightRepository.getHighlightsBySource(
      comic.id,
    )).single;
    expect(saved.color, HighlightColor.blue);
    expect(
      saved.imageArea,
      HighlightImageArea(
        pageIndex: 0,
        x: exact.left,
        y: exact.top,
        width: exact.width,
        height: exact.height,
      ),
    );
    expect(_draft(tester, layer).isActive, isFalse);
    expect(pages.controller.inputLocked, isFalse);
    await capture(tester, 'comic-area-saved');
    expect(tester.takeException(), isNull);
    await unmountUi(tester);
  });
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
