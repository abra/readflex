part of 'reader_bloc.dart';

enum ReaderStatus { initial, loading, ready, failure }

class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.sourceType,
    this.title = '',
    this.book,
    this.article,
    this.highlights = const [],
  });

  final ReaderStatus status;
  final SourceType? sourceType;
  final String title;
  final Book? book;
  final Article? article;
  final List<Highlight> highlights;

  String? get sourceId => book?.id ?? article?.id;

  bool get isBook => sourceType == SourceType.book;

  bool get isArticle => sourceType == SourceType.article;

  static const _absent = Object();

  ReaderState copyWith({
    ReaderStatus? status,
    Object? sourceType = _absent,
    String? title,
    Object? book = _absent,
    Object? article = _absent,
    List<Highlight>? highlights,
  }) => ReaderState(
    status: status ?? this.status,
    sourceType: sourceType == _absent
        ? this.sourceType
        : sourceType as SourceType?,
    title: title ?? this.title,
    book: book == _absent ? this.book : book as Book?,
    article: article == _absent ? this.article : article as Article?,
    highlights: highlights ?? this.highlights,
  );

  @override
  List<Object?> get props => [
    status,
    sourceType,
    title,
    book,
    article,
    highlights,
  ];
}
