import 'package:equatable/equatable.dart' show Equatable;

import 'article.dart';
import 'article_text_direction.dart';
import 'book.dart';
import 'book_format.dart';
import 'source_type.dart';

/// Lightweight projection used by Library and Details surfaces to render books
/// and web articles in one list without leaking repository-specific models
/// into view widgets.
class LibrarySource extends Equatable {
  const LibrarySource({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.typeLabel,
    required this.addedAt,
    this.author,
    this.sourceName,
    this.language,
    this.coverImagePath,
    this.readingProgress = 0.0,
    this.estimatedWordCount = 0,
    this.estimatedCharacterCount = 0,
    this.lastOpenedAt,
    this.isFinished = false,
    this.isComic = false,
    this.supportsReview = true,
  });

  factory LibrarySource.fromBook(Book book) => LibrarySource(
    id: book.id,
    sourceType: SourceType.book,
    title: book.title,
    author: book.author,
    sourceName: null,
    coverImagePath: book.coverImagePath,
    typeLabel: book.format.name.toUpperCase(),
    addedAt: book.addedAt,
    readingProgress: book.readingProgress,
    lastOpenedAt: book.lastOpenedAt,
    isFinished: book.isFinished,
    isComic: book.format == BookFormat.cbz,
    supportsReview: book.format != BookFormat.cbz,
  );

  factory LibrarySource.fromArticle(Article article) => LibrarySource(
    id: article.id,
    sourceType: SourceType.article,
    title: article.title,
    author: article.author,
    sourceName: article.siteName ?? article.hostname,
    language: article.language,
    coverImagePath: null,
    typeLabel: 'Article',
    addedAt: article.addedAt,
    readingProgress: article.readingProgress,
    estimatedWordCount: article.estimatedWordCount,
    estimatedCharacterCount: article.textLength,
    lastOpenedAt: article.lastOpenedAt,
    isFinished: article.isFinished,
    supportsReview: true,
  );

  final String id;
  final SourceType sourceType;
  final String title;
  final String? author;
  final String? sourceName;
  final String? language;
  final String? coverImagePath;
  final String typeLabel;
  final double readingProgress;
  final int estimatedWordCount;
  final int estimatedCharacterCount;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isFinished;
  final bool isComic;
  final bool supportsReview;

  bool get isNew => lastOpenedAt == null && readingProgress == 0;

  ArticleTextDirection? get inferredTextDirection {
    return articleTextDirectionForLanguage(language) ??
        inferArticleTextDirectionFromText(
          [title, author, sourceName].nonNulls.join(' '),
        );
  }

  @override
  List<Object?> get props => [
    id,
    sourceType,
    title,
    author,
    sourceName,
    language,
    coverImagePath,
    typeLabel,
    readingProgress,
    estimatedWordCount,
    estimatedCharacterCount,
    addedAt,
    lastOpenedAt,
    isFinished,
    isComic,
    supportsReview,
  ];
}
