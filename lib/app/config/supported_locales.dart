import 'dart:ui' show Locale;

import 'package:shared/shared.dart';

/// Single source of truth for all locales supported by the app.
///
/// Add a new language here — MaterialApp, PreferencesService and the
/// language picker all pick it up automatically.
abstract final class SupportedLocales {
  static const languages = <SupportedLanguage>[
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

  static List<String> get codes => languages.map((l) => l.code).toList();
}
