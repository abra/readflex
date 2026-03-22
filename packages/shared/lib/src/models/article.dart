import 'package:equatable/equatable.dart' show Equatable;

/// An article imported from the web.
final class Article extends Equatable {
  const Article({
    required this.id,
    required this.title,
    required this.url,
    required this.cleanedHtml,
    required this.addedAt,
    this.siteName,
    this.coverImageUrl,
    this.estimatedWordCount = 0,
    this.currentScrollOffset = 0.0,
    this.lastOpenedAt,
    this.isFinished = false,
  });

  final String id;
  final String title;
  final String? siteName;
  final String url;
  final String cleanedHtml;
  final String? coverImageUrl;
  final int estimatedWordCount;
  final double currentScrollOffset;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isFinished;

  static const _absent = Object();

  Article copyWith({
    String? title,
    Object? siteName = _absent,
    String? url,
    String? cleanedHtml,
    Object? coverImageUrl = _absent,
    int? estimatedWordCount,
    double? currentScrollOffset,
    Object? lastOpenedAt = _absent,
    bool? isFinished,
  }) => Article(
    id: id,
    title: title ?? this.title,
    siteName: siteName == _absent ? this.siteName : siteName as String?,
    url: url ?? this.url,
    cleanedHtml: cleanedHtml ?? this.cleanedHtml,
    coverImageUrl: coverImageUrl == _absent
        ? this.coverImageUrl
        : coverImageUrl as String?,
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
    url,
    cleanedHtml,
    coverImageUrl,
    estimatedWordCount,
    currentScrollOffset,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
}
