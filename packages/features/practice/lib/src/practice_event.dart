part of 'practice_bloc.dart';

sealed class PracticeEvent extends Equatable {
  const PracticeEvent();

  @override
  List<Object?> get props => const [];
}

/// First load and every refresh.
final class PracticeLoadRequested extends PracticeEvent {
  const PracticeLoadRequested();
}
