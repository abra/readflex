import 'dart:ui' show Locale;

typedef ReadflexSupportedLanguage = ({String code, String name});

/// Single source of truth for app locales.
abstract final class ReadflexSupportedLocales {
  static const languages = <ReadflexSupportedLanguage>[
    (code: 'en', name: 'English'),
    (code: 'zh', name: '中文（简体）'),
    (code: 'hi', name: 'हिन्दी'),
    (code: 'es', name: 'Español'),
    (code: 'ar', name: 'العربية'),
    (code: 'fr', name: 'Français'),
    (code: 'ru', name: 'Русский'),
    (code: 'pt', name: 'Português'),
    (code: 'de', name: 'Deutsch'),
    (code: 'ja', name: '日本語'),
  ];

  static const locales = [
    Locale('en'),
    Locale('zh'),
    Locale('hi'),
    Locale('es'),
    Locale('ar'),
    Locale('fr'),
    Locale('ru'),
    Locale('pt'),
    Locale('de'),
    Locale('ja'),
  ];

  static List<String> get codes => [
    for (final language in languages) language.code,
  ];
}
