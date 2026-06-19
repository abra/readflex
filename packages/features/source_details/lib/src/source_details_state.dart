part of 'source_details_bloc.dart';

enum SourceDetailsStatus { initial, loading, success, notFound, failure }

class SourceDetailsState extends Equatable {
  const SourceDetailsState({
    this.status = SourceDetailsStatus.initial,
    this.source,
    this.readerBook,
    this.reviewSummary = const SourceReviewSummary.empty(),
  });

  final SourceDetailsStatus status;
  final LibrarySource? source;
  final Book? readerBook;
  final SourceReviewSummary reviewSummary;

  bool get showReviewSection {
    final source = this.source;
    return source != null && source.supportsReview;
  }

  SourceDetailsState copyWith({
    SourceDetailsStatus? status,
    LibrarySource? source,
    Book? readerBook,
    SourceReviewSummary? reviewSummary,
  }) => SourceDetailsState(
    status: status ?? this.status,
    source: source ?? this.source,
    readerBook: readerBook ?? this.readerBook,
    reviewSummary: reviewSummary ?? this.reviewSummary,
  );

  @override
  List<Object?> get props => [status, source, readerBook, reviewSummary];
}

class SourceReviewSummary extends Equatable {
  const SourceReviewSummary({
    required this.highlightCount,
  });

  const SourceReviewSummary.empty() : highlightCount = 0;

  final int highlightCount;

  @override
  List<Object?> get props => [highlightCount];
}
