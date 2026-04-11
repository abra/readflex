import 'package:drift/drift.dart';

class ArticlesTable extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get siteName => text().nullable()();

  TextColumn get url => text()();

  /// Filename (not path) of the cleaned HTML file written to the app's
  /// articles directory during import — e.g. `<uuid>.html`. Resolved to
  /// an absolute path by `ArticleRepository` against the current
  /// articles directory on every read. Storing only the filename keeps
  /// rows valid across iOS Documents-UUID changes (happens on every
  /// clean reinstall of the simulator build), and keeps `allArticles()`
  /// cheap since the HTML body itself still lives on disk.
  TextColumn get contentPath => text()();

  /// Original remote cover image URL from the article metadata. Kept as
  /// reference / fallback when the local cache is missing.
  TextColumn get coverImageUrl => text().nullable()();

  /// Filename of the locally-cached cover image in the app's covers
  /// directory. Null if the cover couldn't be downloaded or the article
  /// has no cover. Resolved to an absolute path by `ArticleRepository`
  /// the same way [contentPath] is.
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
