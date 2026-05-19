import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart' show ThemeMode;

const _unset = Object();

enum ReaderTextAlignment {
  start('start'),
  end('end'),
  justify('justify')
  ;

  const ReaderTextAlignment(this.id);

  final String id;

  static ReaderTextAlignment fromId(String? value) => switch (value) {
    'end' => end,
    'justify' => justify,
    _ => start,
  };

  static ReaderTextAlignment? tryFromId(String? value) => switch (value) {
    'start' => start,
    'end' => end,
    'justify' => justify,
    _ => null,
  };
}

/// Reader-scoped appearance slice of [Preferences] (theme / font / layout
/// IDs plus per-trait toggles). Exposed separately so widgets that only
/// care about reader look can subscribe via
/// [PreferencesScope.readerAppearanceOf] and skip rebuilds when unrelated
/// preferences change.
class ReaderAppearancePreferences {
  const ReaderAppearancePreferences({
    required this.themeId,
    required this.fontId,
    required this.layoutId,
    required this.textScale,
    required this.lineHeight,
    required this.sideMargin,
    required this.textAlignment,
    required this.invertImagesInDark,
    required this.overrideFont,
    required this.overrideColor,
    required this.useBookLayout,
  });

  static const defaults = ReaderAppearancePreferences(
    themeId: 'paper',
    fontId: 'serif',
    layoutId: 'standard',
    textScale: 1.0,
    lineHeight: 1.55,
    sideMargin: 6.0,
    textAlignment: ReaderTextAlignment.start,
    invertImagesInDark: false,
    overrideFont: true,
    overrideColor: true,
    useBookLayout: true,
  );

  final String themeId;
  final String fontId;
  final String layoutId;
  final double textScale;
  final double lineHeight;
  final double sideMargin;
  final ReaderTextAlignment textAlignment;
  final bool invertImagesInDark;

  /// When `false`, publisher font-family / font-weight win over reader prefs.
  final bool overrideFont;

  /// When `false`, publisher text color wins over reader prefs.
  final bool overrideColor;

  /// When `false`, publisher line-height / indent / hyphenation / margins win.
  final bool useBookLayout;

  ReaderAppearancePreferences copyWith({
    String? themeId,
    String? fontId,
    String? layoutId,
    double? textScale,
    double? lineHeight,
    double? sideMargin,
    ReaderTextAlignment? textAlignment,
    bool? invertImagesInDark,
    bool? overrideFont,
    bool? overrideColor,
    bool? useBookLayout,
  }) => ReaderAppearancePreferences(
    themeId: themeId ?? this.themeId,
    fontId: fontId ?? this.fontId,
    layoutId: layoutId ?? this.layoutId,
    textScale: textScale ?? this.textScale,
    lineHeight: lineHeight ?? this.lineHeight,
    sideMargin: sideMargin ?? this.sideMargin,
    textAlignment: textAlignment ?? this.textAlignment,
    invertImagesInDark: invertImagesInDark ?? this.invertImagesInDark,
    overrideFont: overrideFont ?? this.overrideFont,
    overrideColor: overrideColor ?? this.overrideColor,
    useBookLayout: useBookLayout ?? this.useBookLayout,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderAppearancePreferences &&
          themeId == other.themeId &&
          fontId == other.fontId &&
          layoutId == other.layoutId &&
          textScale == other.textScale &&
          lineHeight == other.lineHeight &&
          sideMargin == other.sideMargin &&
          textAlignment == other.textAlignment &&
          invertImagesInDark == other.invertImagesInDark &&
          overrideFont == other.overrideFont &&
          overrideColor == other.overrideColor &&
          useBookLayout == other.useBookLayout;

  @override
  int get hashCode => Object.hash(
    themeId,
    fontId,
    layoutId,
    textScale,
    lineHeight,
    sideMargin,
    textAlignment,
    invertImagesInDark,
    overrideFont,
    overrideColor,
    useBookLayout,
  );
}

/// Optional per-source reader appearance overrides.
///
/// `null` means "inherit the global reader preference". This keeps Profile as
/// the global default while allowing an individual book/comic to override only
/// the fields the user changed from the in-reader `T` controls.
class ReaderAppearanceOverride {
  const ReaderAppearanceOverride({
    this.themeId,
    this.fontId,
    this.layoutId,
    this.textScale,
    this.lineHeight,
    this.sideMargin,
    this.textAlignment,
    this.invertImagesInDark,
    this.overrideFont,
    this.overrideColor,
    this.useBookLayout,
    this.brightnessOverride,
  });

