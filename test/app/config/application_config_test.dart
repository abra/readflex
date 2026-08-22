import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/config/environment.dart';

void main() {
  group('Environment.from', () {
    test('normalizes supported values', () {
      expect(Environment.from('development'), Environment.dev);
      expect(Environment.from('STAGING'), Environment.staging);
      expect(Environment.from('production'), Environment.prod);
    });

    test('rejects an invalid explicit value', () {
      expect(() => Environment.from('PRODUCTIONN'), throwsArgumentError);
    });
  });

  group('ApplicationConfig.validateBackendConfiguration', () {
    test('accepts the production API endpoint', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.prod,
          endpoints: const {
            'API_BASE_URL': ApplicationConfig.productionApiBaseUrl,
          },
        ),
        returnsNormally,
      );
    });

    test('accepts HTTP loopback in development', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.dev,
          endpoints: const {'API_BASE_URL': 'http://127.0.0.1:9090'},
        ),
        returnsNormally,
      );
    });

    test('rejects an empty staging endpoint', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.staging,
          endpoints: const {'API_BASE_URL': ''},
        ),
        throwsA(isA<ApplicationConfigurationException>()),
      );
    });

    test('rejects HTTP outside development', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.prod,
          endpoints: const {'API_BASE_URL': 'http://api.readflex.app'},
        ),
        throwsA(
          isA<ApplicationConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });

    test('rejects loopback outside development', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.prod,
          endpoints: const {'API_BASE_URL': 'https://localhost:9090'},
        ),
        throwsA(
          isA<ApplicationConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('loopback'),
          ),
        ),
      );
    });

    test('rejects credentials in a backend URL', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.prod,
          endpoints: const {
            'API_BASE_URL': 'https://user:password@api.readflex.app',
          },
        ),
        throwsA(isA<ApplicationConfigurationException>()),
      );
    });

    test('validates every configured backend', () {
      expect(
        () => ApplicationConfig.validateBackendConfiguration(
          environment: Environment.prod,
          endpoints: const {
            'ARTICLE_CLEANER_BASE_URL': 'https://api.readflex.app',
            'CONTEXTUAL_TRANSLATION_BASE_URL': 'https://translate.readflex.app',
            'DICTIONARY_BASE_URL': 'http://dictionary.readflex.app',
          },
        ),
        throwsA(
          isA<ApplicationConfigurationException>().having(
            (error) => error.message,
            'message',
            startsWith('DICTIONARY_BASE_URL'),
          ),
        ),
      );
    });
  });

  group('ApplicationConfig.validateEmbeddedCredential', () {
    test('accepts a local development credential', () {
      expect(
        () => ApplicationConfig.validateEmbeddedCredential(
          environment: Environment.dev,
          credential: 'local-secret',
        ),
        returnsNormally,
      );
    });

    test('accepts an empty production credential', () {
      expect(
        () => ApplicationConfig.validateEmbeddedCredential(
          environment: Environment.prod,
          credential: '',
        ),
        returnsNormally,
      );
    });

    test('rejects a static credential in production', () {
      expect(
        () => ApplicationConfig.validateEmbeddedCredential(
          environment: Environment.prod,
          credential: 'must-not-ship',
        ),
        throwsA(
          isA<ApplicationConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('development-only'),
          ),
        ),
      );
    });
  });
}
