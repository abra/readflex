import 'package:drift/drift.dart';

class ArticlesTable extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get siteName => text().nullable()();

  TextColumn get url => text()();

  /// Absolute path to the cleaned HTML file on disk, written during import.
  /// Article body lives on disk rather than in the DB so [allArticles] stays
  /// cheap — list queries no longer hydrate megabytes of HTML per row.
  TextColumn get contentPath => text()();

  /// Original remote cover image URL from the article metadata. Kept as
  /// reference / fallback when the local cache is missing.
  TextColumn get coverImageUrl => text().nullable()();

  /// Absolute path to the locally-cached cover image. Null if the cover
  /// couldn't be downloaded or the article has no cover.
  TextColumn get coverImagePath => text().nullable()();

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
