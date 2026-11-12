import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show DefaultTabController, TabBar;
import 'package:pagecraft/all_formats.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_contents_tab_bar.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/pdf_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

const _physicalRotation = bool.fromEnvironment('READFLEX_TEST_TABLET_ROTATION');

Map<String, Object> _expectNativeReaderChrome(WidgetTester tester) {
  final slider = find.byType(AppSlider);
  final chromeContext = tester.element(slider);
  final size = MediaQuery.sizeOf(chromeContext);
  final capsule = find.byKey(const ValueKey('readerChromeCapsule'));
  final buttons = find.descendant(
    of: capsule,
    matching: find.byType(AppButton),
  );
  final expectedCaptions = [
    chromeContext.l10n.readerBack,
    chromeContext.l10n.readerContents,
    chromeContext.l10n.readerAppearanceTitle,
    chromeContext.l10n.readerBookmark,
    chromeContext.l10n.readerSearchAction,
  ];
  expect(buttons, findsNWidgets(expectedCaptions.length));
  double? glyphCenterY;
  double? captionBaseline;
  double? captionHeight;
  final actionMetrics = <Map<String, Object>>[];
  for (var index = 0; index < expectedCaptions.length; index++) {
    final button = buttons.at(index);
    final nativeButton = find.descendant(
      of: button,
      matching: find.byType(cupertino.CupertinoButton),
    );
    expect(nativeButton, findsOneWidget);
    final buttonRect = tester.getRect(nativeButton);
    expect(buttonRect.width, greaterThanOrEqualTo(48));
    expect(buttonRect.height, greaterThanOrEqualTo(48));
    final caption = find.descendant(
      of: button,
      matching: find.byType(Text),
    );
    expect(caption, findsOneWidget);
    final captionText = tester.widget<Text>(caption);
    expect(captionText.data, expectedCaptions[index]);
    final captionContext = tester.element(caption);
    final captionStyle = DefaultTextStyle.of(
      captionContext,
    ).style.merge(captionText.style);
    expect(captionStyle.fontSize, 17);
    expect(captionText.maxLines, 1);
    final paragraph = tester.renderObject<RenderParagraph>(caption);
    expect(paragraph.didExceedMaxLines, isFalse);
    final fullCaption = TextPainter(
      text: TextSpan(text: captionText.data, style: captionStyle),
      textDirection: Directionality.of(captionContext),
      textScaler: MediaQuery.textScalerOf(captionContext),
      locale: Localizations.maybeLocaleOf(captionContext),
    )..layout();
    expect(
      fullCaption.width,
      lessThanOrEqualTo(paragraph.size.width + .01),
      reason: '${captionText.data} must fit in full on one line',
    );
    fullCaption.dispose();
    final glyph = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'readerChromeActionGlyph-',
            ),
      ),
    );
    final captionSlot = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'readerChromeActionCaption-',
            ),
      ),
    );
    expect(glyph, findsOneWidget);
    expect(captionSlot, findsOneWidget);
    expect(tester.getSize(glyph).height, 28);
    final centerY = tester.getCenter(glyph).dy;
    final baseline = paragraph
        .localToGlobal(
          Offset(
            0,
            paragraph.getDryBaseline(
              paragraph.constraints,
              TextBaseline.alphabetic,
            )!,
          ),
        )
        .dy;
    final height = tester.getSize(captionSlot).height;
    expect(centerY, closeTo(glyphCenterY ??= centerY, .01));
    expect(baseline, closeTo(captionBaseline ??= baseline, .01));
    expect(height, closeTo(captionHeight ??= height, .01));
    if (tester.widget<AppButton>(button).onPressed != null) {
      expect(nativeButton.hitTestable(), findsOneWidget);
      expect(caption.hitTestable(), findsOneWidget);
    }
    actionMetrics.add({
      'caption': captionText.data!,
      'buttonWidth': buttonRect.width,
      'buttonHeight': buttonRect.height,
      'glyphCenterY': centerY,
      'captionBaseline': baseline,
    });
  }
  final nativeSlider = find.descendant(
    of: slider,
    matching: find.byType(cupertino.CupertinoSlider),
  );
  final nativeTrackRect = tester.getRect(nativeSlider);
  final startLabelRect = tester.getRect(
    find.byKey(const ValueKey('readerProgressStartLabel')),
  );
  final pageLabelRect = tester.getRect(
    find.byKey(const ValueKey('readerProgressPageLabel')),
  );
  expect(startLabelRect.left, closeTo(nativeTrackRect.left + 8, .01));
  expect(pageLabelRect.right, closeTo(nativeTrackRect.right - 8, .01));
  return {
    'width': size.width,
    'height': size.height,
    'capsuleWidth': tester.getSize(capsule).width,
    'actions': actionMetrics,
    'trackLeft': nativeTrackRect.left + 8,
    'startLabelLeft': startLabelRect.left,
    'trackRight': nativeTrackRect.right - 8,
    'pageLabelRight': pageLabelRect.right,
  };
}

