const defaultTranslationSourceLanguageCode = 'en';
const defaultTranslationTargetLanguageCode = 'ru';

final _cyrillicPattern = RegExp(r'[\u0400-\u04FF]');
final _latinPattern = RegExp(r'[A-Za-z]');

/// Detects the source language for the app's currently supported pairs.
///
/// This intentionally stays deterministic and local: it only distinguishes
/// Cyrillic from Latin text and falls back to English when the selection has
/// no useful alphabetic signal.
String detectTranslationSourceLanguage(
  String text, {
  String? contextText,
  String fallbackLanguageCode = defaultTranslationSourceLanguageCode,
}) {
  final selected = text.trim();
  final selectedLanguage = _detectFromSample(selected);
  if (selectedLanguage != null) return selectedLanguage;

  final contextLanguage = _detectFromSample(contextText?.trim() ?? '');
  if (contextLanguage != null) return contextLanguage;

  return fallbackLanguageCode;
}

String? _detectFromSample(String sample) {
  if (sample.isEmpty) return null;

  final cyrillicCount = _cyrillicPattern.allMatches(sample).length;
  final latinCount = _latinPattern.allMatches(sample).length;

  if (cyrillicCount > latinCount) return 'ru';
  if (latinCount > 0) return 'en';
  return null;
}
