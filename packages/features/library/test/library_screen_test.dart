import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';

const double _collectionSourcesMaxHeightForTest = 260;

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
      supportedCodes: ReadflexSupportedLocales.codes,
    );
  });

  Widget buildSubject({
    ArticleRepository? articleRepository,
    bool isOffline = false,
  }) => PreferencesScope(
    service: preferencesService,
    child: Builder(
      builder: (context) => MaterialApp(
        locale: PreferencesScope.localeOf(context),
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          articleRepository: articleRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          isOffline: isOffline,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: () async {},
        ),
      ),
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
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('display button opens view and appearance sheet', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('libraryHeaderDisplayButton')),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.viewList), findsNothing);
    expect(find.byIcon(AppIcons.viewGrid), findsNothing);
    expect(find.byIcon(AppIcons.deviceMode), findsNothing);

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();

    expect(find.text('Display'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.libraryLayoutMode, 'list');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.themeMode, ThemeMode.dark);
    expect(find.text('Display'), findsOneWidget);
  });

  testWidgets('display sheet changes app language', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Русский'));
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.locale, const Locale('ru'));
    expect(find.text('Библиотека'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
  });

  testWidgets('display sheet lays language options out in two columns', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('libraryLanguageOption-en')),
    );

    final englishRect = tester.getRect(
      find.byKey(const ValueKey('libraryLanguageOption-en')),
    );
    final chineseRect = tester.getRect(
      find.byKey(const ValueKey('libraryLanguageOption-zh')),
    );
    final hindiRect = tester.getRect(
      find.byKey(const ValueKey('libraryLanguageOption-hi')),
    );

    expect(chineseRect.top, closeTo(englishRect.top, 1));
    expect(chineseRect.left, greaterThan(englishRect.right));
    expect(hindiRect.top, greaterThan(englishRect.top));
  });

  testWidgets('switches layout without mounting both scroll views', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(LibraryGridView), findsOneWidget);
    expect(find.byType(LibraryListView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pump();

    expect(find.byType(LibraryGridView), findsNothing);
    expect(find.byType(LibraryListView), findsOneWidget);
  });

  testWidgets('header actions stay aligned to the right edge', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    final displayButtonRect = tester.getRect(
      find.byKey(const ValueKey('libraryHeaderDisplayButton')),
    );

    expect(
      displayButtonRect.right,
      closeTo(scaffoldRect.right - AppSpacing.lg, 1),
    );
  });

  testWidgets('shows offline status next to Library title', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject(isOffline: true));
    await tester.pump();

    final titleRect = tester.getRect(find.text('Library'));
    final statusRect = tester.getRect(find.text('offline'));
    final statusText = tester.widget<Text>(find.text('offline'));

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(statusRect.left, greaterThan(titleRect.right));
    expect(statusText.style?.color, AppTheme.light().ext.warning);
  });

  testWidgets('hides offline status while reserving header space', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final statusOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('offline'),
        matching: find.byType(Opacity),
      ),
    );

    expect(statusOpacity.opacity, 0);
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search library...'), findsOneWidget);
  });

  testWidgets('source tap keeps search unfocused after reader route returns', (
    tester,
  ) async {
    var opened = false;
    final navigatorKey = GlobalKey<NavigatorState>();
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {
            opened = true;
            await navigatorKey.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Reader route')),
              ),
            );
          },
          onAddPressed: () async {},
        ),
      ),
    );
    await tester.pump();

    final searchField = find.widgetWithText(TextField, 'Search library...');
    await tester.tap(searchField);
    await tester.pump();

    final searchEditable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    final searchFocusNode = searchEditable.focusNode;
    expect(searchFocusNode.hasFocus, isTrue);

    await tester.tap(find.text('Flutter in Action'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.text('Reader route'), findsOneWidget);
    expect(searchFocusNode.hasFocus, isFalse);
    expect(searchFocusNode.canRequestFocus, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(searchFocusNode.hasFocus, isFalse);
    expect(searchFocusNode.canRequestFocus, isTrue);
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

  testWidgets('keeps FAB above the bottom edge', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final paddingAncestors = find.ancestor(
      of: find.byIcon(AppIcons.add),
      matching: find.byType(Padding),
    );
    final hasBottomLift = paddingAncestors.evaluate().any((element) {
      final padding = (element.widget as Padding).padding;
      return padding == const EdgeInsetsDirectional.only(bottom: AppSpacing.sm);
    });

    expect(hasBottomLift, isTrue);
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

  testWidgets('refreshes and resorts after reader route return delay', (
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
    final targetTileFinder = find.byKey(
      const ValueKey('library-grid-b-target'),
    );
    final newestTileFinder = find.byKey(
      const ValueKey('library-grid-b-newest'),
    );
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetTileFinder).dx,
      greaterThan(tester.getTopLeft(newestTileFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(
      bookRepository.getBooksCallCount,
      1,
      reason: 'refreshing immediately would move the reverse Hero endpoint',
    );
    expect(
      tester.getTopLeft(targetTileFinder).dx,
      greaterThan(tester.getTopLeft(newestTileFinder).dx),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(bookRepository.getBooksCallCount, 1);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetTileFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetTileFinder).dy,
      tester.getTopLeft(newestTileFinder).dy,
    );
  });

  testWidgets('refreshes before reader route returns when source opens', (
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
    final targetTileFinder = find.byKey(
      const ValueKey('library-grid-b-target'),
    );
    final newestTileFinder = find.byKey(
      const ValueKey('library-grid-b-newest'),
    );
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetTileFinder).dx,
      greaterThan(tester.getTopLeft(newestTileFinder).dx),
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
    expect(tester.getTopLeft(targetTileFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetTileFinder).dy,
      tester.getTopLeft(newestTileFinder).dy,
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
    expect(find.text('Add to collection'), findsOneWidget);
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
      tester.getCenter(find.text('Add to collection')).dx,
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

  testWidgets(
    'collection scope sheet shows favourites without permanent section',
    (
      tester,
    ) async {
      bookRepository.seedBooks([_book]);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(AppIcons.collection));
      await tester.pumpAndSettle();

      final favouritesRow = find.byKey(
        const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
      );

      expect(find.text('Permanent'), findsNothing);
      expect(favouritesRow, findsOneWidget);
      expect(
        find.descendant(
          of: favouritesRow,
          matching: find.byIcon(AppIcons.collectionFavourites),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: favouritesRow,
          matching: find.byIcon(AppIcons.moreVertical),
        ),
        findsOneWidget,
      );
    },
  );

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
      const ValueKey('collectionScopeRow-author-seiken (tproger.ru)'),
    );

    expect(searchField, findsOneWidget);
    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
    expect(find.text('Seiken (tproger.ru)'), findsOneWidget);

    await tester.enterText(searchField, 'tpro');
    await tester.pumpAndSettle();

    expect(manualRow, findsNothing);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);

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
    final listView = tester.widget<ListView>(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
    );
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
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
      const ValueKey('collectionScopeRow-author-seiken (tproger.ru)'),
    );

    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
    expect(tester.getSize(manualRow).height, tester.getSize(siteRow).height);
    expect(tester.getSize(manualRow).height, tester.getSize(authorRow).height);

    final sheet = find.byType(ActionBottomSheetLayout);
    final visibleGapBelowAuthor =
        tester.getBottomLeft(sheet).dy - tester.getBottomLeft(authorRow).dy;
    expect(visibleGapBelowAuthor, greaterThanOrEqualTo(AppSpacing.lg));
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
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage collection'), findsOneWidget);

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    final saveFinder = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    var saveButton = tester.widget<FilledButton>(saveFinder);
    final sheetHeightBeforeRemoval = tester.getSize(sheet).height;
    final saveTopBeforeRemoval = tester.getTopLeft(saveFinder).dy;
    expect(saveButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('collectionSourceRemove-b-1')),
    );
    await tester.pump();

    expect(
      find.descendant(of: sheet, matching: find.text('Flutter in Action')),
      findsOneWidget,
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

  testWidgets('manage collection shows book and article counts', (
    tester,
  ) async {
    final articleRepository = _FakeArticleRepository()
      ..seedArticles([
        Article(
          id: 'article-1',
          title: 'Saved article',
          url: 'https://example.com/a',
          siteName: 'Example',
          author: 'Author',
          contentPath: '/articles/article-1/article.json',
          addedAt: DateTime(2026, 1, 2),
        ),
      ]);
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Mixed collection',
      sourceCount: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id, 'article-1'},
    });

    await tester.pumpWidget(
      buildSubject(articleRepository: articleRepository),
    );
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    expect(
      find.descendant(of: sheet, matching: find.text('1 book, 1 article')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('collectionSourceRemove-b-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sheet, matching: find.text('1 article')),
      findsOneWidget,
    );
  });

  testWidgets('manage collection empty state is centered in list area', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Empty collection',
      sourceCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({collection.id: <String>{}});

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    final countLabel = find.descendant(
      of: sheet,
      matching: find.text('0 books/articles'),
    );
    final emptyLabel = find.descendant(
      of: sheet,
      matching: find.text('No items in this collection'),
    );
    final saveButton = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, 'Save'),
    );

    expect(countLabel, findsOneWidget);
    expect(emptyLabel, findsOneWidget);

    final listAreaTop = tester.getBottomLeft(countLabel).dy + AppSpacing.md;
    final listAreaBottom = tester.getTopLeft(saveButton).dy - AppSpacing.lg;
    final expectedCenter = (listAreaTop + listAreaBottom) / 2;

    expect(tester.getCenter(emptyLabel).dy, closeTo(expectedCenter, 1));
  });

  testWidgets('manage collection item list uses scroll edge fades', (
    tester,
  ) async {
    final books = List.generate(
      12,
      (index) => Book(
        id: 'book-$index',
        title: 'Book $index',
        author: 'Author',
        filePath: '/books/book-$index.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 1, index + 1),
      ),
    );
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Large collection',
      sourceCount: books.length,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks(books);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: books.map((book) => book.id).toSet(),
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    final fadeStack = find.descendant(
      of: sheet,
      matching: find.byType(ScrollEdgeFadeStack),
    );

    expect(fadeStack, findsOneWidget);
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
      findsOneWidget,
    );
    final listView = tester.widget<ListView>(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
    );
    expect(
      listView.padding,
      const EdgeInsets.only(bottom: AppSpacing.lg),
    );
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ScrollEdgeFade)),
      findsNWidgets(2),
    );
    expect(
      tester.getSize(fadeStack).width,
      closeTo(tester.getSize(sheet).width, 0.1),
    );
    expect(
      tester.getSize(fadeStack).height,
      lessThanOrEqualTo(_collectionSourcesMaxHeightForTest),
    );
  });

  testWidgets(
    'favourites management removes a source without delete controls',
    (
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
      bookRepository.seedBooks([_book, other]);
      await collectionRepository.addSourcesToFavourites(
        sourceIds: [_book.id, other.id],
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(AppIcons.collection));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'collectionScopeManage-favourites-readflex:favourites',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('manageCollectionContent'));
      expect(find.text('Manage collection'), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(find.text('Delete collection'), findsNothing);

      final saveFinder = find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, 'Save'),
      );
      var saveButton = tester.widget<FilledButton>(saveFinder);
      expect(saveButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('collectionSourceRemove-b-1')),
      );
      await tester.pumpAndSettle();

      saveButton = tester.widget<FilledButton>(saveFinder);
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(collectionRepository.favouriteSourceIds, {other.id});
      expect(find.text('Manage collection'), findsNothing);
    },
  );

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
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final manageStepHeight = tester
        .getSize(
          find.byKey(const ValueKey('manageCollectionContent')),
        )
        .height;
    final stepFrame = find.byKey(const ValueKey('manageCollectionStepFrame'));
    expect(stepFrame, findsOneWidget);
    expect(tester.getSize(stepFrame).height, manageStepHeight);

    await tester.tap(find.text('Delete collection'));
    await tester.pump();

    expect(find.byType(FractionalTranslation), findsWidgets);
    expect(tester.getSize(stepFrame).height, manageStepHeight);

    await tester.pumpAndSettle();

    final deleteStep = find.byKey(const ValueKey('deleteCollectionContent'));
    expect(deleteStep, findsOneWidget);
    expect(tester.getSize(deleteStep).height, lessThan(manageStepHeight));
    expect(find.text('Manage collection'), findsNothing);
    expect(find.text('Delete collection?'), findsOneWidget);

    final deleteTitle = find.text('Delete collection?');
    final deleteMessage = find.descendant(
      of: deleteStep,
      matching: find.text(
        'This removes "Dune" only. Books and articles stay in your library.',
      ),
    );
    final deleteButton = find.descendant(
      of: deleteStep,
      matching: find.widgetWithText(FilledButton, 'Delete'),
    );
    final messageAreaTop = tester.getBottomLeft(deleteTitle).dy + AppSpacing.lg;
    final messageAreaBottom =
        tester.getTopLeft(deleteButton).dy - AppSpacing.lg;
    final expectedMessageCenter = (messageAreaTop + messageAreaBottom) / 2;

    expect(deleteMessage, findsOneWidget);
    expect(
      tester.getCenter(deleteMessage).dy,
      closeTo(expectedMessageCenter, 1),
    );

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
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collection name'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    final nameField = find.descendant(
      of: find.byKey(const ValueKey('manageCollectionContent')),
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

  testWidgets('adds selected source to favourites from add collection sheet', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.collectionAdd));
    await tester.pumpAndSettle();

    final favouritesRow = find.widgetWithText(InkWell, 'Favourites');

    expect(favouritesRow, findsOneWidget);
    expect(find.byIcon(AppIcons.collectionFavourites), findsOneWidget);

    await tester.tap(favouritesRow);
    await tester.pumpAndSettle();

    expect(collectionRepository.favouriteSourceIds, {_book.id});
    expect(find.text('Add to collection'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
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
