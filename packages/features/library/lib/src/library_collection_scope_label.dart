import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';

String libraryCollectionScopeLabel(
  ReadflexLocalizations l10n,
  LibraryCollectionScope scope,
) {
  return switch (scope.type) {
    LibraryCollectionScopeType.favourites => l10n.libraryFavourites,
    LibraryCollectionScopeType.manual ||
    LibraryCollectionScopeType.site ||
    LibraryCollectionScopeType.author => scope.label,
  };
}
