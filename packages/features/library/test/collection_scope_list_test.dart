import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/select_collection_scope_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

LibraryCollectionScope _author(int i, {String? label}) =>
    LibraryCollectionScope.smart(
      type: LibraryCollectionScopeType.author,
      id: 'author-$i',
      label: label ?? 'Author $i',
      sourceCount: 1,
    );

LibraryCollectionScope _site(String id, String label) =>
    LibraryCollectionScope.smart(
      type: LibraryCollectionScopeType.site,
      id: id,
      label: label,
      sourceCount: 1,
    );

LibraryCollectionScope _manual(String id, String name) =>
    LibraryCollectionScope.manual(
      collection: LibraryCollection(
        id: id,
        name: name,
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      sourceIds: const {'a'},
    );

LibraryState _authors(int count, {LibraryCollectionScope? selected}) =>
    LibraryState(
      collectionScopes: [
        LibraryCollectionScope.favourites(),
        for (var i = 0; i < count; i++) _author(i),
      ],
      selectedCollectionScope: selected,
    );

Finder _row(String keyId) => find.byKey(ValueKey('collectionScopeRow-$keyId'));

/// Keys of the picker rows currently built, on screen or in the list's
/// cache extent.
List<String> _builtRows() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'collectionScopeRow-',
          ),
      skipOffstage: false,
    )
    .evaluate()
    .map((element) => (element.widget.key! as ValueKey<String>).value)
    .toList();

final _list = find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(ListView),
);
final _scrollable = find.descendant(
  of: _list,
  matching: find.byType(Scrollable),
);

ScrollableState _scrollState(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable);

/// The results box under the search field, around the list or the empty
/// state.
double _resultsHeight(WidgetTester tester) => tester
    .getSize(
      find
          .ancestor(
            of: find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is ScrollEdgeFadeStack || widget is EmptyState,
              ),
            ),
            matching: find.byType(SizedBox),
          )
          .first,
    )
    .height;

