// Compile-time configuration read from --dart-define flags.
//
// Centralizes all String.fromEnvironment() calls so that missing flags
// are caught in one place rather than scattered across the codebase.
// TestConfig uses noSuchMethod to fail loudly when a test accesses
// a config value it did not provide.

import 'package:readflex/app/config/environment.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Application configuration
class ApplicationConfig {
  /// Creates a new [ApplicationConfig] instance.
  const ApplicationConfig();

  /// Public production API endpoint. This is routing configuration, not a
  /// secret, so keeping it in source prevents release builds from silently
  /// falling back to localhost.
  static const productionApiBaseUrl = 'https://api.readflex.app';

  /// The current environment.
  Environment get environment {
    var env = const String.fromEnvironment('ENVIRONMENT').trim();

    if (env.isNotEmpty) {
      return Environment.from(env);
    }

    env = const String.fromEnvironment('FLUTTER_APP_FLAVOR').trim();

    return Environment.from(env);
  }

  /// GlitchTip DSN for Sentry-compatible error reporting.
  ///
  /// `SENTRY_DSN` is accepted as a fallback because GlitchTip's Flutter docs
  /// use the standard Sentry SDK environment name.
  String get glitchTipDsn {
    const configured = String.fromEnvironment('GLITCHTIP_DSN');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return const String.fromEnvironment('SENTRY_DSN').trim();
  }

  /// Traces sample rate for GlitchTip performance events.
  ///
  /// Defaults to `0` so production builds send crash/error events only unless
  /// performance monitoring is explicitly enabled.
  double get glitchTipTracesSampleRate {
    const configured = String.fromEnvironment('GLITCHTIP_TRACES_SAMPLE_RATE');
    final value = configured.trim();
    if (value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
  }

  /// Whether GlitchTip error reporting is enabled.
  bool get enableGlitchTip => glitchTipDsn.isNotEmpty;

  /// Whether the app is running in development environment.
  bool get isDev => environment == Environment.dev;

  /// Supported locale codes for the app.
  List<String> get supportedLocaleCodes => ReadflexSupportedLocales.codes;

  /// Base URL of the article extraction backend.
  ///
  /// Explicit dart-define values always win. Development uses localhost,
  /// production uses the checked-in public API endpoint, and staging requires
  /// an explicit endpoint so it cannot accidentally send traffic to prod.
  String get articleCleanerBaseUrl {
    const configured = String.fromEnvironment('ARTICLE_CLEANER_BASE_URL');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return switch (environment) {
      Environment.dev => 'http://127.0.0.1:9090',
      Environment.staging => '',
      Environment.prod => productionApiBaseUrl,
    };
  }

  /// Development-only credential for Readflex backend requests.
  ///
  /// A static credential cannot be kept secret in an APK or IPA, so
  /// [validate] rejects it outside development. `ARTICLE_CLEANER_API_KEY` is
  /// accepted temporarily for compatibility with existing local commands.
  String get developmentApiKey {
    const configured = String.fromEnvironment('READFLEX_API_KEY');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return const String.fromEnvironment('ARTICLE_CLEANER_API_KEY').trim();
  }

  /// Base URL of the contextual translation backend.
  ///
  /// Defaults to [articleCleanerBaseUrl] because the current backend entrypoint
  /// is the same API host.
  String get contextualTranslationBaseUrl {
    const configured = String.fromEnvironment(
      'CONTEXTUAL_TRANSLATION_BASE_URL',
    );
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return articleCleanerBaseUrl;
  }

  /// Base URL of the monolingual dictionary backend.
  ///
  /// The default uses the shared Readflex API entrypoint. A separate URL is
  /// only needed when dictionary traffic is deployed to another host.
  String get dictionaryBaseUrl {
    const configured = String.fromEnvironment('DICTIONARY_BASE_URL');
    final value = configured.trim();
    if (value.isNotEmpty) return value;
    return articleCleanerBaseUrl;
  }

  /// Validates configuration before any repositories or HTTP clients are
  /// created. Throws [ApplicationConfigurationException] on invalid values.
  void validate() {
    validateBackendConfiguration(
      environment: environment,
      endpoints: {
        'ARTICLE_CLEANER_BASE_URL': articleCleanerBaseUrl,
        'CONTEXTUAL_TRANSLATION_BASE_URL': contextualTranslationBaseUrl,
        'DICTIONARY_BASE_URL': dictionaryBaseUrl,
      },
    );
    validateEmbeddedCredential(
      environment: environment,
      credential: developmentApiKey,
    );
  }

  /// Pure validation entrypoint used by [validate] and unit tests.
  static void validateBackendConfiguration({
    required Environment environment,
    required Map<String, String> endpoints,
  }) {
    for (final entry in endpoints.entries) {
      final value = entry.value.trim();
      final uri = Uri.tryParse(value);
      if (value.isEmpty ||
          uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty) {
        throw ApplicationConfigurationException(
          '${entry.key} must be an absolute backend URL.',
        );
      }
      if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
        throw ApplicationConfigurationException(
          '${entry.key} must not contain credentials, a query, or a fragment.',
        );
      }
      if (environment != Environment.dev) {
        if (uri.scheme != 'https') {
          throw ApplicationConfigurationException(
            '${entry.key} must use HTTPS outside development.',
          );
        }
        if (_isLoopbackHost(uri.host)) {
          throw ApplicationConfigurationException(
            '${entry.key} must not use a loopback host outside development.',
          );
        }
      } else if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw ApplicationConfigurationException(
          '${entry.key} must use HTTP or HTTPS.',
        );
      }
    }
  }

  /// Prevents shipping a build-time API credential in an installable app.
  static void validateEmbeddedCredential({
    required Environment environment,
    required String credential,
  }) {
    if (environment != Environment.dev && credential.trim().isNotEmpty) {
      throw const ApplicationConfigurationException(
        'READFLEX_API_KEY is development-only. Production authentication '
        'must use short-lived server-issued credentials.',
      );
    }
  }
}

/// Indicates an invalid compile-time application configuration.
final class ApplicationConfigurationException implements Exception {
  const ApplicationConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'ApplicationConfigurationException: $message';
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '::1' ||
      normalized == '0:0:0:0:0:0:0:1' ||
      normalized.startsWith('127.');
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
