import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_page_thumbnail_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/pdf_fixture.dart';
import '../support/reader_test_platform.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('PDF contents with chapters and pages ${profile.name}', (
      tester,
    ) async {
      final app = (await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      ))!;
      addTearDown(app.dispose);
      final book = (await tester.runAsync(() => addPdfFixture(app)))!;
      final thumbnails = (await tester.runAsync(
        () => Future.wait([
          for (var i = 0; i < 4; i++) pdfPageThumbnailFixture(i),
        ]),
      ))!;
      final previous = InAppWebViewPlatform.instance;
      final platform = ReaderTestPlatform(
        onAsyncJavaScript: (body, args) async => CallAsyncJavaScriptResult(
          value:
              'data:image/jpeg;base64,'
              '${base64Encode(thumbnails[(args['index'] as int) % 4])}',
        ),
      );
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        if (previous != null) InAppWebViewPlatform.instance = previous;
      });
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => ReaderScreen(
          sourceId: book.id,
          serverBaseUri: Uri.parse('http://127.0.0.1:49152'),
          bookRepository: app.bookRepository,
          highlightRepository: app.highlightRepository,
          preferencesService: app.preferencesService,
          screenControlService: app.screenControlService,
          textActions: const [],
          initialSource: book,
        ),
        surfaceSize: profile == VisualProfile.tabletRtl
            ? const Size(390, 844)
            : null,
      );
      await waitForUi(
        tester,
        () => platform.views.any(
          (v) => v.created && v.controller.handlers.containsKey('onLoadEnd'),
        ),
        description: 'reader bridge',
      );
      final bridge = platform.views.firstWhere((v) => v.created).controller;
      bridge.handlers['onLoadEnd']!([]);
      bridge.handlers['onDocumentFeatures']!([
        {'format': 'pdf', 'hasToc': true, 'pageCount': 40},
      ]);
      bridge.handlers['onRelocated']!([
        {
          'cfi': 'epubcfi(/6/6!)',
          'percentage': 0.05,
          'chapterCurrentPage': 2,
          'chapterTotalPages': 40,
        },
      ]);
      final context = tester.element(find.byType(BookReaderWebView));
      final bloc = context.read<ReaderBloc>();
      bloc.add(
        const ReaderTocUpdated(
          items: [
            ReaderTocItem(label: 'Introduction', href: '[1]', level: 1),
            ReaderTocItem(label: 'Getting started', href: '[2]', level: 1),
            ReaderTocItem(label: 'Solution lifecycle', href: '[3]', level: 1),
          ],
        ),
      );
      await waitForUi(
        tester,
        () =>
            bloc.state.tocItems.length == 3 &&
            bloc.state.documentFeatures?.pageCount == 40,
        description: 'outline and page count',
      );
      final ui = context.read<ReaderUiCubit>();
      final l10n = context.l10n;
      ui.openTocDrawer();
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'pdf-contents-chapters');

      await tester.ensureVisible(find.text(l10n.readerPages));
      await tapUi(tester, find.text(l10n.readerPages));
      await tester.pumpAndSettle();
      final grid = find.byType(ReaderPageGrid);
      expect(grid, findsOneWidget);
      final cubit = tester
          .element(find.descendant(of: grid, matching: find.byType(GridView)))
          .read<ReaderPageThumbnailCubit>();
      await waitForUi(
        tester,
        () => cubit.state.values.whereType<ImageProvider>().isNotEmpty,
        description: 'thumbnails',
      );
      // The bridge decodes base64 into new byte identities; precache the
      // providers the cubit holds.
      await tester.runAsync(() async {
        for (final image in cubit.state.values) {
          if (image != null) {
            await precacheImage(image, tester.element(grid));
          }
        }
      });
      await tester.pumpAndSettle();
      // The page on screen is scrolled into view; its label may sit below a
      // short large-text sheet, so check the tile itself.
      final currentTile = find.ancestor(
        of: find.text(l10n.readerPageNumber(3)),
        matching: find.byType(Material),
      );
      expect(currentTile.first.hitTestable(), findsOneWidget);
      await expectUiGolden(tester, profile, 'pdf-contents-pages');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, tags: ['golden']);
  }
}
