part of 'reader_bloc.dart';

enum ReaderStatus { initial, loading, ready, failure }

final class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.sourceType,
    this.title = '',
    this.book,
    this.article,
    this.highlights = const [],
    this.selectedText = '',
    this.selectionCfiRange,
    this.selectionPageNumber,
    this.selectionScrollOffset,
    this.hasSelection = false,
    this.showReviewReminder = false,
  });

  final ReaderStatus status;
  final SourceType? sourceType;
  final String title;
  final Book? book;
  final Article? article;
  final List<Highlight> highlights;

  // Text selection
  final String selectedText;
  final String? selectionCfiRange;
  final int? selectionPageNumber;
  final double? selectionScrollOffset;
  final bool hasSelection;

  // Review reminder
  final bool showReviewReminder;

  /// The source ID (book or article).
  String? get sourceId => book?.id ?? article?.id;

  /// Whether the source is a book.
  bool get isBook => sourceType == SourceType.book;

  /// Whether the source is an article.
  bool get isArticle => sourceType == SourceType.article;

  static const _absent = Object();

  ReaderState copyWith({
    ReaderStatus? status,
    Object? sourceType = _absent,
    String? title,
    Object? book = _absent,
    Object? article = _absent,
    List<Highlight>? highlights,
    String? selectedText,
    Object? selectionCfiRange = _absent,
    Object? selectionPageNumber = _absent,
    Object? selectionScrollOffset = _absent,
    bool? hasSelection,
    bool? showReviewReminder,
  }) => ReaderState(
    status: status ?? this.status,
    sourceType: sourceType == _absent
        ? this.sourceType
        : sourceType as SourceType?,
    title: title ?? this.title,
    book: book == _absent ? this.book : book as Book?,
    article: article == _absent ? this.article : article as Article?,
    highlights: highlights ?? this.highlights,
    selectedText: selectedText ?? this.selectedText,
    selectionCfiRange: selectionCfiRange == _absent
        ? this.selectionCfiRange
        : selectionCfiRange as String?,
    selectionPageNumber: selectionPageNumber == _absent
        ? this.selectionPageNumber
        : selectionPageNumber as int?,
    selectionScrollOffset: selectionScrollOffset == _absent
        ? this.selectionScrollOffset
        : selectionScrollOffset as double?,
    hasSelection: hasSelection ?? this.hasSelection,
    showReviewReminder: showReviewReminder ?? this.showReviewReminder,
  );

  @override
  List<Object?> get props => [
    status,
    sourceType,
    title,
    book,
    article,
    highlights,
    selectedText,
    selectionCfiRange,
    selectionPageNumber,
    selectionScrollOffset,
    hasSelection,
    showReviewReminder,
  ];
}
