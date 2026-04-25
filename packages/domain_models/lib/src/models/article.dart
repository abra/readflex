import 'package:equatable/equatable.dart' show Equatable;

/// An article imported from the web.
///
/// Content (HTML) and cover image live on disk — see [contentPath] and
/// [coverImagePath]. Use `ArticleRepository.readContent(article)` to load
/// the HTML body; list queries do not hydrate it.
class Article extends Equatable {
  const Article({
    required this.id,
    required this.title,
    required this.url,
    required this.contentPath,
    required this.addedAt,
    this.siteName,
    this.byline,
    this.excerpt,
    this.publishedTime,
    this.lang,
    this.coverImageUrl,
    this.coverImagePath,
    this.textLength = 0,
    this.estimatedWordCount = 0,
    this.currentScrollOffset = 0.0,
    this.currentCfi,
    this.lastOpenedAt,
    this.isFinished = false,
  });

  final String id;
  final String title;
  final String? siteName;
  final String? byline;
  final String? excerpt;
  final String? publishedTime;
  final String? lang;
  final String url;

  /// Absolute path to the cleaned HTML file on disk, resolved against
  /// the current articles directory by [ArticleRepository]. The DB only
  /// persists the filename so the same row stays valid after the iOS
  /// Documents directory UUID changes across reinstalls.
  final String contentPath;

  /// Absolute path to the article packaged as a single-chapter EPUB.
  /// The reader opens this file through foliate-js so articles render
  /// with the same paginated UI as books. Sits in the same per-article
  /// directory as [contentPath]; produced on import by `EpubBuilder` and,
  /// for older articles, by the migration helper in `ArticleRepository`.
  String get epubPath {
    final lastSep = contentPath.lastIndexOf('/');
    return lastSep == -1
        ? 'article.epub'
        : '${contentPath.substring(0, lastSep + 1)}article.epub';
  }

  /// Original remote cover URL from article metadata. Kept as reference /
  /// fallback; prefer [coverImagePath] for display when available.
  final String? coverImageUrl;

  /// Absolute path to the locally cached cover image, or `null` if the
  /// article has no cover or the download failed. Like [contentPath],
  /// this is resolved by [ArticleRepository] at read time against the
  /// current covers directory.
  final String? coverImagePath;

  final int textLength;
  final int estimatedWordCount;

  /// Reading progress as a fraction in `[0.0, 1.0]`, where `1.0` is the
  /// bottom of the rendered article. Double-duties as both the saved
  /// restore position (reader jumps back here on reopen) AND the source
  /// the library cover reads for its progress pill — for articles these
  /// are the same number. Named `offset` for historical reasons; the
  /// value is a normalized fraction, not a raw pixel offset. A fraction
  /// stays portable across font size / text scale / device width
  /// changes that would invalidate raw pixels on reflow.
  ///
  /// Analogous to `Book.readingProgress`, but books additionally carry a
  /// separate `currentLocation` int for CFI-style restore because their
  /// restore key is a different type from their 0..1 progress. Articles
  /// don't need that split.
  final double currentScrollOffset;

  /// EPUB CFI restored on reopen — same role as [Book.currentCfi]. Articles
  /// render through foliate-js after import packages them as EPUB; the
  /// fraction in [currentScrollOffset] still flows to the catalog cover's
  /// progress pill. `null` until the article has been opened.
  final String? currentCfi;

  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isFinished;

  static const _absent = Object();

  Article copyWith({
    String? title,
    Object? siteName = _absent,
    Object? byline = _absent,
    Object? excerpt = _absent,
    Object? publishedTime = _absent,
    Object? lang = _absent,
    String? url,
    String? contentPath,
    Object? coverImageUrl = _absent,
    Object? coverImagePath = _absent,
    int? textLength,
    int? estimatedWordCount,
    double? currentScrollOffset,
    Object? currentCfi = _absent,
    Object? lastOpenedAt = _absent,
    bool? isFinished,
  }) => Article(
    id: id,
    title: title ?? this.title,
    siteName: siteName == _absent ? this.siteName : siteName as String?,
    byline: byline == _absent ? this.byline : byline as String?,
    excerpt: excerpt == _absent ? this.excerpt : excerpt as String?,
    publishedTime: publishedTime == _absent
        ? this.publishedTime
        : publishedTime as String?,
    lang: lang == _absent ? this.lang : lang as String?,
    url: url ?? this.url,
    contentPath: contentPath ?? this.contentPath,
    coverImageUrl: coverImageUrl == _absent
        ? this.coverImageUrl
        : coverImageUrl as String?,
    coverImagePath: coverImagePath == _absent
        ? this.coverImagePath
        : coverImagePath as String?,
    textLength: textLength ?? this.textLength,
    estimatedWordCount: estimatedWordCount ?? this.estimatedWordCount,
    currentScrollOffset: currentScrollOffset ?? this.currentScrollOffset,
    currentCfi: currentCfi == _absent ? this.currentCfi : currentCfi as String?,
    addedAt: addedAt,
    lastOpenedAt: lastOpenedAt == _absent
        ? this.lastOpenedAt
        : lastOpenedAt as DateTime?,
    isFinished: isFinished ?? this.isFinished,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    siteName,
    byline,
    excerpt,
    publishedTime,
    lang,
    url,
    contentPath,
    coverImageUrl,
    coverImagePath,
    textLength,
    estimatedWordCount,
    currentScrollOffset,
    currentCfi,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
}
