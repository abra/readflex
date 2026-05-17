import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:developer' as developer;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/material.dart' show ThemeMode;

import 'preferences.dart';
import 'preferences_storage.dart';

/// Serialises [Preferences] to/from a single JSON blob in
/// [PreferencesStorage]. Owns the schema (key names, default values) and
/// fallback logic: corrupt JSON on disk falls back to defaults so the app
/// still launches.
class PreferencesRepository {
  PreferencesRepository(this._storage);

  static const _key = 'app_preferences';

  /// Bumped when a stored-prefs default needs to be forced for existing
  /// installs whose JSON predates the change. Each migration step happens
  /// at most once per device (the new version is persisted on next save).
  ///
  /// History:
  ///   1: initial schema (implicit; no version key in JSON).
  ///   2: force `readerFontId = 'serif'` once. Earlier builds shipped
  ///      with the user accidentally landing on Sans/Geist; the default
  ///      for new installs has always been serif, but stored prefs from
  ///      those sessions kept the wrong value.
  ///   3: add per-source reader appearance overrides and reader side margin.
  ///   4: reset global reader text scale to 100%. Android readability is now
  ///      handled by device-scale in the reader, not persisted user percent.
  ///   5: add readerBrightnessOverride for temporary reader brightness.
  ///   6: add readerTextAlignment for left/justified book text.
  static const _currentSchemaVersion = 6;

  final PreferencesStorage _storage;

  Future<Preferences> load(List<String> supportedCodes) async {
    final json = await _storage.getString(_key);
    if (json == null) {
      return Preferences(locale: _resolveInitialLocale(supportedCodes));
    }
    try {
      final map = jsonDecode(json) as Map<String, Object?>;
      final storedVersion = (map['_schemaVersion'] as int?) ?? 1;
      final fontIdRaw = map['readerFontId'] as String?;
      // Migration v1 → v2: reset readerFontId to default. After load
      // returns, the service's first save() persists `_schemaVersion: 2`
      // so this only runs once per device.
      final fontId = storedVersion < 2 ? 'serif' : (fontIdRaw ?? 'serif');
      final readerTextScale = storedVersion < 4
          ? 1.0
          : (map['readerTextScale'] as num?)?.toDouble() ?? 1.0;
      return Preferences(
        themeMode: ThemeMode.values.byName(
          map['themeMode'] as String? ?? 'system',
        ),
        locale: _resolveLocale(map['locale'] as String?, supportedCodes),
        catalogLayoutMode: map['catalogLayoutMode'] as String? ?? 'grid',
        readerThemeId: map['readerThemeId'] as String? ?? 'paper',
        readerFontId: fontId,
        readerLayoutId: map['readerLayoutId'] as String? ?? 'standard',
        readerTextScale: readerTextScale,
        readerLineHeight: (map['readerLineHeight'] as num?)?.toDouble() ?? 1.55,
        readerSideMargin: (map['readerSideMargin'] as num?)?.toDouble() ?? 6.0,
        readerTextAlignment: _readReaderTextAlignment(
          map['readerTextAlignment'],
        ),
        readerInvertImagesInDark:
            map['readerInvertImagesInDark'] as bool? ?? false,
        readerOverrideFont: map['readerOverrideFont'] as bool? ?? true,
        readerOverrideColor: map['readerOverrideColor'] as bool? ?? true,
        readerUseBookLayout: map['readerUseBookLayout'] as bool? ?? true,
        readerBrightnessOverride: _readReaderBrightness(
          map['readerBrightnessOverride'],
        ),
        readerSearchHistory: _readStringList(map['readerSearchHistory']),
        readerAppearanceOverrides: _readReaderAppearanceOverrides(
          map['readerAppearanceOverrides'],
        ),
        onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
        hasCompletedSetup: map['hasCompletedSetup'] as bool? ?? false,
      );
    } catch (e, st) {
      // Corrupt JSON on disk: log and fall back to defaults so the app can
      // still launch. The next successful save() will overwrite the bad blob.
      developer.log(
        'Failed to decode preferences — falling back to defaults',
        error: e,
        stackTrace: st,
        name: 'PreferencesRepository',
      );
      return const Preferences();
    }
  }

  Future<void> save(Preferences prefs) async {
    final map = <String, Object?>{
      '_schemaVersion': _currentSchemaVersion,
      'themeMode': prefs.themeMode.name,
      'locale': prefs.locale.languageCode,
      'catalogLayoutMode': prefs.catalogLayoutMode,
      'readerThemeId': prefs.readerThemeId,
      'readerFontId': prefs.readerFontId,
      'readerLayoutId': prefs.readerLayoutId,
      'readerTextScale': prefs.readerTextScale,
      'readerLineHeight': prefs.readerLineHeight,
      'readerSideMargin': prefs.readerSideMargin,
      'readerTextAlignment': prefs.readerTextAlignment.id,
      'readerInvertImagesInDark': prefs.readerInvertImagesInDark,
      'readerOverrideFont': prefs.readerOverrideFont,
      'readerOverrideColor': prefs.readerOverrideColor,
      'readerUseBookLayout': prefs.readerUseBookLayout,
      'readerBrightnessOverride': prefs.readerBrightnessOverride,
      'readerSearchHistory': prefs.readerSearchHistory,
      'readerAppearanceOverrides': _writeReaderAppearanceOverrides(
        prefs.readerAppearanceOverrides,
      ),
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

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static double? _readReaderBrightness(Object? value) {
    if (value is! num) return null;
    return value.toDouble().clamp(0.05, 1.0).toDouble();
  }

  static ReaderTextAlignment _readReaderTextAlignment(Object? value) {
    if (value is! String) return ReaderTextAlignment.start;
    return ReaderTextAlignment.fromId(value);
  }

  static Map<String, ReaderAppearanceOverride> _readReaderAppearanceOverrides(
    Object? value,
  ) {
    if (value is! Map) return const {};

    final overrides = <String, ReaderAppearanceOverride>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final rawOverride = entry.value;
      if (key is! String || key.isEmpty || rawOverride is! Map) continue;

      final override = ReaderAppearanceOverride.fromJson(
        Map<String, Object?>.from(rawOverride),
      );
      if (!override.isEmpty) overrides[key] = override;
    }

    if (overrides.isEmpty) return const {};
    return Map.unmodifiable(overrides);
  }

  static Map<String, Object?> _writeReaderAppearanceOverrides(
    Map<String, ReaderAppearanceOverride> overrides,
  ) {
    if (overrides.isEmpty) return const {};

    return <String, Object?>{
      for (final entry in overrides.entries)
        if (entry.key.isNotEmpty && !entry.value.isEmpty)
          entry.key: entry.value.toJson(),
    };
  }
}
