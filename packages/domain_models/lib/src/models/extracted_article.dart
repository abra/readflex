import 'package:equatable/equatable.dart' show Equatable;

import 'article_block.dart';

/// Clean article payload returned by the extraction backend before local
/// persistence assigns an id and file paths.
class ExtractedArticle extends Equatable {
  const ExtractedArticle({
    required this.requestedUrl,
    required this.title,
    required this.blocks,
    required this.plainText,
    required this.rawJson,
    this.resolvedUrl,
    this.canonicalUrl,
    this.author,
    this.date,
    this.site,
    this.hostname,
    this.description,
    this.imageUrl,
    this.language,
    this.categories = const [],
    this.tags = const [],
    this.license,
    this.fingerprint,
  });

  final String requestedUrl;
  final String? resolvedUrl;
  final String? canonicalUrl;
  final String title;
  final String? author;
  final String? date;
  final String? site;
  final String? hostname;
  final String? description;
  final String? imageUrl;
  final String? language;
  final List<String> categories;
  final List<String> tags;
  final String? license;
  final String? fingerprint;
  final List<ArticleBlock> blocks;
  final String plainText;

  /// Full backend response encoded as JSON. Stored verbatim for offline reads
  /// and future migrations when the backend adds metadata we do not yet model.
  final String rawJson;

  String get bestUrl => canonicalUrl ?? resolvedUrl ?? requestedUrl;

  int get wordCount {
    final trimmed = plainText.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  List<Object?> get props => [
    requestedUrl,
    resolvedUrl,
    canonicalUrl,
    title,
    author,
    date,
    site,
    hostname,
    description,
    imageUrl,
    language,
    categories,
    tags,
    license,
    fingerprint,
    blocks,
    plainText,
    rawJson,
  ];
}
