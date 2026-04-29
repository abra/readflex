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
  });

  final ReaderStatus status;
  final String title;
  final Book? book;
  final List<Highlight> highlights;

  String? get sourceId => book?.id;

  static const _absent = Object();

  ReaderState copyWith({
    ReaderStatus? status,
    String? title,
    Object? book = _absent,
    List<Highlight>? highlights,
  }) => ReaderState(
    status: status ?? this.status,
    title: title ?? this.title,
    book: book == _absent ? this.book : book as Book?,
    highlights: highlights ?? this.highlights,
  );

  @override
  List<Object?> get props => [status, title, book, highlights];
}
