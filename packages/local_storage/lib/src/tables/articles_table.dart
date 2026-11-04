import 'package:drift/drift.dart';

/// Drift schema for web articles saved through the extraction backend.
///
/// Structured JSON, reader HTML and images live under `articles/<id>/`;
/// [contentPath] stores the JSON filename so paths survive iOS directory changes.
/// [plainText] also keeps the extracted body in SQLite for full article reads.
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

  IntColumn get textLength => integer().withDefault(const Constant(0))();

  IntColumn get estimatedWordCount =>
      integer().withDefault(const Constant(0))();

  TextColumn get currentCfi => text().nullable()();

  RealColumn get readingProgress => real().withDefault(const Constant(0.0))();

  TextColumn get addedAt => text()();

  TextColumn get lastOpenedAt => text().nullable()();

  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  /// Last on purpose: SQLite reads a row's columns in order, so any column
  /// after a long text walks its overflow pages. The Library's metadata
  /// query then never touches the article text.
  TextColumn get plainText => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
