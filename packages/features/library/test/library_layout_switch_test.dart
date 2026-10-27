import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_content_scroll_view.dart';
import 'package:library_feature/src/library_grid_sliver.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_list_sliver.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:component_library/component_library.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';
import 'helpers/fake_fsrs_repository.dart';

// Scrolled out of view, a sliver's child is offstage to finders but still
// mounted: its element is what the switch must keep.
final _row = find.byKey(
  const ValueKey('libraryPracticeRow'),
  skipOffstage: false,
);
final _card = find.byKey(
  const ValueKey('libraryContinueReadingCard'),
  skipOffstage: false,
);
final _scrollable = find.descendant(
  of: find.byType(LibraryContentScrollView),
  matching: find.byType(Scrollable),
);

final _reading = Book(
  id: 'b-reading',
  title: 'Reading Now',
  filePath: '/books/reading.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
  readingProgress: .4,
  lastOpenedAt: DateTime(2026, 3),
);

List<Book> _shelf(int count) => [
  for (var i = 0; i < count; i++)
    Book(
      id: 'b-$i',
      title: 'Book $i',
      filePath: '/books/$i.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 1 + i),
    ),
];

/// Switching List and Grid changes the covers and nothing else: the Practice
/// row and the Continue reading card keep their elements and place, the
/// scroll position survives, and only the sources fade in.
void main() {
  late FakeBookRepository bookRepository;
  late FakeCollectionRepository collectionRepository;
  late FakeFsrsRepository fsrsRepository;
  late PreferencesService preferencesService;

  setUp(() async {
    bookRepository = FakeBookRepository()..seedBooks([_reading, ..._shelf(12)]);
    collectionRepository = FakeCollectionRepository();
    fsrsRepository = FakeFsrsRepository()
      ..stats = reviewStats(words: 1, highlights: 1, due: 2);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    await preferencesService.update(
      (prefs) => prefs.copyWith(libraryLayoutMode: LibraryLayoutMode.list.id),
    );
  });

  Widget buildSubject({bool reduceMotion = false}) => MaterialApp(
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: LibraryScreen(
      bookRepository: bookRepository,
      collectionRepository: collectionRepository,
      fsrsRepository: fsrsRepository,
      preferencesService: preferencesService,
      onSourcePressed: (_, {onSourceOpened, onReadingPositionSaved}) async {},
      onAddPressed:
          ({required onImported, entry = LibraryImportEntry.menu}) async {},
      onPracticePressed: () async {},
    ),
  );

  Future<void> pumpLibrary(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject(reduceMotion: reduceMotion));
    await tester.pumpAndSettle();
    expect(_row, findsOneWidget);
    expect(_card, findsOneWidget);
    expect(find.byType(LibraryListSliver), findsOneWidget);
  }

  /// Chooses [label] in the Display sheet, as the reader does, opening the
  /// sheet when it is not already up, and leaves it open over the Library.
  Future<void> chooseLayout(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.tap(
        find.byKey(const ValueKey('libraryHeaderDisplayButton')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(label));
  }

  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(_scrollable).position.pixels;

  testWidgets('keeps the row, the card, the viewport and its offset', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await tester.drag(
      find.byType(LibraryContentScrollView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    final scrolled = offset(tester);
    expect(scrolled, greaterThan(100));
    final rowElement = tester.element(_row);
    final cardElement = tester.element(_card);
    final scrollableState = tester.state<ScrollableState>(_scrollable);

    await chooseLayout(tester, 'Grid');
    await tester.pumpAndSettle();

    expect(find.byType(LibraryGridSliver), findsOneWidget);
    expect(find.byType(LibraryListSliver), findsNothing);
    expect(tester.element(_row), same(rowElement));
    expect(tester.element(_card), same(cardElement));
    expect(tester.state<ScrollableState>(_scrollable), same(scrollableState));
    expect(offset(tester), scrolled);

    await chooseLayout(tester, 'List');
    await tester.pumpAndSettle();

    expect(find.byType(LibraryListSliver), findsOneWidget);
    expect(tester.element(_row), same(rowElement));
    expect(tester.element(_card), same(cardElement));
    expect(offset(tester), scrolled);
  });

  testWidgets('only the sources fade in; the header is not rebuilt', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    var headerBuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is LibraryHeader) headerBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    await tester.tap(find.text('Grid'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final fade = find.byType(SliverFadeTransition);
    expect(fade, findsOneWidget);
    final midway = tester.widget<SliverFadeTransition>(fade).opacity.value;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));
    expect(
      find.descendant(of: fade, matching: find.byType(LibraryGridSliver)),
      findsOneWidget,
    );
    // The row and the card sit above the fading sliver, untouched.
    expect(find.ancestor(of: _row, matching: fade), findsNothing);
    expect(find.ancestor(of: _card, matching: fade), findsNothing);
    expect(headerBuilds, 0);

    await tester.pumpAndSettle();
    expect(tester.widget<SliverFadeTransition>(fade).opacity.value, 1);
  });

  testWidgets('under reduced motion the new layout is simply there', (
    tester,
  ) async {
    await pumpLibrary(tester, reduceMotion: true);

    await chooseLayout(tester, 'Grid');
    await tester.pump();

    final fade = find.byType(SliverFadeTransition);
    expect(tester.widget<SliverFadeTransition>(fade).opacity.value, 1);
    expect(find.byType(LibraryGridSliver), findsOneWidget);
  });

  testWidgets('the opening layout does not fade in', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.pump();

    final fade = find.byType(SliverFadeTransition);
    expect(fade, findsOneWidget);
    expect(tester.widget<SliverFadeTransition>(fade).opacity.value, 1);
  });
}
