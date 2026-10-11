import 'contextual_translation_models.dart' show autoSourceLanguageCode;

final _subtagSeparator = RegExp(r'[-_]');

/// The primary language subtag of [code], lowercased: `en` for `EN`, `en-US`
/// or `en_GB`. Null for a missing or blank code.
String? translationLanguagePrimaryCode(String? code) {
  final normalized = code?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.split(_subtagSeparator).first;
}

/// Whether [a] and [b] name the same concrete language, ignoring case and
/// region or script subtags. `auto` and missing codes never match, so an
/// undetected source is never "the same" as a target.
///
/// Comparing primary subtags treats `zh-Hant` and `zh-Hans` as one language;
/// the app offers a single Chinese, so there is no script pair to translate.
bool isSameTranslationLanguage(String? a, String? b) {
  final left = translationLanguagePrimaryCode(a);
  if (left == null || left == autoSourceLanguageCode) return false;
  return left == translationLanguagePrimaryCode(b);
}
