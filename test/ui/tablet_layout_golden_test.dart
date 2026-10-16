import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_selection_bar.dart';
import 'package:local_storage/local_storage.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// Wide windows: a 13-inch iPad in both orientations. Phone profiles keep
/// their own goldens unchanged.
void main() {
  setUpAll(loadUiFonts);
  const portrait = Size(1032, 1376);
  const landscape = Size(1376, 1032);

  const titles = [
    ('The Left Hand of Darkness', 'Ursula K. Le Guin'),
    ('Middlemarch', 'George Eliot'),
    (
      'A Very Long Title About the Quiet Art of Reading Slowly in Winter',
      'An Author With a Long Name',
    ),
    ('Dune', 'Frank Herbert'),
    ('Kafka on the Shore', 'Haruki Murakami'),
    ('Pride and Prejudice', 'Jane Austen'),
    ('The Name of the Rose', 'Umberto Eco'),
    ('War and Peace', 'Leo Tolstoy'),
    ('Invisible Cities', 'Italo Calvino'),
  ];

  /// A library with a book in progress, so Continue reading sits on top.
  Future<UiTestApp> library({required String layout}) async {
    final app = await UiTestApp.create(withBook: false);
    for (var i = 0; i < titles.length; i++) {
      await app.database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: 'tablet-book-$i',
          title: titles[i].$1,
          author: Value(titles[i].$2),
          filePath: 'book.fb2',
          format: 'fb2',
          addedAt: DateTime(2026, 1, i + 1).toIso8601String(),
          readingProgress: Value(i == 0 ? 0.42 : 0),
          lastOpenedAt: Value(
            i == 0 ? DateTime(2026, 10).toIso8601String() : null,
          ),
        ),
      );
    }
    await app.preferencesService.update(
      (p) => p.copyWith(libraryLayoutMode: layout),
    );
    return app;
  }

  Widget libraryScreen(UiTestApp app) => LibraryScreen(
    bookRepository: app.bookRepository,
    articleRepository: app.articleRepository,
    collectionRepository: app.collectionRepository,
    preferencesService: app.preferencesService,
    onSourcePressed: (_, {onSourceOpened, onReadingPositionSaved}) async {},
    onAddPressed:
        ({required onImported, entry = LibraryImportEntry.menu}) async {},
  );

  Future<void> waitForBooks(WidgetTester tester) async {
    await waitForUi(
      tester,
      () => find.text('Middlemarch').evaluate().isNotEmpty,
      description: 'library books',
    );
    await tester.pumpAndSettle();
  }

  for (final (profile, window, name) in [
    (VisualProfile.phone, portrait, 'portrait'),
    (VisualProfile.phone, landscape, 'landscape'),
    (VisualProfile.dark, landscape, 'landscape'),
    (VisualProfile.tabletRtl, landscape, 'landscape'),
  ]) {
    testWidgets('two-column library list ${profile.name} $name', (
      tester,
    ) async {
      final app = (await tester.runAsync(() => library(layout: 'list')))!;
      addTearDown(app.dispose);
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => libraryScreen(app),
        surfaceSize: window,
      );
      await waitForBooks(tester);
      await expectUiGolden(tester, profile, 'tablet-library-list-$name');
      await unmountUi(tester);
    });
  }

  for (final (window, name) in [
    (portrait, 'portrait'),
    (landscape, 'landscape'),
  ]) {
    testWidgets('library grid adds columns $name', (tester) async {
      final app = (await tester.runAsync(() => library(layout: 'grid')))!;
      addTearDown(app.dispose);
      await pumpGoldenSurface(
        tester,
        VisualProfile.phone,
        (_) => libraryScreen(app),
        surfaceSize: window,
      );
      await waitForBooks(tester);
      await expectUiGolden(
        tester,
        VisualProfile.phone,
        'tablet-library-grid-$name',
      );
      await unmountUi(tester);
    });
  }

  for (final (profile, window, name) in [
    (VisualProfile.phone, portrait, 'portrait'),
    (VisualProfile.tabletRtl, landscape, 'landscape'),
  ]) {
    testWidgets('selection bar keeps one row ${profile.name} $name', (
      tester,
    ) async {
      final app = (await tester.runAsync(() => library(layout: 'grid')))!;
      addTearDown(app.dispose);
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => libraryScreen(app),
        surfaceSize: window,
      );
      await waitForBooks(tester);
      await tester.longPress(find.text('Middlemarch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dune'));
      await tester.pumpAndSettle();
      expect(find.byType(LibrarySelectionBar), findsOneWidget);
      await expectUiGolden(tester, profile, 'tablet-library-selection-$name');
      await unmountUi(tester);
    });
  }

  testWidgets('empty library keeps the onboarding column', (tester) async {
    final app = (await tester.runAsync(
      () => UiTestApp.create(withBook: false),
    ))!;
    addTearDown(app.dispose);
    await pumpGoldenSurface(
      tester,
      VisualProfile.phone,
      (_) => libraryScreen(app),
      surfaceSize: portrait,
    );
    await waitForUi(
      tester,
      () => find
          .byKey(const ValueKey('libraryEmptyUploadFile'))
          .evaluate()
          .isNotEmpty,
      description: 'empty library',
    );
    await tester.pumpAndSettle();
    await expectUiGolden(tester, VisualProfile.phone, 'tablet-library-empty');
    await unmountUi(tester);
  });

  for (final profile in [VisualProfile.phone, VisualProfile.dark]) {
    testWidgets('appearance columns row ${profile.name}', (tester) async {
      final app = (await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      ))!;
      addTearDown(app.dispose);
      final cubit = ReaderAppearanceCubit(
        preferencesService: app.preferencesService,
        sourceId: 'appearance-fixture',
      );
      addTearDown(cubit.close);
      late BuildContext sheetContext;
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              sheetContext = context;
              return const Scaffold();
            },
          ),
        ),
        surfaceSize: portrait,
      );
      showReaderAppearanceSheet(sheetContext, showColumnControls: true);
      await tester.pumpAndSettle();
      final columns = find.byKey(const ValueKey('reader-columns-control'));
      await tester.ensureVisible(columns);
      await tester.pumpAndSettle();
      expect(columns.hitTestable(), findsOneWidget);
      expect(find.text(sheetContext.l10n.readerColumns), findsOneWidget);
      await expectUiGolden(tester, profile, 'tablet-reader-appearance-columns');
      Navigator.of(sheetContext).pop();
      await tester.pumpAndSettle();
    });
  }
}