/// Jumps the list to [offset], then scrolls [finder] into view.
Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double offset = 0,
}) async {
  _scrollState(tester).position.jumpTo(offset);
  await tester.pump();
  await tester.scrollUntilVisible(finder, 200, scrollable: _scrollable);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

void main() {
  Future<ReadflexLocalizations> open(
    WidgetTester tester,
    LibraryState state, {
    LibraryCollectionManagerBuilder? manageBuilder,
    Stream<LibraryState>? states,
    Locale locale = const Locale('en'),
    double keyboard = 0,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLibraryCollectionScopeSheet(
                context: context,
                state: state,
                states: states,
                manageBuilder: manageBuilder,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return tester.element(find.byType(BottomSheet)).l10n;
  }

  group('a long list', () {
    testWidgets('builds only the rows on screen with 2000 authors', (
      tester,
    ) async {
      final selected = _author(1999);
      await open(tester, _authors(2000, selected: selected));

      final built = _builtRows();
      expect(built.length, inInclusiveRange(5, 30));
      expect(built.take(3), [
        'collectionScopeRow-favourites-readflex:favourites',
        'collectionScopeRow-library',
        'collectionScopeRow-author-author-0',
      ]);
      expect(_row('author-author-1999'), findsNothing);
      expect(_resultsHeight(tester), 420);

      await _reveal(tester, _row('author-author-1999'), offset: 1990 * 48);
      expect(_builtRows().length, lessThanOrEqualTo(30));
      expect(
        find.byKey(
          const ValueKey('collectionScopeSelection-author-author-1999'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('author-author-1999'),
          matching: find.byIcon(AppIcons.check),
        ),
        findsOneWidget,
      );
      final position = _scrollState(tester).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      // The last row keeps its section's 16dp gap and the list's 16dp
      // bottom padding below it.
      expect(
        tester.getRect(_scrollable).bottom -
            tester.getRect(_row('author-author-1999')).bottom,
        closeTo(AppSpacing.lg * 2, .01),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('filters case-insensitively and still builds a screenful', (
      tester,
    ) async {
      final strings = await open(tester, _authors(2000));

      // "Author 19", "Author 190"-"199" and "Author 1900"-"1999".
      await _type(tester, 'AUTHOR 19');
      expect(tester.widget<ListView>(_list).semanticChildCount, 111);
      expect(_builtRows().length, lessThanOrEqualTo(30));
      expect(_builtRows().first, 'collectionScopeRow-author-author-19');
      expect(_row('author-author-20'), findsNothing);
      expect(_row('library'), findsNothing);
      expect(_row('favourites-readflex:favourites'), findsNothing);
      expect(find.text(strings.libraryAuthors), findsOneWidget);

      await _type(tester, '  aUtHoR 1999 ');
      expect(_builtRows(), ['collectionScopeRow-author-author-1999']);
      expect(tester.widget<ListView>(_list).semanticChildCount, 1);

      await _type(tester, 'author 20000');
      expect(find.text(strings.libraryNoMatchingCollections), findsOneWidget);
      expect(_list, findsNothing);
      expect(_resultsHeight(tester), 420);

      await _type(tester, '');
      expect(tester.widget<ListView>(_list).semanticChildCount, 2002);
      expect(_builtRows().length, lessThanOrEqualTo(30));
      expect(_row('library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an open keyboard leaves a lazy list that scrolls to its end', (
      tester,
    ) async {
      await open(tester, _authors(300), keyboard: 300);
      expect(_builtRows().length, inInclusiveRange(1, 30));
      await _reveal(tester, _row('author-author-299'), offset: 290 * 48);
      expect(_row('author-author-299').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('sections', () {
    final state = LibraryState(
      collectionScopes: [
        LibraryCollectionScope.favourites(),
        _manual('reading', 'Reading'),
        _manual('archive', 'Archive'),
        _site('tproger', 'tproger.ru'),
        _author(1, label: 'Reader Writer'),
        _author(2, label: 'Seiken'),
      ],
    );

    testWidgets('titles lead only groups with matches, 16dp apart', (
      tester,
    ) async {
      final strings = await open(tester, state);
      final manualTitle = find.text(strings.libraryManualCollections);
      final sitesTitle = find.text(strings.librarySites);
      final authorsTitle = find.text(strings.libraryAuthors);
      Rect rect(Finder finder) => tester.getRect(finder);

      expect(_builtRows(), [
        'collectionScopeRow-favourites-readflex:favourites',
        'collectionScopeRow-library',
        'collectionScopeRow-manual-reading',
        'collectionScopeRow-manual-archive',
        'collectionScopeRow-site-tproger',
        'collectionScopeRow-author-author-1',
        'collectionScopeRow-author-author-2',
      ]);
      // The untitled first group starts at the top of the list.
      expect(
        rect(_row('favourites-readflex:favourites')).top,
        rect(_scrollable).top,
      );
      // Each group ends 16dp above the next title; a title sits 4dp above
      // its first row.
      expect(
        rect(manualTitle).top - rect(_row('library')).bottom,
        closeTo(AppSpacing.lg, .01),
      );
      expect(
        rect(_row('manual-reading')).top - rect(manualTitle).bottom,
        closeTo(AppSpacing.xs, .01),
      );
      expect(
        rect(sitesTitle).top - rect(_row('manual-archive')).bottom,
        closeTo(AppSpacing.lg, .01),
      );
      expect(
        rect(authorsTitle).top - rect(_row('site-tproger')).bottom,
        closeTo(AppSpacing.lg, .01),
      );

      await _type(tester, 'READ');
      expect(_builtRows(), [
        'collectionScopeRow-manual-reading',
        'collectionScopeRow-author-author-1',
      ]);
      expect(sitesTitle, findsNothing);
      // Without Favourites and Library the first title leads the list.
      expect(rect(manualTitle).top, rect(_scrollable).top);
      expect(
        rect(authorsTitle).top - rect(_row('manual-reading')).bottom,
        closeTo(AppSpacing.lg, .01),
      );
      expect(
        rect(_row('author-author-1')).top - rect(authorsTitle).bottom,
        closeTo(AppSpacing.xs, .01),
      );

      await _type(tester, 'tproger');
      expect(_builtRows(), ['collectionScopeRow-site-tproger']);
      expect(sitesTitle, findsOneWidget);
      expect(manualTitle, findsNothing);
      expect(authorsTitle, findsNothing);

      await _type(tester, 'FAV');
      expect(_builtRows(), [
        'collectionScopeRow-favourites-readflex:favourites',
      ]);
      expect(find.text(strings.libraryManualCollections), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final locale in [const Locale('en'), const Locale('ru')]) {
      testWidgets('built-in rows match their localized label ($locale)', (
        tester,
      ) async {
        LibrarySource source(String id, SourceType type) => LibrarySource(
          id: id,
          sourceType: type,
          title: id,
          typeLabel: 'EPUB',
          addedAt: DateTime(2026),
        );
        final strings = await open(
          tester,
          LibraryState(
            sources: [
              source('book', SourceType.book),
              source('article', SourceType.article),
            ],
            collectionScopes: [
              for (final type in [
                LibraryCollectionScopeType.books,
                LibraryCollectionScopeType.articles,
              ])
                LibraryCollectionScope.smart(
                  type: type,
                  id: type.name,
                  label: type.name,
                  sourceCount: 1,
                ),
              LibraryCollectionScope.favourites(),
            ],
          ),
          locale: locale,
        );
        await _type(
          tester,
          strings.libraryScopeBooks.substring(0, 3).toUpperCase(),
        );
        expect(_builtRows(), contains('collectionScopeRow-books-books'));
        expect(_row('articles-articles'), findsNothing);

        // The stored label is not what the row shows outside English.
        await _type(tester, 'books');
        if (locale.languageCode == 'en') {
          expect(_builtRows(), ['collectionScopeRow-books-books']);
        } else {
          expect(
            find.text(strings.libraryNoMatchingCollections),
            findsOneWidget,
          );
        }
      });
    }
  });

  testWidgets('a new state refreshes the open list under the same query', (
    tester,
  ) async {
    final states = StreamController<LibraryState>.broadcast();
    addTearDown(states.close);
    final seiken = _author(1, label: 'Seiken');
    final seika = _author(2, label: 'Seika');
    await open(
      tester,
      LibraryState(
        collectionScopes: [LibraryCollectionScope.favourites(), seiken],
      ),
      states: states.stream,
    );
    await _type(tester, 'SEI');
    expect(_builtRows(), ['collectionScopeRow-author-author-1']);

    states.add(
      LibraryState(
        collectionScopes: [LibraryCollectionScope.favourites(), seiken, seika],
        selectedCollectionScope: seika,
      ),
    );
    await tester.pumpAndSettle();
    expect(_builtRows(), [
      'collectionScopeRow-author-author-1',
      'collectionScopeRow-author-author-2',
    ]);
    expect(
      find.byKey(const ValueKey('collectionScopeSelection-author-author-2')),
      findsOneWidget,
    );
    expect(tester.widget<ListView>(_list).semanticChildCount, 2);
  });

  testWidgets('screen readers count rows, not titles', (tester) async {
    final semantics = tester.ensureSemantics();
    final strings = await open(
      tester,
      LibraryState(
        collectionScopes: [
          LibraryCollectionScope.favourites(),
          _manual('reading', 'Reading'),
          _author(1, label: 'Seiken'),
        ],
      ),
    );
    expect(tester.widget<ListView>(_list).semanticChildCount, 4);
    final rows = [
      'favourites-readflex:favourites',
      'library',
      'manual-reading',
      'author-author-1',
    ];
    for (final (index, keyId) in rows.indexed) {
      expect(
        tester.getSemantics(_row(keyId)).indexInParent,
        index,
        reason: keyId,
      );
    }
    final library = tester.getSemantics(_row('library')).getSemanticsData();
    expect(library.flagsCollection.isSelected, Tristate.isTrue);
    expect(library.hasAction(SemanticsAction.tap), isTrue);
    expect(
      tester
          .getSemantics(find.text(strings.libraryManualCollections))
          .indexInParent,
      isNull,
    );
    semantics.dispose();
  });

  testWidgets('Manage and Back keep the query and a deep scroll offset', (
    tester,
  ) async {
    final state = LibraryState(
      collectionScopes: [
        LibraryCollectionScope.favourites(),
        for (var i = 0; i < 300; i++)
          _manual('c-$i', 'Collection ${i.toString().padLeft(3, '0')}'),
      ],
    );
    await open(
      tester,
      state,
      manageBuilder: (_, scope, back, _) => Center(
        child: TextButton(
          key: const ValueKey('manageStub'),
          onPressed: back,
          child: Text(scope.label),
        ),
      ),
    );
    // "Collection 200"-"299".
    await _type(tester, 'collection 2');
    expect(tester.widget<ListView>(_list).semanticChildCount, 100);
    final action = find.byKey(
      const ValueKey('collectionScopeManage-manual-c-280'),
    );
    await _reveal(tester, action);
    final scrollable = _scrollState(tester);
    final offset = scrollable.position.pixels;
    expect(offset, greaterThan(0));
    expect(_builtRows().length, lessThanOrEqualTo(30));

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Collection 280'), findsOneWidget);
    expect(action.hitTestable(), findsNothing);

    await tester.tap(find.byKey(const ValueKey('manageStub')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('manageStub')), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'collection 2',
    );
    expect(_scrollState(tester), same(scrollable));
    expect(scrollable.position.pixels, offset);
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('results box', () {
    testWidgets('keeps a short list height while typing', (tester) async {
      await open(
        tester,
        LibraryState(
          collectionScopes: [
            LibraryCollectionScope.favourites(),
            _manual('reading', 'Reading'),
            _site('tproger', 'tproger.ru'),
            _author(1, label: 'Seiken'),
          ],
        ),
      );
      // Favourites, Library and three rows, three titled groups and the
      // bottom breathing room.
      const expected = 5 * 48.0 + 3 * 36 + AppSpacing.xl;
      expect(_resultsHeight(tester), expected);
      await _type(tester, 'seik');
      expect(_resultsHeight(tester), expected);
      await _type(tester, 'zzz');
      expect(_resultsHeight(tester), expected);
      await _type(tester, '');
      expect(_resultsHeight(tester), expected);
    });
  });
}
