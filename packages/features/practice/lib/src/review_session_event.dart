part of 'review_session_bloc.dart';

sealed class ReviewSessionEvent extends Equatable {
  const ReviewSessionEvent();

  @override
  List<Object?> get props => const [];
}

final class ReviewSessionStarted extends ReviewSessionEvent {
  const ReviewSessionStarted();
}

final class ReviewSessionAnswerRevealed extends ReviewSessionEvent {
  const ReviewSessionAnswerRevealed();
}

final class ReviewSessionCardRated extends ReviewSessionEvent {
  const ReviewSessionCardRated(this.rating);

  final Rating rating;

  @override
  List<Object?> get props => [rating];
}

/// Drops the current card from review for good.
final class ReviewSessionCardRemoved extends ReviewSessionEvent {
  const ReviewSessionCardRemoved();
}

/// Starts over with the cards rated Again in the finished session.
final class ReviewSessionAgainRequested extends ReviewSessionEvent {
  const ReviewSessionAgainRequested();
}
