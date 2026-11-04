import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart' show FixedPagesView;
import 'package:pagecraft/testing.dart' show preparePdfEngineForTests;

import '../support/pdf_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  setUpAll(preparePdfEngineForTests);
  for (final profile in VisualProfile.values) {
    testWidgets('PDF contents with chapters and pages ${profile.name}', (
      tester,
    ) async {
      final app = (await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      ))!;
      addTearDown(app.dispose);
      // Margin crops are measured off the fake clock; whole pages keep the
      // page under the sheet the same in every run.
      await tester.runAsync(
        () => app.preferencesService.update(
          (p) => p.copyWith(readerTrimPageMargins: false),
        ),
      );
      final book = (await tester.runAsync(
        () => addPdfFixture(
          app,
          pages: 40,
          outline: const [
            ('Introduction', 0),
            ('Getting started', 1),
            ('Solution lifecycle', 2),
          ],
        ),
      ))!;
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => ReaderScreen(
          sourceId: book.id,
          bookRepository: app.bookRepository,
          highlightRepository: app.highlightRepository,
          preferencesService: app.preferencesService,
          screenControlService: app.screenControlService,
          textActions: const [],
          initialSource: book,
          // The third page is the one being read.
          initialCfi: 'epubcfi(/6/6)',
        ),
        surfaceSize: profile == VisualProfile.tabletRtl
            ? const Size(390, 844)
            : null,
      );
      await waitForUi(
        tester,
        () => find.byType(FixedPagesView).evaluate().isNotEmpty,
        description: 'PDF pages',
        timeout: const Duration(seconds: 30),
      );
      final context = tester.element(find.byType(FixedPagesView));
      final bloc = context.read<ReaderBloc>();
      await waitForUi(
        tester,
        () =>
            bloc.state.tocItems.length == 3 &&
            bloc.state.documentFeatures?.pageCount == 40 &&
            bloc.state.document?.currentCfi == 'epubcfi(/6/6)',
        description: 'outline, page count and the third page',
        timeout: const Duration(seconds: 30),
      );
      await waitForFixedPage(tester);
      final ui = context.read<ReaderUiCubit>();
      final l10n = context.l10n;
      ui.openTocDrawer();
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'pdf-contents-chapters');

      await tester.ensureVisible(find.text(l10n.readerPages));
      await tapUi(tester, find.text(l10n.readerPages));
      final grid = find.byType(ReaderPageGrid);
      expect(grid, findsOneWidget);
      // pdfium renders the previews off the fake clock.
      final images = find.descendant(of: grid, matching: find.byType(RawImage));
      await waitForUi(
        tester,
        () =>
            images.evaluate().isNotEmpty &&
            images.evaluate().every(
              (e) => (e.widget as RawImage).image != null,
            ),
        description: 'page previews',
        timeout: const Duration(seconds: 30),
      );
      // The page on screen is scrolled into view; its label may sit below a
      // short large-text sheet, so check the tile itself.
      final currentTile = find.ancestor(
        of: find.text(l10n.readerPageNumber(3)),
        matching: find.byType(Material),
      );
      expect(currentTile.first.hitTestable(), findsOneWidget);
      await expectUiGolden(tester, profile, 'pdf-contents-pages');
      expect(tester.takeException(), isNull);
      // The reader saves its place after a pause.
      await tester.pump(const Duration(seconds: 1));
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
