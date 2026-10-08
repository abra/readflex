import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';

LibrarySource _source(
  String id, {
  double progress = 0,
  DateTime? openedAt,
  bool finished = false,
  SourceType type = SourceType.book,
  bool comic = false,
}) => LibrarySource(
  id: id,
  sourceType: type,
  title: 'Title $id',
  typeLabel: 'EPUB',
  addedAt: DateTime(2026),
  readingProgress: progress,
  lastOpenedAt: openedAt,
  isFinished: finished,
  isComic: comic,
);

LibraryCollectionScope _builtIn(LibraryCollectionScopeType type, int count) =>
    LibraryCollectionScope.smart(
      type: type,
      id: type.name,
      label: type.name,
      sourceCount: count,
    );

void main() {
  group('continueReadingSource', () {
    test('is the most recently opened started source', () {
      final older = _source('older', progress: .3, openedAt: DateTime(2026, 2));
      final newer = _source('newer', progress: .6, openedAt: DateTime(2026, 3));
      final oldest = _source('oldest', progress: .1, openedAt: DateTime(2026));
      final state = LibraryState(sources: [older, newer, oldest]);
      expect(state.continueReadingSource, newer);
    });

    test('ignores ineligible sources even when they are more recent', () {
      final eligible = _source(
        'eligible',
        progress: .4,
        openedAt: DateTime(2026, 1),
      );
      final state = LibraryState(
        sources: [
          eligible,
          _source(
            'finished',
            progress: .5,
            openedAt: DateTime(2026, 6),
            finished: true,
          ),
          _source('unopened', progress: .5),
          _source('zero', openedAt: DateTime(2026, 6)),
          _source('complete', progress: 1, openedAt: DateTime(2026, 6)),
        ],
      );
      expect(state.continueReadingSource, eligible);
    });

    for (final (name, source) in [
      (
        'finished',
        _source('f', progress: .5, openedAt: DateTime(2026), finished: true),
      ),
      ('never opened', _source('u', progress: .5)),
      ('progress 0', _source('z', openedAt: DateTime(2026))),
      ('progress 1', _source('o', progress: 1, openedAt: DateTime(2026))),
      (
        'negative progress',
        _source('n', progress: -.1, openedAt: DateTime(2026)),
      ),
    ]) {
      test('is null when the only source is $name', () {
        expect(LibraryState(sources: [source]).continueReadingSource, isNull);
      });
    }

    test('is null for an empty library', () {
      expect(LibraryState().continueReadingSource, isNull);
    });

    test('ignores search and scope (the view decides)', () {
      final reading = _source('r', progress: .5, openedAt: DateTime(2026, 2));
      final state = LibraryState(
        sources: [reading],
        searchQuery: 'nothing',
        selectedCollectionScope: _builtIn(
          LibraryCollectionScopeType.articles,
          0,
        ),
      );
      expect(state.visibleItems, isEmpty);
      expect(state.continueReadingSource, reading);
    });

    test('is computed once per state', () {
      final state = LibraryState(
        sources: [_source('r', progress: .5, openedAt: DateTime(2026))],
      );
      expect(
        identical(state.continueReadingSource, state.continueReadingSource),
        isTrue,
      );
    });
  });

  group('isDefaultView', () {
    test('is true with no search and no scope', () {
      expect(LibraryState().isDefaultView, isTrue);
      expect(LibraryState(searchQuery: '   ').isDefaultView, isTrue);
    });

    test('is false while searching or scoped, built-in scopes included', () {
      expect(LibraryState(searchQuery: 'dune').isDefaultView, isFalse);
      expect(
        LibraryState(
          selectedCollectionScope: _builtIn(
            LibraryCollectionScopeType.books,
            1,
          ),
        ).isDefaultView,
        isFalse,
      );
      expect(
        LibraryState(
          selectedCollectionScope: LibraryCollectionScope.favourites(),
        ).isDefaultView,
        isFalse,
      );
    });
  });

  group('scopeItemCount', () {
    final sources = [_source('a'), _source('b'), _source('c')];

    test('counts the whole library without a scope', () {
      expect(LibraryState(sources: sources).scopeItemCount, 3);
    });

    test('counts the selected collection, ignoring search', () {
      final state = LibraryState(
        sources: sources,
        selectedCollectionScope: LibraryCollectionScope.favourites(
          sourceIds: ['a', 'c', 'missing'],
        ),
        searchQuery: 'nothing',
      );
      expect(state.scopeItemCount, 2);
      expect(state.totalCount, 3);
    });
  });

  group('built-in scopes', () {
    final book = _source('book');
    final comic = _source('comic', comic: true);
    final article = _source('article', type: SourceType.article);
    final opened = _source('opened', openedAt: DateTime(2026, 3));
    final started = _source('started', progress: .2);
    final sources = [book, comic, article, opened, started];

    test('match by what a source is, like the old filters', () {
      bool matches(LibraryCollectionScopeType type, LibrarySource source) =>
          libraryBuiltInScopeMatches(type, source);

      expect(matches(LibraryCollectionScopeType.books, book), isTrue);
      expect(matches(LibraryCollectionScopeType.books, comic), isFalse);
      expect(matches(LibraryCollectionScopeType.books, article), isFalse);
      expect(matches(LibraryCollectionScopeType.comics, comic), isTrue);
      expect(matches(LibraryCollectionScopeType.comics, book), isFalse);
      expect(matches(LibraryCollectionScopeType.articles, article), isTrue);
      expect(matches(LibraryCollectionScopeType.articles, book), isFalse);
      // New is never opened and nothing read, like the cover badge.
      expect(matches(LibraryCollectionScopeType.unread, book), isTrue);
      expect(matches(LibraryCollectionScopeType.unread, opened), isFalse);
      expect(matches(LibraryCollectionScopeType.unread, started), isFalse);
      for (final type in [
        LibraryCollectionScopeType.favourites,
        LibraryCollectionScopeType.manual,
        LibraryCollectionScopeType.site,
        LibraryCollectionScopeType.author,
      ]) {
        expect(matches(type, book), isFalse, reason: type.name);
        expect(type.isBuiltIn, isFalse);
      }
    });

    for (final (type, expected) in [
      (LibraryCollectionScopeType.books, ['book', 'opened', 'started']),
      (LibraryCollectionScopeType.comics, ['comic']),
      (LibraryCollectionScopeType.articles, ['article']),
      (LibraryCollectionScopeType.unread, ['article', 'book', 'comic']),
    ]) {
      test('${type.name} narrows the list and counts as the scope', () {
        final state = LibraryState(
          sources: sources,
          selectedCollectionScope: _builtIn(type, expected.length),
        );
        expect(state.visibleItems.map((s) => s.id).toSet(), expected.toSet());
        expect(state.scopeItemCount, expected.length);
        expect(state.totalCount, sources.length);
      });
    }

    test('search narrows inside a built-in scope', () {
      final state = LibraryState(
        sources: sources,
        selectedCollectionScope: _builtIn(LibraryCollectionScopeType.books, 3),
        searchQuery: 'title started',
      );
      expect(state.visibleItems.map((s) => s.id), ['started']);
      expect(state.scopeItemCount, 3);
    });
  });

  group('pickerBuiltInCollectionScopes', () {
    final sources = [_source('a'), _source('b'), _source('c')];
    final scopes = [
      _builtIn(LibraryCollectionScopeType.books, 2),
      _builtIn(LibraryCollectionScopeType.articles, 0),
      _builtIn(LibraryCollectionScopeType.comics, 1),
      // Every item is new: the row would only repeat Library.
      _builtIn(LibraryCollectionScopeType.unread, 3),
      LibraryCollectionScope.favourites(sourceIds: ['a']),
    ];

    test('lists only scopes that narrow the library', () {
      final state = LibraryState(sources: sources, collectionScopes: scopes);
      expect(
        state.pickerBuiltInCollectionScopes.map((scope) => scope.type),
        [LibraryCollectionScopeType.books, LibraryCollectionScopeType.comics],
      );
      expect(state.builtInCollectionScopes, hasLength(4));
    });

    test('keeps the selected scope even when empty or whole', () {
      for (final selected in [scopes[1], scopes[3]]) {
        final state = LibraryState(
          sources: sources,
          collectionScopes: scopes,
          selectedCollectionScope: selected,
        );
        expect(
          state.pickerBuiltInCollectionScopes,
          contains(selected),
          reason: selected.type.name,
        );
      }
    });

    test('keeps the fixed Books, Articles, Comics, New order', () {
      final reversed = [
        _builtIn(LibraryCollectionScopeType.unread, 1),
        _builtIn(LibraryCollectionScopeType.comics, 1),
        _builtIn(LibraryCollectionScopeType.articles, 1),
        _builtIn(LibraryCollectionScopeType.books, 1),
      ];
      final state = LibraryState(sources: sources, collectionScopes: reversed);
      // The bloc builds them in order; the state keeps whatever it is given.
      expect(
        state.pickerBuiltInCollectionScopes.map((scope) => scope.type),
        reversed.map((scope) => scope.type),
      );
      expect(LibraryCollectionScopeType.builtIn, [
        LibraryCollectionScopeType.books,
        LibraryCollectionScopeType.articles,
        LibraryCollectionScopeType.comics,
        LibraryCollectionScopeType.unread,
      ]);
    });
  });
}
