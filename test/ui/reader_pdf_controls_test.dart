import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/pdf_fixture.dart';
import '../support/reader_test_platform.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// The PDF reader wires its page controls end to end: Appearance sheet,
/// WebView style and the Contents page grid.
void main() {
  testWidgets(
    'PDF page appearance reaches the WebView and Contents lists pages',
    (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      ))!;
      addTearDown(app.dispose);
      final book = (await tester.runAsync(() => addPdfFixture(app)))!;
      final previous = InAppWebViewPlatform.instance;
      final platform = ReaderTestPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        if (previous != null) InAppWebViewPlatform.instance = previous;
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: ReaderScreen(
            sourceId: book.id,
            serverBaseUri: Uri.parse('http://127.0.0.1:49152'),
            bookRepository: app.bookRepository,
            highlightRepository: app.highlightRepository,
            preferencesService: app.preferencesService,
            screenControlService: app.screenControlService,
            textActions: const [],
            initialSource: book,
          ),
        ),
      );
      await waitForUi(
        tester,
        () => platform.views.any(
          (view) =>
              view.created && view.controller.handlers.containsKey('onLoadEnd'),
        ),
        description: 'WebView bridge',
      );
      final bridge = platform.views
          .firstWhere((view) => view.created)
          .controller;
      bridge.handlers['onLoadEnd']!([]);
      await tester.pump();

      FoliateStyle style() => tester
          .widget<BookReaderWebView>(find.byType(BookReaderWebView))
          .foliateStyle;
      expect(style().cropPageMargins, isTrue, reason: 'trimmed by default');
      expect(style().pageColors, FoliatePageColors.theme);
      expect(
        tester
            .widget<BookReaderWebView>(find.byType(BookReaderWebView))
            .zoomablePages,
        isTrue,
      );

      final context = tester.element(find.byType(BookReaderWebView));
      final l10n = context.l10n;
      final ui = context.read<ReaderUiCubit>();
      ui.showChrome();
      await tester.pumpAndSettle();
      await tapUi(tester, find.byTooltip(l10n.readerAppearanceTitle));
      expect(find.text(l10n.readerPdfMargins), findsOneWidget);
      expect(find.text(l10n.readerFontSize), findsNothing);

      bridge.scripts.clear();
      await tapUi(tester, find.text(l10n.readerPdfMarginsWhole));
      await tapUi(tester, find.text(l10n.readerPdfPageColorsOriginal));
      expect(style().cropPageMargins, isFalse);
      expect(style().pageColors, FoliatePageColors.original);
      expect(
        bridge.scripts.where(
          (script) =>
              script.contains('changeStyle') &&
              script.contains('"cropPageMargins":false') &&
              script.contains('"pageColors":"original"'),
        ),
        isNotEmpty,
        reason: 'the WebView receives the new page options',
      );
      expect(
        context.read<ReaderAppearanceCubit>().state.sourceOverride.pageColors,
        ReaderPageColors.original,
      );

      Navigator.of(tester.element(find.text(l10n.readerPdfMargins))).pop();
      await tester.pumpAndSettle();
      bridge.handlers['onDocumentFeatures']!([
        {'format': 'pdf', 'hasToc': false, 'pageCount': 6},
      ]);
      await tester.pump();
      ui.openTocDrawer();
      await tester.pumpAndSettle();
      // Chapters stays first even without an outline; Pages follows it.
      expect(find.byType(ReaderPageGrid), findsNothing);
      await tapUi(tester, find.text(l10n.readerPages));
      expect(find.byType(ReaderPageGrid), findsOneWidget);
      await tapUi(tester, find.text(l10n.readerPageNumber(2)));
      expect(
        bridge.scripts.any((script) => script.contains('goToSectionIndex(1)')),
        isTrue,
      );
      expect(ui.state.tocDrawerVisible, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