  final String? themeId;
  final String? fontId;
  final String? layoutId;
  final double? textScale;
  final double? lineHeight;
  final double? sideMargin;
  final ReaderTextAlignment? textAlignment;
  final bool? invertImagesInDark;
  final bool? overrideFont;
  final bool? overrideColor;
  final bool? useBookLayout;
  final double? brightnessOverride;

  bool get isEmpty =>
      themeId == null &&
      fontId == null &&
      layoutId == null &&
      textScale == null &&
      lineHeight == null &&
      sideMargin == null &&
      textAlignment == null &&
      invertImagesInDark == null &&
      overrideFont == null &&
      overrideColor == null &&
      useBookLayout == null &&
      brightnessOverride == null;

  ReaderAppearancePreferences applyTo(ReaderAppearancePreferences base) =>
      base.copyWith(
        themeId: themeId,
        fontId: fontId,
        layoutId: layoutId,
        textScale: textScale,
        lineHeight: lineHeight,
        sideMargin: sideMargin,
        textAlignment: textAlignment,
        invertImagesInDark: invertImagesInDark,
        overrideFont: overrideFont,
        overrideColor: overrideColor,
        useBookLayout: useBookLayout,
      );

  ReaderAppearanceOverride copyWith({
    Object? themeId = _unset,
    Object? fontId = _unset,
    Object? layoutId = _unset,
    Object? textScale = _unset,
    Object? lineHeight = _unset,
    Object? sideMargin = _unset,
    Object? textAlignment = _unset,
    Object? invertImagesInDark = _unset,
    Object? overrideFont = _unset,
    Object? overrideColor = _unset,
    Object? useBookLayout = _unset,
    Object? brightnessOverride = _unset,
  }) => ReaderAppearanceOverride(
    themeId: identical(themeId, _unset) ? this.themeId : themeId as String?,
    fontId: identical(fontId, _unset) ? this.fontId : fontId as String?,
    layoutId: identical(layoutId, _unset) ? this.layoutId : layoutId as String?,
    textScale: _copyOptionalDouble(textScale, this.textScale),
    lineHeight: _copyOptionalDouble(lineHeight, this.lineHeight),
    sideMargin: _copyOptionalDouble(sideMargin, this.sideMargin),
    textAlignment: identical(textAlignment, _unset)
        ? this.textAlignment
        : textAlignment as ReaderTextAlignment?,
    invertImagesInDark: identical(invertImagesInDark, _unset)
        ? this.invertImagesInDark
        : invertImagesInDark as bool?,
    overrideFont: identical(overrideFont, _unset)
        ? this.overrideFont
        : overrideFont as bool?,
    overrideColor: identical(overrideColor, _unset)
        ? this.overrideColor
        : overrideColor as bool?,
    useBookLayout: identical(useBookLayout, _unset)
        ? this.useBookLayout
        : useBookLayout as bool?,
    brightnessOverride: _copyOptionalDouble(
      brightnessOverride,
      this.brightnessOverride,
    ),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (themeId != null) 'themeId': themeId,
    if (fontId != null) 'fontId': fontId,
    if (layoutId != null) 'layoutId': layoutId,
    if (textScale != null) 'textScale': textScale,
    if (lineHeight != null) 'lineHeight': lineHeight,
    if (sideMargin != null) 'sideMargin': sideMargin,
    if (textAlignment != null) 'textAlignment': textAlignment!.id,
    if (invertImagesInDark != null) 'invertImagesInDark': invertImagesInDark,
    if (overrideFont != null) 'overrideFont': overrideFont,
    if (overrideColor != null) 'overrideColor': overrideColor,
    if (useBookLayout != null) 'useBookLayout': useBookLayout,
    if (brightnessOverride != null) 'brightnessOverride': brightnessOverride,
  };

