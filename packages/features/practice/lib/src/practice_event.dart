part of 'practice_bloc.dart';

sealed class PracticeEvent {
  const PracticeEvent();
}

final class PracticeLoadRequested extends PracticeEvent {
  const PracticeLoadRequested();
}

final class PracticeCardRevealed extends PracticeEvent {
  const PracticeCardRevealed();
}

final class PracticeCardRated extends PracticeEvent {
  const PracticeCardRated(this.rating);
  final Rating rating;
}
