import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';

String libraryCollectionScopeLabel(
  ReadflexLocalizations l10n,
  LibraryCollectionScope scope,
) {
  return switch (scope.type) {
    LibraryCollectionScopeType.books => l10n.libraryScopeBooks,
    LibraryCollectionScopeType.articles => l10n.libraryScopeArticles,
    LibraryCollectionScopeType.comics => l10n.libraryScopeComics,
    LibraryCollectionScopeType.unread => l10n.libraryScopeNew,
    LibraryCollectionScopeType.favourites => l10n.libraryFavourites,
    LibraryCollectionScopeType.manual ||
    LibraryCollectionScopeType.site ||
    LibraryCollectionScopeType.author => scope.label,
  };
}