  factory ReaderAppearanceOverride.fromJson(Map<String, Object?> json) {
    return ReaderAppearanceOverride(
      themeId: _readString(json['themeId']),
      fontId: _readString(json['fontId']),
      layoutId: _readString(json['layoutId']),
      textScale: _readDouble(json['textScale']),
      lineHeight: _readDouble(json['lineHeight']),
      sideMargin: _readDouble(json['sideMargin']),
      textAlignment: _readTextAlignment(json['textAlignment']),
      invertImagesInDark: _readBool(json['invertImagesInDark']),
      overrideFont: _readBool(json['overrideFont']),
      overrideColor: _readBool(json['overrideColor']),
      useBookLayout: _readBool(json['useBookLayout']),
      brightnessOverride: _readBrightness(json['brightnessOverride']),
    );
  }

  static String? _readString(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  static double? _readDouble(Object? value) {
    if (value is! num) return null;
    return value.toDouble();
  }

  static bool? _readBool(Object? value) => value is bool ? value : null;

  static double? _readBrightness(Object? value) {
    if (value is! num) return null;
    return value.toDouble().clamp(0.05, 1.0).toDouble();
  }

  static ReaderTextAlignment? _readTextAlignment(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return ReaderTextAlignment.tryFromId(value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderAppearanceOverride &&
          themeId == other.themeId &&
          fontId == other.fontId &&
          layoutId == other.layoutId &&
          textScale == other.textScale &&
          lineHeight == other.lineHeight &&
          sideMargin == other.sideMargin &&
          textAlignment == other.textAlignment &&
          invertImagesInDark == other.invertImagesInDark &&
          overrideFont == other.overrideFont &&
          overrideColor == other.overrideColor &&
          useBookLayout == other.useBookLayout &&
          brightnessOverride == other.brightnessOverride;

  @override
  int get hashCode => Object.hash(
    themeId,
    fontId,
    layoutId,
    textScale,
    lineHeight,
    sideMargin,
    textAlignment,
    invertImagesInDark,
    overrideFont,
    overrideColor,
    useBookLayout,
    brightnessOverride,
  );
}

/// Immutable snapshot of every user-configurable preference in the app —
/// app theme, locale, catalog layout, reader appearance, and onboarding
/// flags. Loaded at startup, mutated via [PreferencesService.update], and
/// surfaced to widgets through [PreferencesScope].
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.catalogLayoutMode = 'grid',
    this.readerThemeId = 'paper',
    this.readerFontId = 'serif',
    this.readerLayoutId = 'standard',
    this.readerTextScale = 1.0,
    this.readerLineHeight = 1.55,
    this.readerSideMargin = 6.0,
    this.readerTextAlignment = ReaderTextAlignment.start,
    this.readerInvertImagesInDark = false,
    this.readerOverrideFont = true,
    this.readerOverrideColor = true,
    this.readerUseBookLayout = true,
    this.readerSearchHistory = const [],
    this.readerAppearanceOverrides = const {},
    this.onboardingCompleted = false,
    this.hasCompletedSetup = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final String catalogLayoutMode;
  final String readerThemeId;
  final String readerFontId;
  final String readerLayoutId;
  final double readerTextScale;
  final double readerLineHeight;
  final double readerSideMargin;
  final ReaderTextAlignment readerTextAlignment;
  final bool readerInvertImagesInDark;
  final bool readerOverrideFont;
  final bool readerOverrideColor;
  final bool readerUseBookLayout;
  final List<String> readerSearchHistory;
  final Map<String, ReaderAppearanceOverride> readerAppearanceOverrides;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingCompleted;

  /// Whether the user has completed the initial setup (added first content).
  final bool hasCompletedSetup;

  ReaderAppearancePreferences get readerAppearance =>
      ReaderAppearancePreferences(
        themeId: readerThemeId,
        fontId: readerFontId,
        layoutId: readerLayoutId,
        textScale: readerTextScale,
        lineHeight: readerLineHeight,
        sideMargin: readerSideMargin,
        textAlignment: readerTextAlignment,
        invertImagesInDark: readerInvertImagesInDark,
        overrideFont: readerOverrideFont,
        overrideColor: readerOverrideColor,
        useBookLayout: readerUseBookLayout,
      );

  ReaderAppearanceOverride? readerAppearanceOverrideFor(String sourceId) {
    final override = readerAppearanceOverrides[sourceId];
    if (override == null || override.isEmpty) return null;
    return override;
  }

  ReaderAppearancePreferences effectiveReaderAppearanceFor(String sourceId) {
    final override = readerAppearanceOverrideFor(sourceId);
    return override?.applyTo(readerAppearance) ?? readerAppearance;
  }

  double? readerBrightnessOverrideFor(String sourceId) {
    return readerAppearanceOverrideFor(sourceId)?.brightnessOverride;
  }

  Preferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? catalogLayoutMode,
    String? readerThemeId,
    String? readerFontId,
    String? readerLayoutId,
    double? readerTextScale,
    double? readerLineHeight,
    double? readerSideMargin,
    ReaderTextAlignment? readerTextAlignment,
    bool? readerInvertImagesInDark,
    bool? readerOverrideFont,
    bool? readerOverrideColor,
    bool? readerUseBookLayout,
    List<String>? readerSearchHistory,
    Map<String, ReaderAppearanceOverride>? readerAppearanceOverrides,
    bool? onboardingCompleted,
    bool? hasCompletedSetup,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    catalogLayoutMode: catalogLayoutMode ?? this.catalogLayoutMode,
    readerThemeId: readerThemeId ?? this.readerThemeId,
    readerFontId: readerFontId ?? this.readerFontId,
    readerLayoutId: readerLayoutId ?? this.readerLayoutId,
    readerTextScale: readerTextScale ?? this.readerTextScale,
    readerLineHeight: readerLineHeight ?? this.readerLineHeight,
    readerSideMargin: readerSideMargin ?? this.readerSideMargin,
    readerTextAlignment: readerTextAlignment ?? this.readerTextAlignment,
    readerInvertImagesInDark:
        readerInvertImagesInDark ?? this.readerInvertImagesInDark,
    readerOverrideFont: readerOverrideFont ?? this.readerOverrideFont,
    readerOverrideColor: readerOverrideColor ?? this.readerOverrideColor,
    readerUseBookLayout: readerUseBookLayout ?? this.readerUseBookLayout,
    readerSearchHistory: readerSearchHistory ?? this.readerSearchHistory,
    readerAppearanceOverrides:
        readerAppearanceOverrides ?? this.readerAppearanceOverrides,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preferences &&
          themeMode == other.themeMode &&
          locale == other.locale &&
          catalogLayoutMode == other.catalogLayoutMode &&
          readerThemeId == other.readerThemeId &&
          readerFontId == other.readerFontId &&
          readerLayoutId == other.readerLayoutId &&
          readerTextScale == other.readerTextScale &&
          readerLineHeight == other.readerLineHeight &&
          readerSideMargin == other.readerSideMargin &&
          readerTextAlignment == other.readerTextAlignment &&
          readerInvertImagesInDark == other.readerInvertImagesInDark &&
          readerOverrideFont == other.readerOverrideFont &&
          readerOverrideColor == other.readerOverrideColor &&
          readerUseBookLayout == other.readerUseBookLayout &&
          listEquals(readerSearchHistory, other.readerSearchHistory) &&
          mapEquals(
            readerAppearanceOverrides,
            other.readerAppearanceOverrides,
          ) &&
          onboardingCompleted == other.onboardingCompleted &&
          hasCompletedSetup == other.hasCompletedSetup;

  @override
  int get hashCode => Object.hashAll([
    themeMode,
    locale,
    catalogLayoutMode,
    readerThemeId,
    readerFontId,
    readerLayoutId,
    readerTextScale,
    readerLineHeight,
    readerSideMargin,
    readerTextAlignment,
    readerInvertImagesInDark,
    readerOverrideFont,
    readerOverrideColor,
    readerUseBookLayout,
    Object.hashAll(readerSearchHistory),
    _hashReaderAppearanceOverrides(readerAppearanceOverrides),
    onboardingCompleted,
    hasCompletedSetup,
  ]);
}

int _hashReaderAppearanceOverrides(
  Map<String, ReaderAppearanceOverride> overrides,
) {
  final entries = overrides.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return Object.hashAll(entries.map((e) => Object.hash(e.key, e.value)));
}

double? _copyOptionalDouble(Object? value, double? current) {
  if (identical(value, _unset)) return current;
  if (value == null) return null;
  return (value as num).toDouble();
}
