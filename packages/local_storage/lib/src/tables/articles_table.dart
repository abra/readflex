import 'package:drift/drift.dart';

class ArticlesTable extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get siteName => text().nullable()();

  TextColumn get url => text()();

  TextColumn get cleanedHtml => text()();

  TextColumn get coverImageUrl => text().nullable()();

  // Readability-extracted metadata. All nullable because some sites expose
  // only a subset of these fields.
  TextColumn get byline => text().nullable()();
  TextColumn get excerpt => text().nullable()();
  TextColumn get publishedTime => text().nullable()(); // ISO 8601 or raw
  TextColumn get lang => text().nullable()();

  /// Plain-text character count reported by readability_dart. Useful for
  /// ranking and reading-time estimates without re-parsing.
  IntColumn get textLength => integer().withDefault(const Constant(0))();

  IntColumn get estimatedWordCount =>
      integer().withDefault(const Constant(0))();

  RealColumn get currentScrollOffset =>
      real().withDefault(const Constant(0.0))();

  TextColumn get addedAt => text()(); // ISO 8601
  TextColumn get lastOpenedAt => text().nullable()(); // ISO 8601
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
