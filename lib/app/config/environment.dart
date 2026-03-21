// Application environment enum: dev, staging, prod.
//
// Eliminates raw string comparisons ("DEV", "PROD") across the codebase.
// Falls back to prod in release mode and dev in debug mode when no
// explicit ENVIRONMENT flag is passed at build time.

import 'package:flutter/foundation.dart' show kReleaseMode;

/// The environment.
enum Environment {
  /// Development environment.
  dev._('DEV'),

  /// Staging environment.
  staging._('STAGING'),

  /// Production environment.
  prod._('PROD')
  ;

  /// The environment value.
  final String value;

  const Environment._(this.value);

  /// Returns the environment from the given [value].
  static Environment from(String? value) => switch (value) {
    'DEV' => Environment.dev,
    'STAGING' => Environment.staging,
    'PROD' => Environment.prod,
    _ => kReleaseMode ? Environment.prod : Environment.dev,
  };
}
