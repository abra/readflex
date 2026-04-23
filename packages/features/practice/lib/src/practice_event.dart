part of 'practice_bloc.dart';

/// Events accepted by [PracticeBloc].
sealed class PracticeEvent {
  const PracticeEvent();
}

/// Initial (or retry) load of the due queue.
final class PracticeLoadRequested extends PracticeEvent {
  const PracticeLoadRequested();
}

/// User tapped "Show Answer" on the current card.
final class PracticeCardRevealed extends PracticeEvent {
  const PracticeCardRevealed();
}

/// User chose an FSRS rating for the current card. Records the review
/// and advances to the next item.
final class PracticeCardRated extends PracticeEvent {
  const PracticeCardRated(this.rating);

  final Rating rating;
}

/// Advances past a highlight (no rating needed).
final class PracticeItemNext extends PracticeEvent {
  const PracticeItemNext();
}
