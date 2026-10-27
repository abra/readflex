part of 'practice_settings_cubit.dart';

/// What the Practice settings sheet shows: each preference as the choice it
/// is nearest to.
class PracticeSettingsState extends Equatable {
  const PracticeSettingsState({
    required this.newCardsPerDay,
    required this.reviewHighlights,
    required this.memoryTarget,
  });

  /// The stored values as the sheet's choices.
  factory PracticeSettingsState.of(Preferences prefs) => PracticeSettingsState(
    newCardsPerDay: nearestNewCardsPreset(prefs.practiceNewCardsPerDay),
    reviewHighlights: prefs.practiceReviewHighlights,
    memoryTarget: PracticeMemoryTarget.nearest(prefs.practiceDesiredRetention),
  );

  /// One of [practiceNewCardsPresets].
  final int newCardsPerDay;
  final bool reviewHighlights;
  final PracticeMemoryTarget memoryTarget;

  PracticeSettingsState copyWith({
    int? newCardsPerDay,
    bool? reviewHighlights,
    PracticeMemoryTarget? memoryTarget,
  }) => PracticeSettingsState(
    newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
    reviewHighlights: reviewHighlights ?? this.reviewHighlights,
    memoryTarget: memoryTarget ?? this.memoryTarget,
  );

  @override
  List<Object?> get props => [newCardsPerDay, reviewHighlights, memoryTarget];
}
