import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/all_formats.dart' show TextColumnPage, TextPagesView;
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_panel.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// The real reader and its original FB2 fixture in medium/expanded windows. These
/// are full-window compositions, including the page beneath each modal panel.
void main() {
  setUpAll(loadUiFonts);

  for (final (profile, window, name) in [
    (
      VisualProfile.phone,
      const Size(800, 1280),
      'portrait-800-light-en',
    ),
    (
      VisualProfile.tabletRtl,
      const Size(1280, 800),
      'landscape-1280-dark-ar',
    ),
    (
      VisualProfile.phone,
      const Size(1032, 1376),
      'portrait-light-en',
    ),
    (
      VisualProfile.phone,
      const Size(1376, 1032),
      'landscape-light-en',
    ),
    (
      VisualProfile.tabletRtl,
      const Size(1376, 1032),
      'landscape-dark-ar',
    ),
  ]) {
    testWidgets('tablet reader panels $name', (tester) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      addTearDown(() async {
        await unmountUi(tester);
        await tester.pump(const Duration(seconds: 1));
      });
      await tester.runAsync(
        () => app.preferencesService.update(
          (preferences) => preferences.copyWith(
            readerThemeId: profile.brightness == Brightness.dark
                ? 'night'
                : 'paper',
          ),
        ),
      );
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => ReaderScreen(
          sourceId: app.book!.id,
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          highlightRepository: app.highlightRepository,
          preferencesService: app.preferencesService,
          screenControlService: app.screenControlService,
          textActions: const [],
          initialSource: app.book,
          initialCfi: 'epubcfi(/6/4)',
        ),
        surfaceSize: window,
      );
      await waitForUi(
        tester,
        () => find.byType(TextColumnPage).evaluate().isNotEmpty,
        description: 'tablet book page',
        timeout: const Duration(seconds: 30),
      );
      final reader = find.byType(TextPagesView);
      final context = tester.element(reader);
      final bloc = context.read<ReaderBloc>();
      final ui = context.read<ReaderUiCubit>();
      final l10n = context.l10n;
      await waitForUi(
        tester,
        () => bloc.state.chapterTitle == 'Chapter 2',
        description: 'restored second chapter',
        timeout: const Duration(seconds: 30),
      );
      final controller = tester.widget<TextPagesView>(reader).controller;
      final pageBounds = tester.getRect(reader);
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final wide = AppWindowSize.isWideSize(window);
      expect(tester.view.physicalSize, window);

      ui.showChrome();
      await tester.pumpAndSettle();
      final actions = find.byKey(const ValueKey('readerChromeCapsule'));
      expect(tester.getSize(actions).height, wide ? 80 : 60);
      expect(
        find.descendant(of: actions, matching: find.byType(TextButton)),
        wide ? findsNWidgets(5) : findsNothing,
        reason: 'expanded reading controls have tappable captions',
      );
      expect(
        find.byTooltip(l10n.readerFontAction).hitTestable(),
        findsOneWidget,
      );
      await expectUiGolden(tester, profile, 'tablet-reader-ready-$name');

      ui.openTocDrawer();
      await tester.pumpAndSettle();
      final contents = _panelBounds(tester, ReaderTocDrawerDriver);
      _expectPanel(contents, window, rtl: rtl);
      final activeChapter = find.widgetWithText(ListTile, 'Chapter 2');
      expect(tester.widget<ListTile>(activeChapter).selected, isTrue);
      expect(tester.getRect(reader), pageBounds);
      expect(tester.widget<TextPagesView>(reader).controller, same(controller));
      await expectUiGolden(tester, profile, 'tablet-reader-contents-$name');

      await tapUi(tester, find.byTooltip(l10n.commonClose).hitTestable());
      ui.openSearchDrawer();
      await tester.pumpAndSettle();
      final field = find.byType(TextField).hitTestable();
      await tester.enterText(field, 'power');
      final search = tester.element(field).read<ReaderSearchCubit>();
      await waitForUi(
        tester,
        () => !search.state.isLoading && search.state.results.isNotEmpty,
        description: 'real book search results',
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();
      final searchBounds = _panelBounds(tester, ReaderSearchPanel);
      _expectPanel(searchBounds, window, rtl: rtl);
      expect(searchBounds, contents);
      expect(tester.getRect(reader), pageBounds);
      expect(tester.widget<TextPagesView>(reader).controller, same(controller));
      await expectUiGolden(tester, profile, 'tablet-reader-search-$name');

      final results = search.state.results;
      await tapUi(tester, find.byTooltip(l10n.commonClose).hitTestable());
      ui.openSearchDrawer();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'power');
      expect(search.state.results, same(results));
    }, tags: ['golden']);
  }
}

Rect _panelBounds(WidgetTester tester, Type owner) {
  final panel = find.descendant(
    of: find.byType(owner),
    matching: find.byType(AppInlineSheet),
  );
  return tester.getRect(
    find.descendant(of: panel, matching: find.byType(Material)).first,
  );
}

void _expectPanel(Rect panel, Size window, {required bool rtl}) {
  if (AppWindowSize.isWideSize(window)) {
    expect(panel.width, AppSizes.sidePanelWidth);
    expect(panel.top, 0);
    expect(panel.bottom, window.height);
    expect(rtl ? panel.left : window.width - panel.right, 0);
  } else {
    expect(panel.width, 640);
    expect(panel.center.dx, window.width / 2);
    expect(panel.bottom, window.height);
    expect(
      panel.height,
      closeTo(
        (window.height - AppInlineSheetGeometry.topGap) *
            AppInlineSheetGeometry.halfFraction,
        .01,
      ),
    );
  }
}
