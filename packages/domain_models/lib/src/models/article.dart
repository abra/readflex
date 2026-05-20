import 'package:equatable/equatable.dart' show Equatable;

/// Article saved from the web for offline reading.
///
/// The cleaned backend JSON and generated EPUB live on disk in the article's
/// directory; this model stores resolved absolute paths supplied by
/// `ArticleRepository`.
class Article extends Equatable {
  const Article({
    required this.id,
    required this.title,
    required this.url,
    required this.contentPath,
    required this.addedAt,
    this.resolvedUrl,
    this.canonicalUrl,
    this.author,
    this.siteName,
    this.hostname,
    this.description,
    this.imageUrl,
    this.coverImagePath,
    this.language,
    this.plainText = '',
    this.textLength = 0,
    this.estimatedWordCount = 0,
    this.currentCfi,
    this.readingProgress = 0.0,
    this.lastOpenedAt,
    this.isFinished = false,
  });

  final String id;
  final String title;
  final String url;
  final String? resolvedUrl;
  final String? canonicalUrl;
  final String? author;
  final String? siteName;
  final String? hostname;
  final String? description;
  final String? imageUrl;
  final String? coverImagePath;
  final String? language;

  /// Absolute path to the stored extraction JSON.
  final String contentPath;

  String get epubPath {
    final slash = contentPath.lastIndexOf('/');
    if (slash == -1) return 'article.epub';
    return '${contentPath.substring(0, slash + 1)}article.epub';
  }

  final String plainText;
  final int textLength;
  final int estimatedWordCount;
  final String? currentCfi;
  final double readingProgress;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isFinished;

  static const _absent = Object();

  Article copyWith({
    String? title,
    String? url,
    Object? resolvedUrl = _absent,
    Object? canonicalUrl = _absent,
    Object? author = _absent,
    Object? siteName = _absent,
    Object? hostname = _absent,
    Object? description = _absent,
    Object? imageUrl = _absent,
    Object? coverImagePath = _absent,
    Object? language = _absent,
    String? contentPath,
    String? plainText,
    int? textLength,
    int? estimatedWordCount,
    Object? currentCfi = _absent,
    double? readingProgress,
    Object? lastOpenedAt = _absent,
    bool? isFinished,
  }) => Article(
    id: id,
    title: title ?? this.title,
    url: url ?? this.url,
    resolvedUrl: resolvedUrl == _absent
        ? this.resolvedUrl
        : resolvedUrl as String?,
    canonicalUrl: canonicalUrl == _absent
        ? this.canonicalUrl
        : canonicalUrl as String?,
    author: author == _absent ? this.author : author as String?,
    siteName: siteName == _absent ? this.siteName : siteName as String?,
    hostname: hostname == _absent ? this.hostname : hostname as String?,
    description: description == _absent
        ? this.description
        : description as String?,
    imageUrl: imageUrl == _absent ? this.imageUrl : imageUrl as String?,
    coverImagePath: coverImagePath == _absent
        ? this.coverImagePath
        : coverImagePath as String?,
    language: language == _absent ? this.language : language as String?,
    contentPath: contentPath ?? this.contentPath,
    plainText: plainText ?? this.plainText,
    textLength: textLength ?? this.textLength,
    estimatedWordCount: estimatedWordCount ?? this.estimatedWordCount,
    currentCfi: currentCfi == _absent ? this.currentCfi : currentCfi as String?,
    readingProgress: readingProgress ?? this.readingProgress,
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
    url,
    resolvedUrl,
    canonicalUrl,
    author,
    siteName,
    hostname,
    description,
    imageUrl,
    coverImagePath,
    language,
    contentPath,
    plainText,
    textLength,
    estimatedWordCount,
    currentCfi,
    readingProgress,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
}
