import 'package:drift/drift.dart';

/// Drift schema for imported articles. Body HTML and cover images live on
/// disk under the app's articles directory; rows store only filenames (see
/// [contentPath], [coverImagePath]) so they stay valid across iOS
/// Documents-UUID changes. Paired with `ArticleRepository` which owns
/// resolution, download, and cleanup of those files.
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

  /// Reading progress as a normalized `[0, 1]` fraction. Used by the
  /// catalog cover for the progress pill. Stays in sync with [currentCfi]:
  /// the reader writes both on every position update.
  RealColumn get currentScrollOffset =>
      real().withDefault(const Constant(0.0))();

  /// EPUB CFI string used to restore reader position when the article is
  /// reopened. Articles render through foliate-js (the import pipeline
  /// packages each one as a single-chapter EPUB), so position is a CFI
  /// just like books rather than a raw scroll fraction. Null when the
  /// article hasn't been opened yet.
  TextColumn get currentCfi => text().nullable()();

  TextColumn get addedAt => text()(); // ISO 8601
  TextColumn get lastOpenedAt => text().nullable()(); // ISO 8601
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
