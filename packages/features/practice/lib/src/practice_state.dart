part of 'practice_bloc.dart';

enum PracticeStatus { initial, loading, ready, failure }

class PracticeState extends Equatable {
  const PracticeState({
    this.status = PracticeStatus.initial,
    this.stats = const ReviewStats(),
    this.sources = const [],
    this.reviewHighlights = true,
  });

  final PracticeStatus status;
  final ReviewStats stats;

  /// Sources with saved words or highlights, most due first.
  final List<PracticeSourceSummary> sources;

  /// The Profile setting: whether highlights take part in reviews.
  final bool reviewHighlights;

  /// Due cards a session would show, honouring [reviewHighlights].
  int get due =>
      stats.dueOf(ReviewableType.dictionary) +
      (reviewHighlights ? stats.dueOf(ReviewableType.highlight) : 0);

  int get total =>
      stats.totalOf(ReviewableType.dictionary) +
      stats.totalOf(ReviewableType.highlight);

  bool get hasNothing => total == 0;

  PracticeState copyWith({
    PracticeStatus? status,
    ReviewStats? stats,
    List<PracticeSourceSummary>? sources,
    bool? reviewHighlights,
  }) => PracticeState(
    status: status ?? this.status,
    stats: stats ?? this.stats,
    sources: sources ?? this.sources,
    reviewHighlights: reviewHighlights ?? this.reviewHighlights,
  );

  @override
  List<Object?> get props => [status, stats, sources, reviewHighlights];
}
