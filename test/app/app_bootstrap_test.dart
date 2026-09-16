import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/app_bootstrap.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/config/environment.dart';
import 'package:readflex/app/resource_disposer.dart';

import '../support/app_fakes.dart';

void main() {
  for (final dsn in ['', 'https://public@example.test/1']) {
    test(
      'invalid environment reaches recovery before monitoring (dsn=$dsn)',
      () async {
        final errors = <Object>[];
        final bootstrap = AppBootstrap(
          config: _Config(dsn: dsn, invalidEnvironment: true),
          logger: Logger(),
          reporterFactory: (_) async =>
              throw TestFailure('Monitoring must not start'),
          dependenciesFactory:
              ({
                required config,
                required logger,
                required errorReporter,
              }) async => throw TestFailure('Dependencies must not be created'),
        );

        await bootstrap.run(
          onReady: (_) => fail('Invalid configuration must not launch the app'),
          onFailure: (error, _) => errors.add(error),
        );

        expect(errors.single, isArgumentError);
      },
    );
  }

  test(
    'reporter construction failure is recoverable and can be retried',
    () async {
      final logger = Logger();
      final reporter = _Reporter();
      var attempts = 0;
      final errors = <Object>[];
      final dependencies = _Dependencies(logger, reporter);
      final bootstrap = AppBootstrap(
        config: const _Config(),
        logger: logger,
        reporterFactory: (_) async {
          if (++attempts == 1) throw StateError('Reporter unavailable');
          return reporter;
        },
        dependenciesFactory:
            ({
              required config,
              required logger,
              required errorReporter,
            }) async => dependencies,
        prepareReader: (_) async {},
      );
      await bootstrap.run(
        onReady: (_) => fail('First attempt must fail'),
        onFailure: (error, _) => errors.add(error),
      );
      var ready = false;
      await bootstrap.run(
        onReady: (_) => ready = true,
        onFailure: (error, _) => fail('$error'),
      );

      expect(errors.single, isStateError);
      expect(attempts, 2);
      expect(ready, isTrue);
      await dependencies.dispose();
    },
  );

  test(
    'preparation rollback retains monitoring; successful app owns final disposal',
    () async {
      final logger = Logger();
      final reporter = _Reporter();
      final attempts = <_Dependencies>[];
      final stages = <String>[];
      final errors = <Object>[];
      final zone = Zone.current;
      var reporterCreations = 0;
      final bootstrap = AppBootstrap(
        config: const _Config(),
        logger: logger,
        reporterFactory: (_) async {
          reporterCreations++;
          return reporter;
        },
        dependenciesFactory:
            ({required config, required logger, required errorReporter}) async {
              expect(errorReporter, same(reporter));
              expect(Zone.current, same(zone));
              stages.add('compose');
              final dependencies = _Dependencies(logger, reporter);
              attempts.add(dependencies);
              return dependencies;
            },
        prepareReader: (_) async {
          stages.add('prepare');
          if (attempts.length == 1) {
            throw StateError('Reader preparation failed');
          }
        },
      );

      await bootstrap.run(
        onReady: (_) => fail('First attempt must fail'),
        onFailure: (error, _) => errors.add(error),
      );
      expect(attempts.single.ownedDisposals, 1);
      expect(logger.destroyed, isFalse);
      expect(reporter.closes, 0);

      await bootstrap.run(
        onReady: (dependencies) {
          expect(dependencies, same(attempts.last));
          expect(Zone.current, same(zone));
          stages.add('ready');
        },
        onFailure: (error, _) => fail('$error'),
      );

      expect(stages, ['compose', 'prepare', 'compose', 'prepare', 'ready']);
      expect(errors.single, isStateError);
      expect(reporterCreations, 1);
      expect(attempts.last.ownedDisposals, 0);
      logger.error('probe');
      expect(
        reporter.errors,
        hasLength(2),
        reason: 'Retry must not attach duplicate log observers',
      );
      await attempts.last.dispose();
      await attempts.last.dispose();
      expect(attempts.last.ownedDisposals, 1);
      expect(reporter.closes, 1);
      expect(logger.destroyed, isTrue);
    },
  );

  test(
    'dependency factory failure skips preparation and retains monitoring for retry',
    () async {
      final logger = Logger();
      final reporter = _Reporter();
      var reporterCreations = 0;
      var factoryCalls = 0;
      var preparationCalls = 0;
      final dependencies = _Dependencies(logger, reporter);
      final errors = <Object>[];
      final bootstrap = AppBootstrap(
        config: const _Config(),
        logger: logger,
        reporterFactory: (_) async {
          reporterCreations++;
          return reporter;
        },
        dependenciesFactory:
            ({required config, required logger, required errorReporter}) async {
              if (++factoryCalls == 1) throw StateError('Composition failed');
              return dependencies;
            },
        prepareReader: (_) async {
          preparationCalls++;
        },
      );
      await bootstrap.run(
        onReady: (_) => fail('Must fail'),
        onFailure: (error, _) => errors.add(error),
      );
      expect(preparationCalls, 0);
      await bootstrap.run(
        onReady: (_) {},
        onFailure: (error, _) => fail('$error'),
      );
      expect(errors.single, isStateError);
      expect(reporterCreations, 1);
      expect(preparationCalls, 1);
      await dependencies.dispose();
    },
  );

  test('failed ownership transfer rolls dependencies back', () async {
    final logger = Logger();
    final reporter = _Reporter();
    final dependencies = _Dependencies(logger, reporter);
    final bootstrap = AppBootstrap(
      config: const _Config(),
      logger: logger,
      reporterFactory: (_) async => reporter,
      dependenciesFactory:
          ({required config, required logger, required errorReporter}) async =>
              dependencies,
      prepareReader: (_) async {},
    );
    final errors = <Object>[];
    await bootstrap.run(
      onReady: (_) => throw StateError('Mount failed'),
      onFailure: (error, _) => errors.add(error),
    );
    expect(errors.single, isStateError);
    expect(dependencies.ownedDisposals, 1);
    expect(logger.destroyed, isFalse);
    expect(reporter.closes, 0);
    await reporter.close();
    await logger.destroy();
  });
}

class _Config extends ApplicationConfig {
  const _Config({this.dsn = '', this.invalidEnvironment = false});
  final String dsn;
  final bool invalidEnvironment;

  @override
  Environment get environment =>
      Environment.from(invalidEnvironment ? 'invalid' : 'dev');
  @override
  String get glitchTipDsn => dsn;
  @override
  String get developmentApiKey => '';
  @override
  String get articleCleanerBaseUrl => 'http://localhost:9090';
  @override
  String get contextualTranslationBaseUrl => articleCleanerBaseUrl;
  @override
  String get dictionaryBaseUrl => articleCleanerBaseUrl;
}

final class _Dependencies extends TestDependenciesContainer {
  _Dependencies(Logger logger, _Reporter reporter) {
    _resources = ResourceDisposer(logger: logger)
      ..add('logger', logger.destroy, disposeOnRollback: false)
      ..add('reporter', reporter.close, disposeOnRollback: false)
      ..add('owned', () {
        ownedDisposals++;
      });
  }
  late final ResourceDisposer _resources;
  int ownedDisposals = 0;
  @override
  Future<void> dispose() => _resources.dispose();
  @override
  Future<void> disposeAfterBootstrapFailure() =>
      _resources.dispose(rollback: true);
}

class _Reporter implements ErrorReportingService {
  int closes = 0;
  final errors = <Object>[];
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) async {
    errors.add(throwable);
  }
}
