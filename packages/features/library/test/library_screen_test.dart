import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:library_feature/library_feature.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  author: 'Eric Windmill',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

void main() {
  late FakeBookRepository bookRepository;
  late FakeCollectionRepository collectionRepository;
  late PreferencesService preferencesService;

  setUp(() async {
    bookRepository = FakeBookRepository();
    collectionRepository = FakeCollectionRepository();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ['en'],
    );
  });

  Widget buildSubject({ArticleRepository? articleRepository}) => MaterialApp(
    theme: AppTheme.light(),
    home: LibraryScreen(
      bookRepository: bookRepository,
      articleRepository: articleRepository,
      collectionRepository: collectionRepository,
      preferencesService: preferencesService,
      onSourcePressed: (_, {onSourceOpened}) async {},
      onAddPressed: () async {},
    ),
  );

  testWidgets('shows loading indicator initially', (tester) async {
    bookRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());

    await tester.pump();
    expect(find.text('Failed to load library'), findsOneWidget);
  });

  testWidgets('shows error state on failure', (tester) async {
    bookRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Failed to load library'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows empty state when no items', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('shows Library header and item count with content', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search library...'), findsOneWidget);
  });

  testWidgets('shows filter segments', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Comics'), findsOneWidget);
  });

  testWidgets('shows FAB', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB guards against double-tap while import is in-flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    var invocations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: () async {
            invocations++;
            await gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(
      invocations,
      1,
      reason: 'second tap during in-flight import must be ignored',
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  // Visual counterpart to the guard test above. The behavioural guard
  // alone (re-entry check inside the handler) made the second tap a
  // silent no-op, but the FAB stayed visually enabled — confusing UX
  // and the fragility flagged by audit ("if UI ever depends on the
  // flag, it would silently desync"). Now `_addInFlight` is mutated
  // through setState and passed down as a nullable onPressed, so
  // FloatingActionButton renders greyed-out for the duration of the
  // import.
  testWidgets('FAB renders disabled while import is in-flight', (tester) async {
    final gate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: () async {
            await gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    // Before the tap: FAB is enabled.
    final initialFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(initialFab.onPressed, isNotNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // While the awaited onAddPressed parks on the gate, the FAB's
    // onPressed must be null — Material renders that state as disabled.
    final inFlightFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(inFlightFab.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();

    // After the import resolves the FAB returns to its enabled state.
    final settledFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(settledFab.onPressed, isNotNull);
  });

  testWidgets('refreshes and resorts after source details return delay', (
    tester,
  ) async {
    final newest = Book(
      id: 'b-newest',
      title: 'Newest',
      author: 'Author',
      filePath: '/books/newest.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 4),
    );
    final second = Book(
      id: 'b-second',
      title: 'Second',
      author: 'Author',
      filePath: '/books/second.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 3),
    );
    final target = Book(
      id: 'b-target',
      title: 'Target',
      author: 'Author',
      filePath: '/books/target.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1),
    );

    bookRepository.seedBooks([newest, second, target]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (source, {onSourceOpened}) async {
            expect(source.id, target.id);
            bookRepository.seedBooks([
              target.copyWith(lastOpenedAt: DateTime(2026, 1, 5)),
              newest,
              second,
            ]);
          },
          onAddPressed: () async {},
        ),
      ),
    );
    await tester.pump();

    final targetFinder = find.text('Target');
    final newestFinder = find.text('Newest');
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetFinder).dx,
      greaterThan(tester.getTopLeft(newestFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(
      bookRepository.getBooksCallCount,
      1,
      reason: 'refreshing immediately would move the reverse Hero endpoint',
    );
    expect(
      tester.getTopLeft(targetFinder).dx,
      greaterThan(tester.getTopLeft(newestFinder).dx),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(bookRepository.getBooksCallCount, 1);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetFinder).dy,
      tester.getTopLeft(newestFinder).dy,
    );
  });

  testWidgets('refreshes before source details returns when reader opens', (
    tester,
  ) async {
    final newest = Book(
      id: 'b-newest',
      title: 'Newest',
      author: 'Author',
      filePath: '/books/newest.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 4),
    );
    final target = Book(
      id: 'b-target',
      title: 'Target',
      author: 'Author',
      filePath: '/books/target.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1),
    );
    final routeCompleter = Completer<void>();
    VoidCallback? notifySourceOpened;

    bookRepository.seedBooks([newest, target]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (source, {onSourceOpened}) async {
            expect(source.id, target.id);
            notifySourceOpened = onSourceOpened;
            await routeCompleter.future;
          },
          onAddPressed: () async {},
        ),
      ),
    );
    await tester.pump();

    final targetFinder = find.text('Target');
    final newestFinder = find.text('Newest');
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetFinder).dx,
      greaterThan(tester.getTopLeft(newestFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 1);
    expect(notifySourceOpened, isNotNull);

    bookRepository.seedBooks([
      target.copyWith(lastOpenedAt: DateTime(2026, 1, 5)),
      newest,
    ]);
    notifySourceOpened!();
    await tester.pump();
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetFinder).dy,
      tester.getTopLeft(newestFinder).dy,
    );

    bookRepository.seedBooks([
      target.copyWith(
        lastOpenedAt: DateTime(2026, 1, 5),
        readingProgress: 0.5,
      ),
      newest,
    ]);
    routeCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      bookRepository.getBooksCallCount,
      2,
      reason: 'return refresh waits for the reverse Hero endpoint',
    );
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(
      bookRepository.getBooksCallCount,
      3,
      reason: 'return refresh picks up reader progress persisted after open',
    );
  });

  testWidgets('selection mode shows collection and delete FABs', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final addFabCenter = tester.getCenter(find.byIcon(AppIcons.add));

    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNWidgets(2));
    expect(find.text('Add collection'), findsOneWidget);
    expect(find.byIcon(AppIcons.collectionAdd), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsOneWidget);
    expect(find.byIcon(AppIcons.add), findsNothing);
    expect(
      tester.getCenter(find.byIcon(AppIcons.delete)).dx,
      closeTo(addFabCenter.dx, 1),
    );
    expect(
      tester.getCenter(find.byIcon(AppIcons.delete)).dy,
      closeTo(addFabCenter.dy, 1),
    );

    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(
      tester.getCenter(find.text('Add collection')).dx,
      lessThan(screenWidth * 0.35),
    );
    expect(
      tester.getCenter(find.byIcon(AppIcons.delete)).dx,
      greaterThan(screenWidth * 0.65),
    );
  });

  testWidgets('manual collection scope filters visible sources', (
    tester,
  ) async {
    final other = Book(
      id: 'b-2',
      title: 'Domain-Driven Design',
      author: 'Eric Evans',
      filePath: '/books/ddd.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 2),
    );
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book, other]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dune'));
    await tester.pumpAndSettle();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsNothing);
    expect(find.text('Dune'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsOneWidget);
  });

  testWidgets('collection scope sheet filters scopes by search query', (
    tester,
  ) async {
    final articleRepository = _FakeArticleRepository()
      ..seedArticles([
        Article(
          id: 'a-1',
          title: 'Article',
          url: 'https://tproger.ru/a',
          siteName: 'Tproger',
          author: 'Seiken',
          contentPath: '/articles/a-1/article.json',
          addedAt: DateTime(2026, 1, 2),
        ),
      ]);
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject(articleRepository: articleRepository));
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final sheet = find.byType(ActionBottomSheetLayout);
    final sheetTopBeforeSearch = tester.getTopLeft(sheet).dy;
    final sheetHeightBeforeSearch = tester.getSize(sheet).height;
    final searchField = find.widgetWithText(TextField, 'Search collections...');
    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final siteRow = find.byKey(
      const ValueKey('collectionScopeRow-site-tproger'),
    );
    final authorRow = find.byKey(
      const ValueKey('collectionScopeRow-author-seiken'),
    );

    expect(searchField, findsOneWidget);
    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);

    await tester.enterText(searchField, 'tpro');
    await tester.pumpAndSettle();

    expect(manualRow, findsNothing);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsNothing);

    await tester.enterText(searchField, 'missing');
    await tester.pumpAndSettle();

    expect(find.text('No matching collections'), findsOneWidget);
    expect(siteRow, findsNothing);
    expect(tester.getTopLeft(sheet).dy, closeTo(sheetTopBeforeSearch, 0.1));
    expect(tester.getSize(sheet).height, closeTo(sheetHeightBeforeSearch, 0.1));

    await tester.tap(
      find.descendant(
        of: find.byType(ActionBottomSheetLayout),
        matching: find.byIcon(AppIcons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
  });

  testWidgets('collection scope sheet uses scroll edge fades', (tester) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final sheet = find.byType(ActionBottomSheetLayout);
    final fadeStack = find.descendant(
      of: sheet,
      matching: find.byType(ScrollEdgeFadeStack),
    );

    final sheetWidget = tester.widget<ActionBottomSheetLayout>(sheet);

    expect(find.byType(AppBottomSafeArea), findsNothing);
    expect(sheetWidget.bodyPadding, EdgeInsets.zero);
    expect(fadeStack, findsOneWidget);
    expect(
      tester.getSize(fadeStack).width,
      closeTo(tester.getSize(sheet).width, 0.1),
    );
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ScrollEdgeFade)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
      findsOneWidget,
    );
  });

  testWidgets('collection scope rows do not show pressed overlay', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final rowInkWell = tester.widget<InkWell>(
      find.ancestor(of: manualRow, matching: find.byType(InkWell)),
    );

    expect(
      rowInkWell.overlayColor?.resolve({WidgetState.pressed}),
      Colors.transparent,
    );
  });

  testWidgets('collection scope rows keep equal height across sections', (
    tester,
  ) async {
    final articleRepository = _FakeArticleRepository()
      ..seedArticles([
        Article(
          id: 'a-1',
          title: 'Article',
          url: 'https://tproger.ru/a',
          siteName: 'Tproger',
          author: 'Seiken',
          contentPath: '/articles/a-1/article.json',
          addedAt: DateTime(2026, 1, 2),
        ),
      ]);
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject(articleRepository: articleRepository));
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final siteRow = find.byKey(
      const ValueKey('collectionScopeRow-site-tproger'),
    );
    final authorRow = find.byKey(
      const ValueKey('collectionScopeRow-author-seiken'),
    );

    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
    expect(tester.getSize(manualRow).height, tester.getSize(siteRow).height);
    expect(tester.getSize(manualRow).height, tester.getSize(authorRow).height);
  });

  testWidgets('manual collection management removes a source', (
    tester,
  ) async {
    final other = Book(
      id: 'b-2',
      title: 'Domain-Driven Design',
      author: 'Eric Evans',
      filePath: '/books/ddd.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 2),
    );
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book, other]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id, other.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.moreVertical));
    await tester.pumpAndSettle();

    expect(find.text('Manage collection'), findsOneWidget);

    final sheet = find.byType(ActionBottomSheetLayout);
    final saveFinder = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    var saveButton = tester.widget<FilledButton>(saveFinder);
    final sheetHeightBeforeRemoval = tester.getSize(sheet).height;
    final saveTopBeforeRemoval = tester.getTopLeft(saveFinder).dy;
    expect(saveButton.onPressed, isNull);

    await tester.tap(
      find.descendant(of: sheet, matching: find.byIcon(AppIcons.close)).first,
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(sheet).height, lessThan(sheetHeightBeforeRemoval));
    expect(
      tester.getTopLeft(saveFinder).dy,
      closeTo(saveTopBeforeRemoval, 0.1),
    );

    expect(
      find.descendant(of: sheet, matching: find.text('Flutter in Action')),
      findsNothing,
    );
    expect(collectionRepository.addedSourceIdsByCollection[collection.id], {
      _book.id,
      other.id,
    });

    saveButton = tester.widget<FilledButton>(saveFinder);
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(collectionRepository.addedSourceIdsByCollection[collection.id], {
      other.id,
    });
    expect(find.text('Manage collection'), findsNothing);
  });

  testWidgets('manual collection management deletes collection', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.moreVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete collection'));
    await tester.pumpAndSettle();

    expect(find.byType(ActionBottomSheetLayout), findsOneWidget);
    expect(find.text('Manage collection'), findsNothing);
    expect(find.text('Delete collection?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await collectionRepository.getCollections(), isEmpty);
    expect(await collectionRepository.getCollectionSourceIds(), isEmpty);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('manual collection management renames from footer action', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.moreVertical));
    await tester.pumpAndSettle();

    expect(find.text('Collection name'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    final nameField = find.descendant(
      of: find.byType(ActionBottomSheetLayout),
      matching: find.byType(TextField),
    );
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, 'Dune Saga');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final collections = await collectionRepository.getCollections();
    expect(collections.single.name, 'Dune Saga');
    expect(find.text('Manage collection'), findsNothing);
  });

  testWidgets('creates collection from selected source', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.collectionAdd));
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, 'New collection name');
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(
      tester.getCenter(nameField).dy,
      lessThan(tester.getCenter(find.text('Create')).dy),
    );
    expect(
      tester.getCenter(find.text('Cancel')).dy,
      closeTo(tester.getCenter(find.text('Create')).dy, 1),
    );

    await tester.enterText(
      nameField,
      'Dune',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(collectionRepository.addedSourceIdsByCollection, isNotEmpty);
    expect(
      collectionRepository.addedSourceIdsByCollection.values.single,
      contains(_book.id),
    );
    expect(find.text('Added to collection'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

class _FakeArticleRepository implements ArticleRepository {
  final List<Article> _articles = [];

  void seedArticles(List<Article> articles) => _articles
    ..clear()
    ..addAll(articles);

  @override
  Future<List<Article>> getArticles({int? limit, int? offset}) async =>
      List.unmodifiable(_articles);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
