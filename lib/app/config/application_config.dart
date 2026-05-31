// Compile-time configuration read from --dart-define flags.
//
// Centralizes all String.fromEnvironment() calls so that missing flags
// are caught in one place rather than scattered across the codebase.
// TestConfig uses noSuchMethod to fail loudly when a test accesses
// a config value it did not provide.

import 'package:readflex/app/config/environment.dart';

/// Application configuration
class ApplicationConfig {
  /// Creates a new [ApplicationConfig] instance.
  const ApplicationConfig();

  /// The current environment.
  Environment get environment {
    var env = const String.fromEnvironment('ENVIRONMENT').trim();

    if (env.isNotEmpty) {
      return Environment.from(env);
    }

    env = const String.fromEnvironment('FLUTTER_APP_FLAVOR').trim();

    return Environment.from(env);
  }

  /// The Sentry DSN.
  String get sentryDsn => const String.fromEnvironment('SENTRY_DSN').trim();

  /// Whether Sentry is enabled.
  bool get enableSentry => sentryDsn.isNotEmpty;

  /// Whether the app is running in development environment.
  bool get isDev => environment == Environment.dev;

  /// Supported locale codes for the app.
  List<String> get supportedLocaleCodes => const ['en', 'ru'];

  /// Base URL of the article extraction backend.
  ///
  /// Explicit dart-define values always win. The checked-in default stays on
  /// localhost; device/release builds should pass a private value with
  /// `--dart-define=ARTICLE_CLEANER_BASE_URL=...`.
  String get articleCleanerBaseUrl {
    const configured = String.fromEnvironment('ARTICLE_CLEANER_BASE_URL');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return 'http://127.0.0.1:9090';
  }

  /// Optional API key for the article extraction backend.
  String get articleCleanerApiKey =>
      const String.fromEnvironment('ARTICLE_CLEANER_API_KEY').trim();

  /// Temporary direct DeepSeek key for translation enrichment.
  ///
  /// This is intentionally for local/internal builds only. Production should
  /// send enrichment requests to a Readflex backend and keep provider keys
  /// server-side.
  String get deepSeekApiKey =>
      const String.fromEnvironment('DEEPSEEK_API_KEY').trim();

  /// Base URL for the DeepSeek-compatible chat completions endpoint.
  String get deepSeekBaseUrl {
    const configured = String.fromEnvironment('DEEPSEEK_BASE_URL');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return 'https://api.deepseek.com';
  }

  /// DeepSeek model used by the temporary direct translation client.
  String get deepSeekModel {
    const configured = String.fromEnvironment('DEEPSEEK_MODEL');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return 'deepseek-v4-pro';
  }

  /// Whether the app should wire the temporary direct DeepSeek client.
  bool get enableDirectDeepSeekTranslation => deepSeekApiKey.isNotEmpty;
}

/// A special version of [ApplicationConfig] that is used in tests.
///
/// In order to use [ApplicationConfig] in tests, it is needed to
/// extend this class and provide the dependencies that are needed for the test.
base class TestConfig implements ApplicationConfig {
  const TestConfig();

  @override
  Object noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'The test tries to access ${invocation.memberName} (${invocation.runtimeType}) config option, but '
      'it was not provided. Please provide the option in the test. '
      'You can do it by extending this class and providing the option.',
    );
  }
}
