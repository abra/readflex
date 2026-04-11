import 'package:equatable/equatable.dart' show Equatable;

/// An article imported from the web.
class Article extends Equatable {
  const Article({
    required this.id,
    required this.title,
    required this.url,
    required this.cleanedHtml,
    required this.addedAt,
    this.siteName,
    this.byline,
    this.excerpt,
    this.publishedTime,
    this.lang,
    this.coverImageUrl,
    this.textLength = 0,
    this.estimatedWordCount = 0,
    this.currentScrollOffset = 0.0,
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
  final String cleanedHtml;
  final String? coverImageUrl;
  final int textLength;
  final int estimatedWordCount;
  final double currentScrollOffset;
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
    String? cleanedHtml,
    Object? coverImageUrl = _absent,
    int? textLength,
    int? estimatedWordCount,
    double? currentScrollOffset,
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
    cleanedHtml: cleanedHtml ?? this.cleanedHtml,
    coverImageUrl: coverImageUrl == _absent
        ? this.coverImageUrl
        : coverImageUrl as String?,
    textLength: textLength ?? this.textLength,
    estimatedWordCount: estimatedWordCount ?? this.estimatedWordCount,
    currentScrollOffset: currentScrollOffset ?? this.currentScrollOffset,
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
    cleanedHtml,
    coverImageUrl,
    textLength,
    estimatedWordCount,
    currentScrollOffset,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
}
