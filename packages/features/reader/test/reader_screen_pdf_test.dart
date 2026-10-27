import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:vellum/testing.dart';
import 'package:vellum/vellum.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

const fixtures = '../../vellum/test/fixtures/pdf';

void main() {
  late Directory tempDir;
  late PreferencesService preferences;
  late FakeBookRepository books;
  late FakeHighlightRepository highlights;
  late Book pdf;

  setUpAll(preparePdfEngineForTests);

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    tempDir = Directory.systemTemp.createTempSync('reader_pdf_');
    final path = '${tempDir.path}/book.pdf';
    File(path).writeAsBytesSync(
      File('$fixtures/text_outline.pdf').readAsBytesSync(),
    );
    books = FakeBookRepository();
    highlights = FakeHighlightRepository();
    pdf = Book(
      id: 'pdf-1',
      title: 'Vellum Fixture',
      filePath: path,
      format: BookFormat.pdf,
      addedAt: DateTime(2026, 1, 1),
    );
    books.seedBook(pdf);
  });

  tearDown(() {
    preferences.dispose();
    tempDir.deleteSync(recursive: true);
  });

  Finder frames() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is FixedPagePainter,
  );

  /// pdfium renders on the real event loop; alternate until the page and
  /// its text layer are there.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        final overlays = find.byType(PdfTextOverlay).evaluate();
        if (frames().evaluate().isNotEmpty &&
            overlays.any((e) => (e.widget as PdfTextOverlay).layer != null)) {
          break;
        }
      }
    });
    await tester.pump();
  }

  Future<void> pumpReader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: ReaderScreen(
          sourceId: pdf.id,
          serverBaseUri: Uri.parse('http://127.0.0.1:8080'),
          bookRepository: books,
          highlightRepository: highlights,
          preferencesService: preferences,
          screenControlService: _ScreenControlService(),
          textActions: [_FakeHighlightAction()],
          nativeFormats: const {BookFormat.pdf},
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  ReadflexLocalizations l10n(WidgetTester tester) =>
      tester.element(find.byType(FixedPagesView)).l10n;

  Future<Finder> chromeControl(WidgetTester tester, String tooltip) async {
    var control = find.byTooltip(tooltip).hitTestable();
    if (control.evaluate().isEmpty) {
      await tester.tapAt(const Offset(195, 422));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      control = find.byTooltip(tooltip).hitTestable();
    }
    expect(control, findsOneWidget);
    return control;
  }

  testWidgets('opens a PDF on the native engine with its outline', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(FixedPagesView), findsOneWidget);
    expect(find.byType(BookReaderWebView), findsNothing);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(1)),
      findsOneWidget,
    );
    final bloc = tester.element(find.byType(FixedPagesView)).read<ReaderBloc>();
    expect(bloc.state.tocItems.map((i) => i.label), [
      'Chapter One',
      'Section 1.1',
      'Chapter Two',
    ]);
    expect(bloc.state.tocItems[1].level, 1);
    expect(bloc.state.tocItems[1].href, fakeCfiFromIndex(1));
    expect(bloc.state.documentFeatures?.format, 'pdf');
    expect(bloc.state.documentFeatures?.pageCount, 3);
    expect(bloc.state.documentFeatures?.hasSearchableText, isTrue);
    expect(bloc.state.chapterTitle, 'Chapter One');

    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, 'epubcfi(/6/2)');
    expect(books.updatedBook?.readingProgress, closeTo(1 / 3, 1e-9));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a long press selects a word with its sentence as context', (
    tester,
  ) async {
    await pumpReader(tester);
    // "Hello page one" sits 72 pt from the left, 92 pt from the top of a
    // 612×792 page fitted to 390 px wide and centred in 844 px; "page"
    // starts about 61 pt into the line.
    const scale = 390 / 612;
    const top = (844 - 792 * scale) / 2;
    final point = Offset(
      (72 + 85) * scale,
      top + (792 - 700 - 8) * scale,
    );
    final gesture = await tester.startGesture(point);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pump();

    final selection = tester
        .element(find.byType(FixedPagesView))
        .read<ReaderSelectionCubit>()
        .state;
    expect(selection.hasSelection, isTrue);
    expect(selection.selectedText, 'page');
    expect(selection.contextText, 'Hello page one');
    expect(selection.markedContextText, 'Hello [[page]] one');
    expect(selection.cfiRange, pdfTextCfi(0, const PdfTextRange(6, 10)));
    expect(selection.position, isNotNull);
    expect(selection.position!.top, greaterThan(0));
    expect(selection.position!.bottom, lessThan(0.5));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a tap outside the selection clears it and its popup', (
    tester,
  ) async {
    await pumpReader(tester);
    const scale = 390 / 612;
    const top = (844 - 792 * scale) / 2;
    final word = Offset((72 + 85) * scale, top + (792 - 700 - 8) * scale);
    final gesture = await tester.startGesture(word);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderHighlightControls), findsOneWidget);
    // The popup previews its colour from its first build; the overlay must
    // take that without a build-phase error.
    expect(tester.takeException(), isNull);

    await tester.tapAt(Offset(300, top + 400));
    await tester.pumpAndSettle();
    final selection = tester
        .element(find.byType(FixedPagesView))
        .read<ReaderSelectionCubit>()
        .state;
    expect(selection.hasSelection, isFalse);
    expect(find.byType(ReaderHighlightControls), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('switching to a dark theme recolours the page on screen', (
    tester,
  ) async {
    await pumpReader(tester);
    FixedPagePainter painter() => tester
        .widgetList<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is FixedPagePainter,
          ),
        )
        .map((w) => w.painter! as FixedPagePainter)
        .first;
    expect(painter().colors?.dark, isFalse, reason: 'paper tints, no invert');

    final element = tester.element(find.byType(FixedPagesView));
    await element.read<ReaderAppearanceCubit>().setTheme('night');
    await tester.pump();
    await tester.pump();
    expect(painter().colors?.dark, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the chrome bookmark button bookmarks the page on screen', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = l10n(tester);
    await tester.tap(await chromeControl(tester, strings.readerBookmark));
    await tester.pumpAndSettle();
    final saved = books.bookmarksBySourceId[pdf.id]!.single;
    expect(saved.cfi, 'epubcfi(/6/2)');
    expect(saved.anchorSectionIndex, 0);
    expect(saved.content, 'Page 1 / 3');
    expect(
      find.byTooltip(strings.readerRemoveBookmark).hitTestable(),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a swipe turns the page and persists the position', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(2)),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, 'epubcfi(/6/4)');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _ScreenControlService implements ScreenControlService {
  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}

  @override
  Future<double?> readApplicationBrightness() async => 0.5;

  @override
  Future<void> setApplicationBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationBrightness() async {}
}

/// The highlight action, which the selection popup needs to appear.
class _FakeHighlightAction extends ColorHighlightTextAction {
  @override
  String get label => 'Highlight';

  @override
  IconData get icon => Icons.brush;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {}

  @override
  Future<void> onExecuteWithColor(
    BuildContext context,
    TextSelectionContext selection,
    HighlightColor color,
  ) async {}
}
