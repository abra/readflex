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
  prod._('PROD');

  /// The environment value.
  final String value;

  const Environment._(this.value);

  /// Returns the environment from [value]. Missing values use the build-mode
  /// default; invalid explicit values fail instead of silently selecting a
  /// different backend.
  static Environment from(String? value) {
    final normalized = value?.trim().toUpperCase();
    return switch (normalized) {
      'DEV' || 'DEVELOPMENT' => Environment.dev,
      'STAGING' => Environment.staging,
      'PROD' || 'PRODUCTION' => Environment.prod,
      null || '' => kReleaseMode ? Environment.prod : Environment.dev,
      _ => throw ArgumentError.value(value, 'value', 'Unknown environment'),
    };
  }
}
