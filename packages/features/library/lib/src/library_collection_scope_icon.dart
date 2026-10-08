import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'library_bloc.dart';

/// The glyph a collection scope shows wherever it is named: its Collections
/// picker row and the bottom collection switcher. The whole Library uses
/// [AppIcons.library].
IconData libraryCollectionScopeIcon(LibraryCollectionScopeType type) {
  return switch (type) {
    LibraryCollectionScopeType.books => AppIcons.book,
    LibraryCollectionScopeType.articles => AppIcons.article,
    LibraryCollectionScopeType.comics => AppIcons.comic,
    LibraryCollectionScopeType.unread => AppIcons.newItems,
    LibraryCollectionScopeType.favourites => AppIcons.collectionFavourites,
    LibraryCollectionScopeType.manual => AppIcons.collection,
    LibraryCollectionScopeType.site => AppIcons.global,
    LibraryCollectionScopeType.author => AppIcons.author,
  };
}
