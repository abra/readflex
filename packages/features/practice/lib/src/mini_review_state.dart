part of 'mini_review_cubit.dart';

/// Lifecycle of an in-reader mini review session.
enum MiniReviewStatus { loading, reviewing, empty, completed, failure }

/// State of the in-reader mini review: source-scoped due items plus the
/// same cursor shape as [PracticeState] so both sessions can reuse the
/// card widgets in `review_card_views.dart`.
class MiniReviewState extends Equatable {
  const MiniReviewState({
    this.status = MiniReviewStatus.loading,
    this.items = const [],
    this.currentIndex = 0,
    this.isRevealed = false,
  });

  final MiniReviewStatus status;
  final List<PracticeItem> items;
  final int currentIndex;
  final bool isRevealed;

  PracticeItem? get currentItem =>
      currentIndex < items.length ? items[currentIndex] : null;

  int get remaining => items.length - currentIndex;

  int get reviewed => currentIndex;

  MiniReviewState copyWith({
    MiniReviewStatus? status,
    List<PracticeItem>? items,
    int? currentIndex,
    bool? isRevealed,
  }) => MiniReviewState(
    status: status ?? this.status,
    items: items ?? this.items,
    currentIndex: currentIndex ?? this.currentIndex,
    isRevealed: isRevealed ?? this.isRevealed,
  );

  @override
  List<Object?> get props => [status, items, currentIndex, isRevealed];
}
