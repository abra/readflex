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

final class CatalogSourceDeleted extends CatalogEvent {
  const CatalogSourceDeleted(this.sourceId, {required this.scope});

  final String sourceId;
  final BookDeletionScope scope;
}

final class CatalogSourcesDeleted extends CatalogEvent {
  const CatalogSourcesDeleted(this.sourceIds, {required this.scope});

  final Set<String> sourceIds;
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
