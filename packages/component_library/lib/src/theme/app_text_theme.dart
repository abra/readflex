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
}
