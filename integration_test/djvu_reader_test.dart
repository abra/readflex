import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:integration_test/integration_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:pagecraft/djvu.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import '../packages/pagecraft/test/formats/djvu/djvu_fixture.dart';
import '../test/support/device_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Exercises the packaged C++ decoder, production import/repositories and the
/// Reader on an original fixture. It never reads user books or backend keys.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DjVu imports, renders, searches and restores its saved page', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final book = await tester.runAsync(() async {
      final file = File('${app.directory.path}/original.djvu');
      await file.writeAsBytes(djvuFixtureBytes());
      return importBookFile(
        sourceFile: file,
        bookRepository: app.bookRepository,
        logger: app.logger,
      );
    });
    expect(book, isNotNull);
    expect(book!.format, BookFormat.djvu);
    expect(book.title, 'Pagecraft DjVu fixture');
    expect(book.author, 'Readflex Tests');
    expect(book.coverImagePath, isNotNull);

    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    final source = find.byWidgetPredicate(
      (widget) =>
          (widget is LibraryContinueReadingCard &&
              widget.source.id == book.id) ||
          widget.key == ValueKey('library-grid-${book.id}') ||
          widget.key == ValueKey('library-row-${book.id}'),
    );
    await tapUi(tester, source);
    await waitForFixedPage(tester);

    final pages = find.byType(FixedPagesView);
    FixedPagesView view() => tester.widget<FixedPagesView>(pages);
    final readerContext = tester.element(pages);
    final bloc = readerContext.read<ReaderBloc>();
    final ui = readerContext.read<ReaderUiCubit>();
    final l10n = readerContext.l10n;
    expect(view().pages, isA<DjvuPages>());
    expect(view().controller.pageCount, 3);
    expect(bloc.state.status, ReaderStatus.ready);
    await takeDeviceScreenshot(binding, 'djvu-open');

    ui.hideChrome();
    await tester.pump(const Duration(milliseconds: 400));
    await waitForUi(
      tester,
      () => find.byType(DjvuTextOverlay).evaluate().any((element) {
        final overlay = element.widget as DjvuTextOverlay;
        return overlay.enabled &&
            overlay.page == view().controller.page &&
            overlay.layer?.words.any((word) => word.text == 'Quiet') == true;
      }),
      description: 'DjVu hidden-text word zones',
    );
    final overlayElement = find.byType(DjvuTextOverlay).evaluate().firstWhere((
      element,
    ) {
      final overlay = element.widget as DjvuTextOverlay;
      return overlay.enabled &&
          overlay.page == view().controller.page &&
          overlay.layer?.words.any((word) => word.text == 'Quiet') == true;
    });
    final overlay = overlayElement.widget as DjvuTextOverlay;
    final word = overlay.layer!.words.firstWhere(
      (word) => word.text == 'Quiet',
    );
    final scale = overlay.imageRect.width / overlay.pageWidth;
    final position = (overlayElement.renderObject! as RenderBox).localToGlobal(
      overlay.imageRect.topLeft + word.box.center * scale,
    );
    await tester.longPressAt(position);
    final selection = readerContext.read<ReaderSelectionCubit>();
    await waitForUi(
      tester,
      () =>
          selection.state.hasSelection &&
          selection.state.selectedText == 'Quiet',
      description: 'DjVu word selected with its reader context panel',
    );
    expect(selection.state.cfiRange, contains('pagecraft-djvu'));
    expect(selection.state.markedContextText, contains('[[Quiet]]'));
    await takeDeviceScreenshot(binding, 'djvu-selection');
    overlay.selection.clear();
    view().controller.lockInput(false);
    selection.deselect();
    await tester.pump(const Duration(milliseconds: 400));

    // Search uses the stored Unicode text, not OCR or an image approximation.
    ui.showChrome();
    await tester.pump(const Duration(milliseconds: 400));
    await tapUi(tester, find.byTooltip(l10n.readerSearchAction).first);
    final field = find.byType(TextField).hitTestable();
    await tester.enterText(field, 'continues');
    final search = tester.element(field).read<ReaderSearchCubit>();
    await waitForUi(
      tester,
      () => search.state.query == 'continues' && !search.state.isLoading,
      description: 'DjVu text search completed',
      timeout: const Duration(seconds: 30),
    );
    expect(search.state.results, hasLength(1));
    await tapUi(tester, find.byType(ReaderSearchResultTile).first);
    await waitForUi(
      tester,
      () => view().controller.page == 1,
      description: 'DjVu search result opens page 2',
    );
    await takeDeviceScreenshot(binding, 'djvu-search-result');
    search.reset();

    // The same fixed-page preview queue decodes thumbnails on demand.
    ui.openTocDrawer();
    await tester.pump(const Duration(milliseconds: 400));
    await tapUi(tester, find.text(l10n.readerPages));
    final previews = find.descendant(
      of: find.byType(ReaderPageGrid),
      matching: find.byType(RawImage),
    );
    await waitForUi(
      tester,
      () => previews.evaluate().any(
        (element) => (element.widget as RawImage).image != null,
      ),
      description: 'DjVu page thumbnails',
    );
    await takeDeviceScreenshot(binding, 'djvu-previews');
    await dismissSheet(tester);

    // Closing drains the debounced position write; reopening restores it.
    ui.showChrome();
    await tester.pump(const Duration(milliseconds: 400));
    await tapUi(tester, find.byTooltip(l10n.readerBookmark));
    await waitForUi(
      tester,
      () => bloc.state.bookmarks.isNotEmpty,
      description: 'DjVu bookmark saved',
    );
    await tapUi(tester, find.byTooltip(l10n.readerBack));
    await takeDeviceScreenshot(binding, 'djvu-library-return');
    await waitForUi(
      tester,
      () => source.hitTestable().evaluate().isNotEmpty,
      description: 'Library after closing DjVu',
    );
    final saved = await tester.runAsync(
      () => app.bookRepository.getBookById(book.id),
    );
    expect(saved!.currentCfi, isNotNull);
    await tapUi(tester, source);
    await waitForFixedPage(tester);
    await waitForUi(
      tester,
      () => view().controller.page == 1,
      description: 'DjVu saved page restored',
    );
    await takeDeviceScreenshot(binding, 'djvu-restored');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
