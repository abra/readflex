part of 'reader_bloc.dart';

enum ReaderStatus { initial, loading, ready, failure }

/// Snapshot of the loaded book and its highlights. Highlights are loaded
/// alongside the book and refreshed on demand via [ReaderHighlightsRefreshed].
class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.title = '',
    this.book,
    this.highlights = const [],
    this.chapterTitle,
    this.bookCurrentPage,
    this.bookTotalPages,
  });

  final ReaderStatus status;
  final String title;
  final Book? book;
  final List<Highlight> highlights;

  /// Live chapter / page metrics surfaced by foliate-js on every page
  /// turn. Used by the bottom chrome ("Book IV  ·  84") and not
  /// persisted — they're recomputed on every reader open.
  final String? chapterTitle;
  final int? bookCurrentPage;
  final int? bookTotalPages;

  String? get sourceId => book?.id;

  static const _absent = Object();

  ReaderState copyWith({
    ReaderStatus? status,
    String? title,
    Object? book = _absent,
    List<Highlight>? highlights,
    Object? chapterTitle = _absent,
    Object? bookCurrentPage = _absent,
    Object? bookTotalPages = _absent,
  }) => ReaderState(
    status: status ?? this.status,
    title: title ?? this.title,
    book: book == _absent ? this.book : book as Book?,
    highlights: highlights ?? this.highlights,
    chapterTitle: chapterTitle == _absent
        ? this.chapterTitle
        : chapterTitle as String?,
    bookCurrentPage: bookCurrentPage == _absent
        ? this.bookCurrentPage
        : bookCurrentPage as int?,
    bookTotalPages: bookTotalPages == _absent
        ? this.bookTotalPages
        : bookTotalPages as int?,
  );

  @override
  List<Object?> get props => [
    status,
    title,
    book,
    highlights,
    chapterTitle,
    bookCurrentPage,
    bookTotalPages,
  ];
}
