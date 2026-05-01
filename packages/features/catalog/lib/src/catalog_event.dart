part of 'catalog_bloc.dart';

sealed class CatalogEvent {
  const CatalogEvent();
}

final class CatalogLoadRequested extends CatalogEvent {
  const CatalogLoadRequested();
}

final class CatalogRefreshRequested extends CatalogEvent {
  const CatalogRefreshRequested();
}

final class CatalogBookDeleted extends CatalogEvent {
  const CatalogBookDeleted(this.bookId, {required this.scope});

  final String bookId;
  final BookDeletionScope scope;
}

final class CatalogBooksDeleted extends CatalogEvent {
  const CatalogBooksDeleted(this.bookIds, {required this.scope});

  final Set<String> bookIds;
  final BookDeletionScope scope;
}

final class CatalogSearchQueryChanged extends CatalogEvent {
  const CatalogSearchQueryChanged(this.query);

  final String query;
}

final class CatalogFilterChanged extends CatalogEvent {
  const CatalogFilterChanged(this.filter);

  final CatalogFilter filter;
}
