import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_event.dart';
import 'package:reader/src/reader_search_navigation_bar.dart';
import 'package:reader/src/reader_search_occlusion.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart'
    show TextColumnPage, TextPagesView, TextScrollView;

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

void main() {
  late UiTestApp app;
  setUp(() async {
    app = await UiTestApp.create();
    await app.articleRepository.addExtractedArticle(ReadingFixture.article);
  });
  tearDown(() => app.dispose());

  testWidgets(
    'book search overlays the mounted pages and never resizes them',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app.widget);
      await tapUi(
        tester,
        find.byKey(ValueKey('library-grid-${app.book!.id}')),
      );
      final pages = find.byType(TextPagesView);
      await waitForUi(
        tester,
        () => find.byType(TextColumnPage).evaluate().isNotEmpty,
        description: 'the first page',
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();
      final originalState = tester.state(pages);
      final originalBounds = tester.getRect(pages);
      final readerContext = tester.element(pages);
      final ui = readerContext.read<ReaderUiCubit>();
      final l10n = readerContext.l10n;
      double overlayInset() => tester
          .widget<ReaderSearchOcclusionMarker>(
            find.byType(ReaderSearchOcclusionMarker),
          )
          .bottomInset;
      ui.showChrome();
      await tester.pumpAndSettle();
      for (final label in [
        l10n.readerBack,
        l10n.readerFontAction,
        l10n.readerBookmark,
      ]) {
        final button = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == label,
        );
        expect(
          tester.getSize(button),
          const Size.square(AppSizes.buttonHeight),
        );
        final style = tester.widget<IconButton>(button).style!;
        expect(
          style.shape?.resolve({WidgetState.pressed}),
          isA<CircleBorder>(),
        );
      }
      expect(tester.getRect(pages), originalBounds);
      expect(tester.state(pages), same(originalState));
      ui.hideChrome();
      await tester.pumpAndSettle();
      final search = readerContext.read<ReaderSearchCubit>();
      search.recentQuerySelected(
        'vision',
        searchBook: (_) => Stream.fromIterable([
          const ReaderSearchResults(
            requestId: 1,
            results: [
              ReaderSearchResult(
                cfi: 'first',
                excerpt: ReaderSearchExcerpt(match: 'vision'),
              ),
              ReaderSearchResult(
                cfi: 'second',
                excerpt: ReaderSearchExcerpt(match: 'vision'),
              ),
            ],
          ),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 50));
      search.resultSelected(
        index: 0,
        returnLocation: const ReaderSearchLocation(
          cfi: 'origin',
          fraction: 0.12,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderSearchNavigationBar), findsOneWidget);
      expect(
        tester.getRect(pages),
        originalBounds,
        reason: 'Starting match navigation must not repaginate the reader',
      );
      expect(tester.state(pages), same(originalState));
      final fraction =
          tester.getSize(find.byType(ReaderSearchNavigationBar)).height /
          originalBounds.height;
      expect(overlayInset(), fraction);

      search.resultSelected(index: 1);
      await tester.pumpAndSettle();
      expect(tester.getRect(pages), originalBounds);
      expect(overlayInset(), fraction);
      ui.openSearchDrawer();
      await tester.pumpAndSettle();
      expect(tester.getRect(pages), originalBounds);
      expect(overlayInset(), 0, reason: 'the panel covers the whole page');
      ui.closeSearchDrawer();
      await tester.pumpAndSettle();
      expect(overlayInset(), fraction);

      tester.view.physicalSize = const Size(844, 390);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.getSize(pages).height, 390);
      expect(tester.state(pages), same(originalState));
      final landscapeFraction =
          tester.getSize(find.byType(ReaderSearchNavigationBar)).height / 390;
      expect(overlayInset(), landscapeFraction);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('End search'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderSearchNavigationBar), findsNothing);
      expect(tester.getRect(pages), originalBounds);
      expect(tester.state(pages), same(originalState));
      expect(overlayInset(), 0);
      expect(tester.takeException(), isNull);
      // The reader saves its place after a pause.
      await tester.pump(const Duration(seconds: 1));
      await unmountUi(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'article search overlays the scrolling text and never resizes it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app.widget);
      await tapUi(tester, find.text(ReadingFixture.articleTitle));
      final text = find.byType(TextScrollView);
      await waitForUi(
        tester,
        () =>
            text.evaluate().isNotEmpty &&
            tester.widget<TextScrollView>(text).controller.position != null,
        description: 'article laid out',
      );
      final originalState = tester.state(text);
      final originalBounds = tester.getRect(text);
      final readerContext = tester.element(text);
      final ui = readerContext.read<ReaderUiCubit>();
      ui.showChrome();
      await tester.pumpAndSettle();
      expect(tester.getRect(text), originalBounds);
      ui.hideChrome();
      await tester.pumpAndSettle();
      final search = readerContext.read<ReaderSearchCubit>();
      search.recentQuerySelected(
        'vision',
        searchBook: (_) => Stream.fromIterable([
          const ReaderSearchResults(
            requestId: 1,
            results: [
              ReaderSearchResult(
                cfi: 'first',
                excerpt: ReaderSearchExcerpt(match: 'vision'),
              ),
            ],
          ),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 50));
      search.resultSelected(
        index: 0,
        returnLocation: const ReaderSearchLocation(
          cfi: 'origin',
          fraction: 0.12,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderSearchNavigationBar), findsOneWidget);
      expect(tester.getRect(text), originalBounds);
      expect(tester.state(text), same(originalState));

      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      expect(tester.getSize(text).height, 390);
      expect(tester.state(text), same(originalState));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('End search'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderSearchNavigationBar), findsNothing);
      expect(tester.getRect(text), originalBounds);
      expect(tester.state(text), same(originalState));
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    },
  );
}
