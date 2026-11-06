part of 'review_session_bloc.dart';

sealed class ReviewSessionEvent extends Equatable {
  const ReviewSessionEvent();

  @override
  List<Object?> get props => const [];
}

final class ReviewSessionStarted extends ReviewSessionEvent {
  const ReviewSessionStarted();
}

sealed class ReviewSessionCardEvent extends ReviewSessionEvent {
  const ReviewSessionCardEvent(this.card);

  final ReviewSessionCardIdentity card;

  @override
  List<Object?> get props => [card];
}

final class ReviewSessionAnswerRevealed extends ReviewSessionCardEvent {
  const ReviewSessionAnswerRevealed(super.card);
}

final class ReviewSessionCardRated extends ReviewSessionCardEvent {
  const ReviewSessionCardRated(super.card, this.rating);

  final Rating rating;

  @override
  List<Object?> get props => [card, rating];
}

/// Removes the displayed card's current review row.
final class ReviewSessionCardRemoved extends ReviewSessionCardEvent {
  const ReviewSessionCardRemoved(super.card);
}

/// Starts over with the cards rated Again in the finished session.
final class ReviewSessionAgainRequested extends ReviewSessionEvent {
  const ReviewSessionAgainRequested();
}
