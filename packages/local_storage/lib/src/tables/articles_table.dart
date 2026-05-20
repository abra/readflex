import 'package:drift/drift.dart';

/// Drift schema for web articles saved through the extraction backend.
///
/// Heavy content stays on disk under `articles/<id>/`; [contentPath] stores
/// only the JSON filename so rows survive iOS Documents-directory changes.
class ArticlesTable extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get url => text()();

  TextColumn get resolvedUrl => text().nullable()();

  TextColumn get canonicalUrl => text().nullable()();

  TextColumn get author => text().nullable()();

  TextColumn get siteName => text().nullable()();

  TextColumn get hostname => text().nullable()();

  TextColumn get description => text().nullable()();

  TextColumn get imageUrl => text().nullable()();

  TextColumn get coverImagePath => text().nullable()();

  TextColumn get language => text().nullable()();

  TextColumn get contentPath => text()();

  TextColumn get plainText => text().withDefault(const Constant(''))();

  IntColumn get textLength => integer().withDefault(const Constant(0))();

  IntColumn get estimatedWordCount =>
      integer().withDefault(const Constant(0))();

  TextColumn get currentCfi => text().nullable()();

  RealColumn get readingProgress => real().withDefault(const Constant(0.0))();

  TextColumn get addedAt => text()();

  TextColumn get lastOpenedAt => text().nullable()();

  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
