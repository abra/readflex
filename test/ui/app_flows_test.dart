import 'package:connectivity_service/connectivity_service.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_list_view.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

void main() {
  late UiTestApp app;

  setUp(() async {
    app = await UiTestApp.create();
  });
  tearDown(() async => app.dispose());

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app.widget);
    await waitForUi(
      tester,
      () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
      description: 'library contents',
    );
  }

  testWidgets('library search and layout changes do not reload storage', (
    tester,
  ) async {
    await launch(tester);
    final initialReads = app.bookRepository.reads;
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ReadingFixture.bookTitle), findsNothing);
    await tapUi(tester, find.bySemanticsLabel('Clear search'));
    expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
    await tapUi(tester, find.byTooltip('Display options'));
    await tapUi(tester, find.text('List'));
    expect(app.preferencesService.current.libraryLayoutMode, 'list');
    await dismissSheet(tester);
    expect(find.byType(LibraryListView), findsOneWidget);
    expect(
      app.bookRepository.reads,
      initialReads,
      reason: 'Local UI actions must not issue another library query',
    );
    await unmountUi(tester);
  });

  testWidgets('article import retries and persists through a root remount', (
    tester,
  ) async {
    await launch(tester);
    app.articleExtractionService.fail = true;
    await tapUi(tester, find.byType(FloatingActionButton));
    await tapUi(tester, find.text('Save Article'));
    await tester.enterText(
      find.byType(TextField).last,
      ReadingFixture.articleUrl,
    );
    await tapUi(tester, find.widgetWithText(FilledButton, 'Save'));
    await waitForUi(
      tester,
      () => find.text('Try again').evaluate().isNotEmpty,
      description: 'retry after import failure',
    );
    app.articleExtractionService.fail = false;
    await tapUi(tester, find.text('Try again'));
    await tester.enterText(
      find.byType(TextField).last,
      ReadingFixture.articleUrl,
    );
    await tapUi(tester, find.widgetWithText(FilledButton, 'Save'));
    await waitForUi(tester, () {
      expect(app.articleRepository.lastError, isNull);
      return find.text('Article saved!').evaluate().isNotEmpty;
    }, description: 'article saved to SQLite');
    await tapUi(tester, find.text('Done'));
    await waitForUi(
      tester,
      () => find.text(ReadingFixture.articleTitle).evaluate().isNotEmpty,
      description: 'imported article in library',
    );
    final articles = await tester.runAsync(app.articleRepository.getArticles);
    expect(articles, hasLength(1));
    expect(app.articleExtractionService.requests, [
      ReadingFixture.articleUrl,
      ReadingFixture.articleUrl,
    ]);
    await unmountUi(tester);
    await tester.pumpWidget(app.widget);
    await waitForUi(
      tester,
      () => find.text(ReadingFixture.articleTitle).evaluate().isNotEmpty,
      description: 'persisted article after remount',
    );
    await unmountUi(tester);
  });

  testWidgets('open import sheet follows offline and online changes', (
    tester,
  ) async {
    await launch(tester);
    await tapUi(tester, find.byType(FloatingActionButton));
    app.connectivityService.setStatus(ConnectivityStatus.offline);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Paste URL'), findsNothing);
    expect(app.articleExtractionService.requests, isEmpty);
    app.connectivityService.setStatus(ConnectivityStatus.online);
    await tester.pumpAndSettle();
    await tapUi(tester, find.text('Save Article'));
    expect(find.bySemanticsLabel('Paste URL'), findsOneWidget);
    await unmountUi(tester);
  });

  testWidgets('collection create, rename and delete preserve the book', (
    tester,
  ) async {
    await launch(tester);
    await tester.longPress(find.text(ReadingFixture.bookTitle));
    await tester.pumpAndSettle();
    await tapUi(tester, find.byIcon(AppIcons.collectionAdd));
    await tester.enterText(
      find.widgetWithText(TextField, 'New collection name'),
      'Reading list',
    );
    await tapUi(tester, find.text('Create'));
    await waitForUi(
      tester,
      () => find.text('Create').evaluate().isEmpty,
      description: 'collection created',
    );
    final collections = await tester.runAsync(
      app.collectionRepository.getCollections,
    );
    final collection = collections!.single;
    expect(collection.name, 'Reading list');
    expect(collection.sourceCount, 1);
    await tapUi(tester, find.byIcon(AppIcons.collection));
    final manage = find.byKey(
      ValueKey('collectionScopeManage-manual-${collection.id}'),
    );
    await tapUi(tester, manage);
    final nameField = find.descendant(
      of: find.byKey(const ValueKey('manageCollectionContent')),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Weekend reading');
    await tapUi(tester, find.text('Save'));
    await waitForUi(
      tester,
      () => find.text('Manage collection').evaluate().isEmpty,
      description: 'collection renamed',
    );
    expect(
      (await tester.runAsync(
        app.collectionRepository.getCollections,
      ))!.single.name,
      'Weekend reading',
    );
    await tapUi(tester, find.byIcon(AppIcons.collection));
    await tapUi(tester, manage);
    await tapUi(tester, find.text('Delete collection'));
    await tapUi(tester, find.text('Cancel'));
    expect(
      (await tester.runAsync(app.collectionRepository.getCollections)),
      hasLength(1),
    );
    await tapUi(tester, find.text('Delete collection'));
    await tapUi(tester, find.text('Delete'));
    await waitForUi(
      tester,
      () => find.text('Delete collection?').evaluate().isEmpty,
      description: 'collection deleted',
    );
    expect(
      await tester.runAsync(app.collectionRepository.getCollections),
      isEmpty,
    );
    expect(
      await tester.runAsync(app.collectionRepository.getCollectionSourceIds),
      isEmpty,
    );
    expect(await tester.runAsync(app.bookRepository.getBooks), hasLength(1));
    expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await unmountUi(tester);
  });
}
