import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_comic_thumbnail_cubit.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_image_highlight_preview.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../test/support/comic_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'comic bookmarks restore by icon and saved areas navigate without text actions',
    (tester) async {
      final app = await UiTestApp.create(withBook: false, nativeReader: true);
      addTearDown(app.dispose);
      final comic = await addComicFixture(app);
      for (var index = 0; index < 3; index++) {
        await app.highlightRepository.addImageAreaHighlight(
          sourceId: comic.id,
          sourceType: SourceType.book,
          pageIndex: index == 0 ? 0 : 2,
          x: .04,
          y: index == 1 ? .52 : .03,
          width: .92,
          height: .45,
          chapterTitle: index == 0 ? 'page-0.png' : 'page-2.png',
          note: index == 0
              ? null
              : index == 1
              ? 'The conversation continues.'
              : 'A quiet afternoon.',
          color: HighlightColor.values[index],
        );
      }
      tester.platformDispatcher.defaultRouteNameTestValue = '/';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(app.widget);
      await tapUi(tester, find.byKey(ValueKey('library-grid-${comic.id}')));
      await waitForUi(
        tester,
        () =>
            find.byType(BookReaderWebView).evaluate().isNotEmpty &&
            tester
                .state<BookReaderWebViewState>(find.byType(BookReaderWebView))
                .debugIsReady,
        description: 'comic ready',
        timeout: const Duration(seconds: 45),
      );
      final context = tester.element(find.byType(BookReaderWebView));
      final reader = tester.state<BookReaderWebViewState>(
        find.byType(BookReaderWebView),
      );
      final ui = context.read<ReaderUiCubit>();
      final bloc = context.read<ReaderBloc>();
      ui.showChrome();
      await tester.pump(const Duration(milliseconds: 350));
      await tapUi(tester, find.byTooltip('Bookmark'));
      await waitForUi(
        tester,
        () => bloc.state.bookmarks.length == 1,
        description: 'comic bookmark saved',
      );
      final bookmark = bloc.state.bookmarks.single;
      await tapUi(tester, find.byTooltip('Contents'));
      await tapUi(tester, find.text('Bookmarks'));
      // Undo lands on the trailing gutter, under the drawer's Close glyph.
      final closeIcon = tester.getRect(
        find.byIcon(AppIcons.close).hitTestable(),
      );
      expect(find.byTooltip('Delete bookmark'), findsNothing);
      await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      await waitForUi(
        tester,
        () => bloc.state.bookmarkEdits.removed.length == 1,
        description: 'comic bookmark deleted',
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Undo'), findsNothing);
      final undo = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Undo',
      );
      expect(tester.getSize(undo), const Size.square(48));
      expect(
        tester.getRect(find.byIcon(AppIcons.undo)).center.dx,
        closeTo(closeIcon.center.dx, .01),
      );
      if (Platform.isAndroid) {
        await captureAndroidScreenshot('comic-bookmark-undo');
      } else {
        await binding.takeScreenshot('comic-bookmark-undo');
      }
      await tapUi(tester, find.byTooltip('Undo'));
      await waitForUi(
        tester,
        () =>
            bloc.state.bookmarks.length == 1 &&
            bloc.state.currentPageBookmarked,
        description: 'comic bookmark restored',
      );
      expect(bloc.state.bookmarks.single, bookmark);
      await tapUi(tester, find.text('Highlights'));
      await waitForUi(tester, () {
        final previews = find.byType(ReaderImageHighlightPreview).evaluate();
        return previews.length == 3 &&
            previews.every((element) {
              final page = (element.widget as ReaderImageHighlightPreview)
                  .area
                  .pageIndex;
              return element.read<ReaderComicThumbnailCubit>().state[page] !=
                  null;
            });
      }, description: 'native cropped previews');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Page highlight'), findsNothing);
      final rows = find.byType(ReaderHighlightListTile);
      expect(rows, findsNWidgets(3));
      for (final icon in [
        AppIcons.copy,
        AppIcons.arrowRight,
        AppIcons.arrowLeft,
      ]) {
        expect(
          find.descendant(of: rows, matching: find.byIcon(icon)),
          findsNothing,
        );
      }
      if (Platform.isAndroid) {
        await captureAndroidScreenshot('comic-highlights-list');
      } else {
        await binding.takeScreenshot('comic-highlights-list');
      }
      await tapUi(tester, find.byTooltip('Blue'));
      expect(rows, findsOneWidget);
      await tapUi(tester, find.text('Bookmarks'));
      await tapUi(tester, find.text('Highlights'));
      expect(rows, findsOneWidget);
      await tapUi(tester, find.text('All'));
      expect(rows, findsNWidgets(3));
      // A row tap uses the existing page anchor. It does not change the saved area
      // or automatically zoom, and works without the old standalone arrow.
      await tapUi(tester, find.text('A quiet afternoon.'));
      expect(ui.state.tocDrawerVisible, isFalse);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (await reader.debugController!.evaluateJavascript(
            source: 'reader.view.renderer.index',
          ) !=
          2) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Saved area did not open page 3');
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));
      if (Platform.isAndroid) {
        await captureAndroidScreenshot('comic-highlight-destination');
      } else {
        await binding.takeScreenshot('comic-highlight-destination');
      }
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
