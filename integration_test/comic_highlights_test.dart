import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_image_highlight_preview.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart' show FixedPagesView;

import '../test/support/comic_fixture.dart';
import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'comic bookmarks restore by icon and saved areas navigate without text actions',
    (tester) async {
      final app = await UiTestApp.create(withBook: false);
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
      await waitForFixedPage(tester);
      final pages = find.byType(FixedPagesView);
      final context = tester.element(pages);
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
      // Rows past the sheet are not built, nor their previews loaded.
      final previews = find.byType(ReaderImageHighlightPreview);
      await waitForUi(
        tester,
        () =>
            previews.evaluate().isNotEmpty &&
            find
                .descendant(of: previews, matching: find.byIcon(AppIcons.book))
                .evaluate()
                .isEmpty,
        description: 'native cropped previews',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Page highlight'), findsNothing);
      final rows = find.byType(ReaderHighlightListTile);
      final shown = rows.evaluate().length;
      expect(shown, greaterThan(1));
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
      expect(rows, findsNWidgets(shown));
      // A row tap uses the existing page anchor. It does not change the saved area
      // or automatically zoom, and works without the old standalone arrow.
      await tester.ensureVisible(find.text('A quiet afternoon.'));
      await tester.pump(const Duration(milliseconds: 350));
      await tapUi(tester, find.text('A quiet afternoon.'));
      expect(ui.state.tocDrawerVisible, isFalse);
      await waitForUi(
        tester,
        () => tester.widget<FixedPagesView>(pages).controller.page == 2,
        description: 'the saved area\'s page 3',
      );
      await tester.pump(const Duration(milliseconds: 400));
      if (Platform.isAndroid) {
        await captureAndroidScreenshot('comic-highlight-destination');
      } else {
        await binding.takeScreenshot('comic-highlight-destination');
      }
      expect(tester.takeException(), isNull);
      // The reader saves its place after a pause.
      await tester.pump(const Duration(seconds: 1));
      await unmountUi(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