/// Exercises platform navigation through the production root and real parser,
/// using isolated storage and the device's actual viewport.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    // The iOS compositor can still hold the frame preceding the last pump.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    await takeDeviceScreenshot(binding, name);
  }

  tearDownAll(() {
    binding.reportData ??= {};
    binding.reportData!.addAll({
      'platform': Platform.operatingSystem,
      'tests': binding.results.map(
        (name, result) => MapEntry(name, result.toString()),
      ),
    });
  });

  testWidgets('Collections opens, selects and restores the whole Library', (
    tester,
  ) async {
    final app = await UiTestApp.create();
    addTearDown(app.dispose);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);

    final picker = find.byKey(const ValueKey('libraryCollectionsButton'));
    await tapUi(tester, picker);
    expect(
      find.byKey(const ValueKey('collectionScopeSelection-library')),
      findsOneWidget,
    );
    await capture(tester, 'platform-collections-library');
    await tapUi(
      tester,
      find.byKey(
        const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
      ),
    );
    await tester.pumpAndSettle();
    await tapUi(tester, picker);
    expect(
      find.byKey(
        const ValueKey(
          'collectionScopeSelection-favourites-readflex:favourites',
        ),
      ),
      findsOneWidget,
    );
    await capture(tester, 'platform-collections-favourites');
    await tapUi(
      tester,
      find.byKey(const ValueKey('collectionScopeRow-library')),
    );
    await tester.pumpAndSettle();
    await waitForUi(
      tester,
      () => find
          .byKey(ValueKey('library-grid-${app.book!.id}'))
          .hitTestable()
          .evaluate()
          .isNotEmpty,
      description: 'book restored by the whole-Library scope',
    );
    expect(tester.takeException(), isNull);
    await unmountUi(tester);
  });

  testWidgets('Reader track taps navigate and its menus preserve the page', (
    tester,
  ) async {
    final app = await UiTestApp.create();
    addTearDown(app.dispose);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widgetAt(AppRoutes.reader(app.book!.id)));
    final pages = find.byType(TextPagesView);
    await waitForUi(
      tester,
      () =>
          pages.evaluate().isNotEmpty &&
          tester.widget<TextPagesView>(pages).controller.position != null,
      description: 'parsed book and reading position',
      timeout: const Duration(seconds: 45),
    );
    final readerState = tester.state(pages);
    final bloc = tester.element(pages).read<ReaderBloc>();
    await waitForUi(
      tester,
      () =>
          bloc.state.chapterCurrentPage != null &&
          (bloc.state.chapterTotalPages ?? 0) > 1,
      description: 'paginated chapter position',
    );
    final slider = find.byType(AppSlider);
    final ui = tester.element(pages).read<ReaderUiCubit>();
    final controller = tester.widget<TextPagesView>(pages).controller;
    final positionBeforeChrome = controller.position!.cfi;
    expect(ui.state.chromeVisible, isFalse);
    expect(slider.hitTestable(), findsNothing);
    await tester.tapAt(tester.getRect(pages).center);
    await tester.pumpAndSettle();
    expect(ui.state.chromeVisible, isTrue);
    expect(controller.position!.cfi, positionBeforeChrome);
    await waitForUi(
      tester,
      () => slider.hitTestable().evaluate().isNotEmpty,
      description: 'visible Reader progress track',
    );
    final initialPosition = controller.position!;
    final track = tester.getRect(slider);
    await tester.tapAt(Offset(track.left + track.width * .8, track.center.dy));
    await waitForUi(
      tester,
      () =>
          controller.position!.fraction > initialPosition.fraction + .3 &&
          controller.position!.cfi != initialPosition.cfi,
      description: 'track tap navigates to a later rendered page',
    );
    await tester.pumpAndSettle();
    final laterPosition = controller.position!;
    final trackAfterSeek = tester.getRect(slider);
    await tester.tapAt(
      Offset(
        trackAfterSeek.left + trackAfterSeek.width * .2,
        trackAfterSeek.center.dy,
      ),
    );
    await waitForUi(
      tester,
      () =>
          controller.position!.fraction < laterPosition.fraction - .3 &&
          controller.position!.cfi != laterPosition.cfi,
      description: 'track tap navigates back to an earlier rendered page',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('readerProgressStartLabel')))
          .data,
      bloc.state.chapterTitle,
    );
    await capture(tester, 'platform-reader-track-seek');

    final chromeContext = tester.element(slider);
    if (Platform.isIOS &&
        AppWindowSize.isWide(chromeContext) &&
        MediaQuery.textScalerOf(chromeContext).scale(17) <= 17 * 1.3) {
      (binding.reportData ??= {})['readerChrome'] = _expectNativeReaderChrome(
        tester,
      );
      if (_physicalRotation) {
        final rotationCfi = controller.position!.cfi;
        final rotations = <Map<String, Object>>[];
        (binding.reportData ??= {})['readerChromeRotations'] = rotations;
        for (final landscape in [true, false]) {
          final orientation = landscape ? 'landscape' : 'portrait';
          final previousSize = MediaQuery.sizeOf(tester.element(slider));
          debugPrint('READFLEX_READER_ROTATE:$orientation');
          await waitForUi(
            tester,
            () {
              final size = MediaQuery.sizeOf(tester.element(slider));
              return size != previousSize &&
                  (size.width > size.height) == landscape;
            },
            description: 'native Reader rotation to $orientation',
            timeout: const Duration(seconds: 60),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextPagesView>(pages).controller,
            same(controller),
          );
          expect(controller.position!.cfi, rotationCfi);
          expect(ui.state.chromeVisible, isTrue);
          rotations.add({
            'orientation': orientation,
            ..._expectNativeReaderChrome(tester),
          });
          await capture(tester, 'platform-reader-chrome-rotated-$orientation');
        }
      }
    }

    final position = bloc.state.document!.currentCfi;
    await tapUi(tester, find.byTooltip('Contents'));
    await tapUi(tester, find.text('Bookmarks').hitTestable());
    await capture(tester, 'platform-reader-contents');
    await tapUi(tester, find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip('Font'));
    await tapUi(tester, find.byKey(const ValueKey('reader-font-picker')));
    await capture(tester, 'platform-reader-font-menu');
    await tapUi(tester, find.byTooltip('Back'));
    await tapUi(tester, find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await waitForUi(
      tester,
      () =>
          find.byTooltip('Contents').hitTestable().evaluate().isNotEmpty &&
          find.byTooltip('Close').hitTestable().evaluate().isEmpty,
      description: 'Appearance exit restores interactive Reader controls',
    );
    expect(tester.state(pages), same(readerState));
    expect(bloc.state.document!.currentCfi, position);
    expect(tester.takeException(), isNull);
    await unmountUi(tester);
  });

  testWidgets('PDF Contents keeps its tabs compact and navigates Pages', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final book = await addPdfFixture(app);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widgetAt(AppRoutes.reader(book.id)));
    final pages = find.byType(FixedPagesView);
    await waitForUi(
      tester,
      () => pages.evaluate().isNotEmpty,
      description: 'PDF reader',
      timeout: const Duration(seconds: 45),
    );
    await waitForFixedPage(tester);
    final context = tester.element(pages);
    final l10n = context.l10n;
    final bloc = context.read<ReaderBloc>();
    final ui = context.read<ReaderUiCubit>();
    await waitForUi(
      tester,
      () => bloc.state.documentFeatures?.pageCount == 6,
      description: 'PDF page count',
    );
    ui.showChrome();
    await waitForUi(
      tester,
      () => find
          .byTooltip(l10n.readerContents)
          .hitTestable()
          .evaluate()
          .isNotEmpty,
      description: 'visible PDF Reader controls',
    );
    await tapUi(tester, find.byTooltip(l10n.readerContents));
    final tabBar = find.byType(ReaderContentsTabBar);
    final tabContext = tester.element(tabBar);
    final controller = DefaultTabController.of(tabContext);
    expect(controller.length, 4);
    expect(controller.index, 0);
    for (final label in [
      l10n.readerChapters,
      l10n.readerPages,
      l10n.readerBookmarks,
      l10n.readerHighlights,
    ]) {
      final tab = find.descendant(of: tabBar, matching: find.text(label));
      expect(tab, findsOneWidget);
      if (Platform.isIOS) expect(tab.hitTestable(), findsOneWidget);
    }
    final nativeChoices = find.byType(
      cupertino.CupertinoSlidingSegmentedControl<int>,
    );
    if (Platform.isIOS) {
      expect(find.byType(AppChoiceControl<int>), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      final size = MediaQuery.sizeOf(tabContext);
      final scale = MediaQuery.textScalerOf(tabContext);
      if (size.width >= 390 && (scale.scale(14) - 14).abs() < .01) {
        expect(nativeChoices, findsOneWidget);
        expect(tester.getSize(tabBar).height, lessThanOrEqualTo(70));
        final label = find.descendant(
          of: tabBar,
          matching: find.text(l10n.readerChapters),
        );
        final style = DefaultTextStyle.of(tester.element(label)).style.merge(
          tester.widget<Text>(label).style,
        );
        expect(
          style.fontSize,
          AppWindowSize.isMedium(tabContext)
              ? tabContext.text.bodyMedium.fontSize
              : tabContext.text.labelSmall.fontSize,
        );
        if (AppWindowSize.isWide(tabContext)) {
          expect(tester.getSize(tabBar).width, 420);
        }
        (binding.reportData ??= {})['pdfContents'] = {
          'width': size.width,
          'height': size.height,
          'barWidth': tester.getSize(tabBar).width,
          'barHeight': tester.getSize(tabBar).height,
          'labelFontSize': style.fontSize,
        };
      }
    } else if (Platform.isAndroid) {
      expect(find.byType(TabBar), findsOneWidget);
      expect(nativeChoices, findsNothing);
    }
    await capture(tester, 'platform-pdf-contents-chapters');

    for (final (label, index) in [
      (l10n.readerBookmarks, 2),
      (l10n.readerHighlights, 3),
      (l10n.readerPages, 1),
    ]) {
      final tab = find.descendant(of: tabBar, matching: find.text(label));
      await tester.ensureVisible(tab);
      await tapUi(tester, tab);
      expect(controller.index, index);
      if (nativeChoices.evaluate().isNotEmpty) {
        expect(
          tester
              .widget<cupertino.CupertinoSlidingSegmentedControl<int>>(
                nativeChoices,
              )
              .groupValue,
          index,
        );
      }
    }
    final grid = find.byType(ReaderPageGrid);
    expect(grid, findsOneWidget);
    await waitForUi(
      tester,
      () => find
          .descendant(
            of: grid,
            matching: find.byWidgetPredicate(
              (widget) => widget is RawImage && widget.image != null,
            ),
          )
          .evaluate()
          .isNotEmpty,
      description: 'PDF page previews',
      timeout: const Duration(seconds: 30),
    );
    await capture(tester, 'platform-pdf-contents-pages');
    if (Platform.isIOS &&
        _physicalRotation &&
        AppWindowSize.isWide(tabContext)) {
      final rotations = <Map<String, Object>>[];
      (binding.reportData ??= {})['pdfContentsRotations'] = rotations;
      for (final landscape in [true, false]) {
        final orientation = landscape ? 'landscape' : 'portrait';
        debugPrint('READFLEX_PDF_ROTATE:$orientation');
        await waitForUi(
          tester,
          () {
            final size = MediaQuery.sizeOf(tester.element(tabBar));
            return (size.width > size.height) == landscape;
          },
          description: 'native PDF Contents rotation to $orientation',
          timeout: const Duration(seconds: 60),
        );
        await tester.pumpAndSettle();
        final rotatedContext = tester.element(tabBar);
        final size = MediaQuery.sizeOf(rotatedContext);
        expect(DefaultTabController.of(rotatedContext), same(controller));
        expect(controller.index, 1);
        expect(tester.getSize(tabBar).width, 420);
        expect(tester.getSize(tabBar).height, lessThanOrEqualTo(70));
        rotations.add({
          'orientation': orientation,
          'width': size.width,
          'height': size.height,
          'barHeight': tester.getSize(tabBar).height,
        });
        await capture(tester, 'platform-pdf-contents-rotated-$orientation');
      }
    }
    await tapUi(tester, find.byTooltip(l10n.commonClose));
    await tapUi(tester, find.byTooltip(l10n.readerContents));
    expect(DefaultTabController.of(tester.element(tabBar)).index, 1);
    expect(grid, findsOneWidget);

    final secondPage = find.text(l10n.readerPageNumber(2));
    await tester.ensureVisible(secondPage);
    await tester.pumpAndSettle();
    await tapUi(tester, secondPage);
    await waitForUi(
      tester,
      () => bloc.state.document?.currentCfi == 'epubcfi(/6/4)',
      description: 'Pages grid selects the actual second PDF page',
    );
    expect(ui.state.tocDrawerVisible, isFalse);
    expect(tester.takeException(), isNull);
    await unmountUi(tester);
  });
}
