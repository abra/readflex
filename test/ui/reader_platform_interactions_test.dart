import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:pagecraft/all_formats.dart';
import 'package:pagecraft/testing.dart' show preparePdfEngineForTests;
import 'package:readflex/app/readflex_platform_app.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_brightness_cubit.dart';
import 'package:reader/src/reader_navigation_tile.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import '../support/pdf_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart' show loadUiFonts;

void main() {
  setUpAll(() async {
    await loadUiFonts();
    await preparePdfEngineForTests();
    final font = await rootBundle.load(
      'packages/component_library/fonts/Geist-Variable.ttf',
    );
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '${platform.name} Reader controls navigate under the real root',
      (
        tester,
      ) async {
        _configureView(tester, platform);
        final app = (await tester.runAsync(UiTestApp.create))!;
        addTearDown(app.dispose);
        await tester.pumpWidget(app.widgetAt(AppRoutes.reader(app.book!.id)));
        final pages = find.byType(TextPagesView);
        await waitForUi(
          tester,
          () =>
              pages.evaluate().isNotEmpty &&
              tester.widget<TextPagesView>(pages).controller.isReady,
          description: 'parsed book pages',
        );
        _expectRoot(platform);
        final pageState = tester.state(pages);
        final context = tester.element(pages);
        final l10n = context.l10n;
        final controller = tester.widget<TextPagesView>(pages).controller;
        await _showChrome(tester, pages, l10n.readerContents);
        final slider = find.byType(AppSlider);
        final bounds = tester.getRect(slider);
        final originalCfi = controller.position!.cfi;
        await tester.tapAt(
          Offset(bounds.left + bounds.width * .7, bounds.center.dy),
        );
        await waitForUi(
          tester,
          () => controller.position!.fraction > .55,
          description: 'track tap seeks the rendered book',
        );
        await tester.pumpAndSettle();
        expect(controller.position!.cfi, isNot(originalCfi));
        expect(context.read<ReaderUiCubit>().state.chromeVisible, isTrue);

        final platformSlider = platform == TargetPlatform.iOS
            ? find.byType(cupertino.CupertinoSlider)
            : find.byType(material.Slider);
        final nativeBounds = tester.getRect(platformSlider);
        final value = tester.widget<AppSlider>(slider).value;
        // Begin on the thumb: Cupertino intentionally limits its drag hit area.
        final thumbX =
            nativeBounds.left + 22 + (nativeBounds.width - 44) * value;
        final beforeDrag = controller.position!.fraction;
        final drag = await tester.startGesture(
          Offset(thumbX, nativeBounds.center.dy),
        );
        await drag.moveBy(const Offset(-25, 0));
        await tester.pump();
        await drag.moveBy(const Offset(-75, 0));
        await tester.pump();
        expect(controller.position!.fraction, beforeDrag);
        await drag.up();
        await waitForUi(
          tester,
          () => controller.position!.fraction < beforeDrag - .1,
          description: 'thumb release commits the seek',
        );
        await tester.pumpAndSettle();

        if (platform == TargetPlatform.iOS) {
          final semantics = tester.ensureSemantics();
          try {
            await tester.pump();
            final node = tester.getSemantics(platformSlider);
            final beforeAdjust = controller.position!.fraction;
            node.owner!.performAction(node.id, SemanticsAction.increase);
            await tester.pump();
            await waitForUi(
              tester,
              () => controller.position!.fraction > beforeAdjust,
              description: 'native accessibility adjustment commits the seek',
            );
          } finally {
            semantics.dispose();
          }
        }

        final brightness = context.read<ReaderBrightnessCubit>();
        await tapUi(tester, find.byTooltip(l10n.readerIncreaseBrightness));
        expect(brightness.state.brightnessOverride, isNotNull);
        final increased = brightness.state.controlValue;
        await tapUi(tester, find.byTooltip(l10n.readerDecreaseBrightness));
        expect(brightness.state.controlValue, lessThan(increased));

        await tapUi(tester, find.byTooltip(l10n.readerContents));
        await tester.enterText(
          find.byType(AppTextField).hitTestable(),
          'Chapter 2',
        );
        await tester.pumpAndSettle();
        await tapUi(
          tester,
          find.descendant(
            of: find.byType(ReaderNavigationTile),
            matching: find.text('Chapter 2'),
          ),
        );
        await waitForUi(
          tester,
          () =>
              controller.position!.section == 1 &&
              !context.read<ReaderUiCubit>().state.tocDrawerVisible,
          description: 'filtered chapter selection navigates',
        );
        await _showChrome(tester, pages, l10n.readerContents);
        await tapUi(tester, find.byTooltip(l10n.readerContents));
        await tapUi(tester, find.text(l10n.readerBookmarks));
        await tapUi(tester, find.text(l10n.readerHighlights));
        await tapUi(tester, find.byTooltip(l10n.commonClose));
        await tester.pumpAndSettle();

        final anchor = controller.position!.cfi;
        await tapUi(tester, find.byTooltip(l10n.readerFontAction));
        await tapUi(tester, find.byKey(const ValueKey('reader-font-picker')));
        await tapUi(tester, find.byKey(const ValueKey('reader-font-sans')));
        await tapUi(tester, find.byTooltip(l10n.commonBack));
        await tapUi(tester, find.byTooltip(l10n.commonClose));
        await waitForUi(
          tester,
          () =>
              context.read<ReaderUiCubit>().state.overlay ==
                  ReaderOverlay.none &&
              find
                  .byTooltip(l10n.readerSearchAction)
                  .hitTestable()
                  .evaluate()
                  .isNotEmpty,
          description: 'Appearance closes and restores chrome',
        );
        await tester.pumpAndSettle();
        expect(controller.position!.cfi, anchor);
        expect(tester.state(pages), same(pageState));

        await tapUi(tester, find.byTooltip(l10n.readerSearchAction));
        await tester.enterText(
          find.byType(AppTextField).hitTestable(),
          'devices',
        );
        final search = context.read<ReaderSearchCubit>();
        await waitForUi(
          tester,
          () =>
              !search.state.isLoading &&
              search.state.results.isNotEmpty &&
              find
                  .byType(ReaderSearchResultTile)
                  .hitTestable()
                  .evaluate()
                  .isNotEmpty,
          description: 'search finds actual book text',
        );
        final result = find.byType(ReaderSearchResultTile).hitTestable().first;
        final destination = tester
            .widget<ReaderSearchResultTile>(result)
            .result
            .cfi;
        await tapUi(tester, result);
        await waitForUi(
          tester,
          () => controller.position!.cfi == destination,
          description: 'search result navigates to its CFI',
        );
        await tapUi(tester, find.byTooltip(l10n.readerEndSearch));
        expect(search.state.isNavigating, isFalse);
        expect(tester.state(pages), same(pageState));
        expect(tester.takeException(), isNull);
        await unmountUi(tester);
      },
    );

    testWidgets('${platform.name} Reader Pages opens and selects a PDF page', (
      tester,
    ) async {
      _configureView(tester, platform);
      final app = (await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      ))!;
      addTearDown(app.dispose);
      final book = (await tester.runAsync(() => addPdfFixture(app)))!;
      await tester.pumpWidget(app.widgetAt(AppRoutes.reader(book.id)));
      final pages = find.byType(FixedPagesView);
      await waitForUi(
        tester,
        () => pages.evaluate().isNotEmpty,
        description: 'PDF pages',
      );
      await waitForFixedPage(tester);
      _expectRoot(platform);
      final context = tester.element(pages);
      final l10n = context.l10n;
      final bloc = context.read<ReaderBloc>();
      await waitForUi(
        tester,
        () => bloc.state.documentFeatures?.pageCount == 6,
        description: 'PDF page count',
      );
      await _showChrome(tester, pages, l10n.readerContents);
      await tapUi(tester, find.byTooltip(l10n.readerContents));
      await tapUi(tester, find.text(l10n.readerPages));
      expect(find.byType(ReaderPageGrid), findsOneWidget);
      final secondPage = find.text(l10n.readerPageNumber(2));
      await tester.ensureVisible(secondPage);
      await tester.pumpAndSettle();
      await tapUi(tester, secondPage);
      await waitForUi(
        tester,
        () => bloc.state.document?.currentCfi == 'epubcfi(/6/4)',
        description: 'Pages grid selects the actual second PDF page',
      );
      expect(context.read<ReaderUiCubit>().state.tocDrawerVisible, isFalse);
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    });
  }

  testWidgets(
    'iOS Reader progress and Contents work on a large-text RTL phone',
    (
      tester,
    ) async {
      _configureView(
        tester,
        TargetPlatform.iOS,
        size: const Size(320, 568),
        textScale: 2,
      );
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      await tester.runAsync(
        () => app.preferencesService.update(
          (preferences) => preferences.copyWith(locale: const Locale('ar')),
        ),
      );
      await tester.pumpWidget(app.widgetAt(AppRoutes.reader(app.book!.id)));
      final pages = find.byType(TextPagesView);
      await waitForUi(
        tester,
        () =>
            pages.evaluate().isNotEmpty &&
            tester.widget<TextPagesView>(pages).controller.isReady,
        description: 'RTL book reader',
      );
      final context = tester.element(pages);
      final l10n = context.l10n;
      final controller = tester.widget<TextPagesView>(pages).controller;
      expect(Directionality.of(context), TextDirection.rtl);
      await _showChrome(tester, pages, l10n.readerContents);
      final slider = tester.getRect(find.byType(AppSlider));
      await tester.tapAt(
        Offset(slider.left + slider.width * .7, slider.center.dy),
      );
      await waitForUi(
        tester,
        () => controller.position!.fraction > .55,
        description: 'progress follows the LTR book within RTL chrome',
      );
      final anchor = controller.position!.cfi;
      await tapUi(tester, find.byTooltip(l10n.readerContents));
      for (final label in [l10n.readerBookmarks, l10n.readerHighlights]) {
        await tester.ensureVisible(find.text(label));
        await tapUi(tester, find.text(label));
      }
      await tapUi(tester, find.byTooltip(l10n.commonClose));
      await tester.pumpAndSettle();
      expect(controller.position!.cfi, anchor);
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    },
  );
}

Future<void> _showChrome(
  WidgetTester tester,
  Finder pages,
  String contentsLabel,
) async {
  final contents = find.byTooltip(contentsLabel);
  if (contents.hitTestable().evaluate().isEmpty) {
    await tester.tap(pages);
  }
  await waitForUi(
    tester,
    () => contents.hitTestable().evaluate().isNotEmpty,
    description: 'reader chrome',
  );
  await tester.pumpAndSettle();
}

void _configureView(
  WidgetTester tester,
  TargetPlatform platform, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 47, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectRoot(TargetPlatform platform) {
  expect(find.byType(ReadflexPlatformApp), findsOneWidget);
  expect(
    find.byType(cupertino.CupertinoApp),
    platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(material.MaterialApp),
    platform == TargetPlatform.android ? findsOneWidget : findsNothing,
  );
}
