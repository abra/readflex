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
  const CatalogBookDeleted(this.bookId);

  final String bookId;
}

final class CatalogSearchQueryChanged extends CatalogEvent {
  const CatalogSearchQueryChanged(this.query);

  final String query;
}

final class CatalogFilterChanged extends CatalogEvent {
  const CatalogFilterChanged(this.filter);

  final CatalogFilter filter;
}
