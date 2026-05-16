import 'package:flutter/material.dart';

/// Non-null view over [TextTheme] for styles that the app guarantees are
/// always defined by `AppTypography.textTheme`.
///
/// Flutter's [TextTheme] fields are nullable because a user can override any
/// slot with null. This app always ships the full set of styles, so call
/// sites that use `context.text.bodyMedium` should never need the `!`
/// operator. [AppTextTheme] encodes that contract by exposing every role
/// as a non-null [TextStyle].
///
/// Constructed once per theme build in `build_context_ext.dart` and cached
/// inside the [TextTheme] instance via an [Expando]-free pattern: a zero-cost
/// wrapper whose fields are resolved lazily from the underlying [TextTheme].
class AppTextTheme {
  const AppTextTheme(this._source);

  final TextTheme _source;

  TextStyle get displayLarge => _source.displayLarge!;

  TextStyle get displayMedium => _source.displayMedium!;

  TextStyle get displaySmall => _source.displaySmall!;

  TextStyle get headlineLarge => _source.headlineLarge!;

  TextStyle get headlineMedium => _source.headlineMedium!;

  TextStyle get headlineSmall => _source.headlineSmall!;

  TextStyle get titleLarge => _source.titleLarge!;

  TextStyle get titleMedium => _source.titleMedium!;

  TextStyle get titleSmall => _source.titleSmall!;

  TextStyle get bodyLarge => _source.bodyLarge!;

  TextStyle get bodyMedium => _source.bodyMedium!;

  TextStyle get bodySmall => _source.bodySmall!;

  TextStyle get labelLarge => _source.labelLarge!;

  TextStyle get labelMedium => _source.labelMedium!;

  TextStyle get labelSmall => _source.labelSmall!;

  /// Compact count in screen headers, e.g. "12 items" next to Library.
  TextStyle get screenCounter => labelSmall.copyWith(
    fontWeight: FontWeight.w400,
  );

  /// Main title in dense source rows.
  TextStyle get sourceListTitle => titleSmall.copyWith(
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  /// Secondary metadata in source rows, e.g. author, format, progress.
  TextStyle get sourceMetadata => labelSmall.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  /// Tiny cover-corner badge text constrained by cover artwork geometry.
  TextStyle get sourceCoverBadge => labelSmall.copyWith(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Reader chrome metadata, e.g. chapter title and page progress.
  TextStyle get readerChromeLabel => bodySmall;

  /// Reader chrome numbers should not jitter as digits change.
  TextStyle get readerChromeNumber => readerChromeLabel.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Uppercase micro-label used above detail sections.
  TextStyle get kicker => labelSmall.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// Text glyph used as an icon inside status discs.
  TextStyle get statusGlyph => titleLarge.copyWith(
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  /// Label for reader appearance A-/A+ controls.
  TextStyle readerTextSizeControl({required bool large}) =>
      (large ? titleMedium : labelLarge).copyWith(
        fontSize: large ? 18 : 14,
      );
}
