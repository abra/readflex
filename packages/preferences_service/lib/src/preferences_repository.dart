import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/material.dart' show ThemeMode;

import 'preferences.dart';
import 'preferences_storage.dart';

/// Loads and persists [Preferences] via [PreferencesStorage].
class PreferencesRepository {
  PreferencesRepository(this._storage);

  static const _key = 'app_preferences';

  final PreferencesStorage _storage;

  Future<Preferences> load(List<String> supportedCodes) async {
    final json = await _storage.getString(_key);
    if (json == null) {
      return Preferences(locale: _resolveInitialLocale(supportedCodes));
    }
    try {
      final map = jsonDecode(json) as Map<String, Object?>;
      return Preferences(
        themeMode: ThemeMode.values.byName(
          map['themeMode'] as String? ?? 'system',
        ),
        locale: _resolveLocale(map['locale'] as String?, supportedCodes),
        readerThemeId: map['readerThemeId'] as String? ?? 'paper',
        readerFontId: map['readerFontId'] as String? ?? 'serif',
        readerTextScale:
            (map['readerTextScale'] as num?)?.toDouble() ?? 1.0,
        readerLineHeight:
            (map['readerLineHeight'] as num?)?.toDouble() ?? 1.55,
        onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
        hasCompletedSetup: map['hasCompletedSetup'] as bool? ?? false,
      );
    } catch (_) {
      return const Preferences();
    }
  }

  Future<void> save(Preferences prefs) async {
    final map = <String, Object?>{
      'themeMode': prefs.themeMode.name,
      'locale': prefs.locale.languageCode,
      'readerThemeId': prefs.readerThemeId,
      'readerFontId': prefs.readerFontId,
      'readerTextScale': prefs.readerTextScale,
      'readerLineHeight': prefs.readerLineHeight,
      'onboardingCompleted': prefs.onboardingCompleted,
      'hasCompletedSetup': prefs.hasCompletedSetup,
    };
    await _storage.setString(_key, jsonEncode(map));
  }

  static Locale _resolveLocale(String? code, List<String> supportedCodes) {
    if (code != null && supportedCodes.contains(code)) return Locale(code);
    return _resolveInitialLocale(supportedCodes);
  }

  static Locale _resolveInitialLocale(List<String> supportedCodes) {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return Locale(supportedCodes.contains(code) ? code : 'en');
  }
}
