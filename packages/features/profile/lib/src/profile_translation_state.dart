part of 'profile_translation_cubit.dart';

/// Snapshot of translation language preferences shown on [ProfileScreen].
class ProfileTranslationState extends Equatable {
  const ProfileTranslationState({
    required this.targetLanguageCode,
    required this.sourceLanguageCode,
  });

  factory ProfileTranslationState.fromPreferences(Preferences preferences) {
    return ProfileTranslationState(
      targetLanguageCode: preferences.translationTargetLanguageCode,
      sourceLanguageCode: preferences.translationSourceLanguageCode,
    );
  }

  final String targetLanguageCode;

  /// `null` means "Auto".
  final String? sourceLanguageCode;

  @override
  List<Object?> get props => [targetLanguageCode, sourceLanguageCode];
}
