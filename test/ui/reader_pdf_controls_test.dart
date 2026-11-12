import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart' show FixedPagesView;
import 'package:pagecraft/testing.dart' show preparePdfEngineForTests;

import '../support/pdf_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// The PDF reader wires its page controls end to end: Appearance sheet,
/// the engine's page view and the Contents page grid.
void main() {
  setUpAll(preparePdfEngineForTests);
  testWidgets('PDF page appearance reaches the pages and Contents lists them', (
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
    // A dark paper, where theme colours recolour the page.
    await tester.runAsync(
      () => app.preferencesService.update(
        (p) => p.copyWith(readerThemeId: ReaderThemePreset.night.id),
      ),
    );
    final book = (await tester.runAsync(() => addPdfFixture(app)))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: readflexLocalizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: ReaderScreen(
          sourceId: book.id,
          bookRepository: app.bookRepository,
          highlightRepository: app.highlightRepository,
          preferencesService: app.preferencesService,
          screenControlService: app.screenControlService,
          textActions: const [],
          initialSource: book,
        ),
      ),
    );
    final pages = find.byType(FixedPagesView);
    await waitForUi(
      tester,
      () => pages.evaluate().isNotEmpty,
      description: 'PDF pages',
      timeout: const Duration(seconds: 30),
    );
    FixedPagesView view() => tester.widget<FixedPagesView>(pages);
    await waitForFixedPage(tester);
    expect(view().visibleRectOf, isNotNull, reason: 'trimmed by default');
    expect(view().pageColors, isNotNull, reason: 'theme colours by default');

    final context = tester.element(pages);
    final l10n = context.l10n;
    final ui = context.read<ReaderUiCubit>();
    ui.showChrome();
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.readerAppearanceTitle));
    expect(find.text(l10n.readerPdfMargins), findsOneWidget);
    expect(find.text(l10n.readerFontSize), findsNothing);

    await tapUi(tester, find.text(l10n.readerPdfMarginsWhole));
    await tapUi(tester, find.text(l10n.readerPdfPageColorsOriginal));
    expect(view().visibleRectOf, isNull);
    expect(view().pageColors, isNull);
    expect(
      context.read<ReaderAppearanceCubit>().state.sourceOverride.pageColors,
      ReaderPageColors.original,
    );

    Navigator.of(tester.element(find.text(l10n.readerPdfMargins))).pop();
    await tester.pumpAndSettle();
    final bloc = context.read<ReaderBloc>();
    await waitForUi(
      tester,
      () => bloc.state.documentFeatures?.pageCount == 6,
      description: 'the page count',
    );
    expect(bloc.state.documentFeatures?.hasTableOfContents, isFalse);
    ui.openTocDrawer();
    await tester.pumpAndSettle();
    // Chapters stays first even without an outline; Pages follows it.
    expect(find.byType(ReaderPageGrid), findsNothing);
    await tapUi(tester, find.text(l10n.readerPages));
    expect(find.byType(ReaderPageGrid), findsOneWidget);
    await tapUi(tester, find.text(l10n.readerPageNumber(2)));
    expect(ui.state.tocDrawerVisible, isFalse);
    await waitForUi(
      tester,
      () => bloc.state.document?.currentCfi == 'epubcfi(/6/4)',
      description: 'the second page',
    );
    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));
    await unmountUi(tester);
  });
}
