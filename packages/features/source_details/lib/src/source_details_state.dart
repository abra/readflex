part of 'source_details_bloc.dart';

enum SourceDetailsStatus { initial, loading, success, notFound, failure }

class SourceDetailsState extends Equatable {
  const SourceDetailsState({
    this.status = SourceDetailsStatus.initial,
    this.source,
    this.reviewSummary = const SourceReviewSummary.empty(),
  });

  final SourceDetailsStatus status;
  final Book? source;
  final SourceReviewSummary reviewSummary;

  SourceDetailsState copyWith({
    SourceDetailsStatus? status,
    Book? source,
    SourceReviewSummary? reviewSummary,
  }) => SourceDetailsState(
    status: status ?? this.status,
    source: source ?? this.source,
    reviewSummary: reviewSummary ?? this.reviewSummary,
  );

  @override
  List<Object?> get props => [status, source, reviewSummary];
}

class SourceReviewSummary extends Equatable {
  const SourceReviewSummary({
    required this.highlightCount,
    required this.flashcardCount,
    required this.dictionaryEntryCount,
  });

  const SourceReviewSummary.empty()
    : highlightCount = 0,
      flashcardCount = 0,
      dictionaryEntryCount = 0;

  final int highlightCount;
  final int flashcardCount;
  final int dictionaryEntryCount;

  @override
  List<Object?> get props => [
    highlightCount,
    flashcardCount,
    dictionaryEntryCount,
  ];
}
