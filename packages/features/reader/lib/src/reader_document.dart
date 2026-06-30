part of 'reader_bloc.dart';

/// Source-neutral document shape used by the reader UI.
///
/// Books keep their real [BookFormat]. Saved articles point directly at
/// `content.html` and intentionally have no book format, so UI logic cannot
/// accidentally treat them as EPUB files.
class ReaderDocument extends Equatable {
  const ReaderDocument({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.filePath,
    required this.addedAt,
    this.author,
    this.coverImagePath,
    this.format,
    this.totalLocations = 0,
    this.currentLocation = 0,
    this.currentCfi,
    this.readingProgress = 0,
    this.lastOpenedAt,
    this.isFinished = false,
  });

  factory ReaderDocument.fromBook(Book book) {
    return ReaderDocument(
      id: book.id,
      sourceType: SourceType.book,
      title: book.title,
      author: book.author,
      coverImagePath: book.coverImagePath,
      format: book.format,
      filePath: book.filePath,
      totalLocations: book.totalLocations,
      currentLocation: book.currentLocation,
      currentCfi: book.currentCfi,
      readingProgress: book.readingProgress,
      addedAt: book.addedAt,
      lastOpenedAt: book.lastOpenedAt,
      isFinished: book.isFinished,
    );
  }

  factory ReaderDocument.fromArticle(Article article) {
    return ReaderDocument(
      id: article.id,
      sourceType: SourceType.article,
      title: article.title,
      author: article.author ?? article.siteName ?? article.hostname,
      coverImagePath: article.coverImagePath,
      filePath: article.contentHtmlPath,
      currentCfi: article.currentCfi,
      readingProgress: article.readingProgress,
      addedAt: article.addedAt,
      lastOpenedAt: article.lastOpenedAt,
      isFinished: article.isFinished,
    );
  }

  final String id;
  final SourceType sourceType;
  final String title;
  final String? author;
  final String? coverImagePath;
  final BookFormat? format;
  final String filePath;
  final int totalLocations;
  final int currentLocation;
  final String? currentCfi;
  final double readingProgress;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isFinished;

  static const _absent = Object();

  ReaderDocument copyWith({
    Object? currentCfi = _absent,
    double? readingProgress,
    Object? lastOpenedAt = _absent,
    bool? isFinished,
  }) {
    return ReaderDocument(
      id: id,
      sourceType: sourceType,
      title: title,
      author: author,
      coverImagePath: coverImagePath,
      format: format,
      filePath: filePath,
      totalLocations: totalLocations,
      currentLocation: currentLocation,
      currentCfi: currentCfi == _absent
          ? this.currentCfi
          : currentCfi as String?,
      readingProgress: readingProgress ?? this.readingProgress,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt == _absent
          ? this.lastOpenedAt
          : lastOpenedAt as DateTime?,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  Book toBook() {
    final bookFormat = format;
    if (sourceType != SourceType.book || bookFormat == null) {
      throw StateError('Only book reader documents can be converted to Book.');
    }
    return Book(
      id: id,
      title: title,
      author: author,
      coverImagePath: coverImagePath,
      format: bookFormat,
      filePath: filePath,
      totalLocations: totalLocations,
      currentLocation: currentLocation,
      currentCfi: currentCfi,
      readingProgress: readingProgress,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt,
      isFinished: isFinished,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sourceType,
    title,
    author,
    coverImagePath,
    format,
    filePath,
    totalLocations,
    currentLocation,
    currentCfi,
    readingProgress,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
}
