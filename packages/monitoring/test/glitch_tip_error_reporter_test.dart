import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';

final class _FakeGlitchTipClient implements GlitchTipReporterClient {
  _FakeGlitchTipClient({
    this.enabledAfterInitialize = true,
    this.initializeError,
  });

  final bool enabledAfterInitialize;
  final Object? initializeError;

  var initializeCalls = 0;
  var closeCalls = 0;
  GlitchTipReporterConfig? initializedConfig;
  final captured = <({Object throwable, StackTrace? stackTrace})>[];

  @override
  bool get isEnabled => initializeCalls > 0 && enabledAfterInitialize;

  @override
  Future<void> initialize(GlitchTipReporterConfig config) async {
    initializeCalls += 1;
    initializedConfig = config;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) async {
    captured.add((throwable: throwable, stackTrace: stackTrace));
  }

  @override
  Future<void> close() async {
    closeCalls += 1;
  }
}

void main() {
  group('GlitchTipErrorReporter', () {
    test('does not initialize without a DSN', () async {
      final client = _FakeGlitchTipClient();
      final reporter = GlitchTipErrorReporter(
        dsn: ' ',
        environment: 'production',
        client: client,
      );

      await reporter.initialize();

      expect(reporter.isInitialized, isFalse);
      expect(client.initializeCalls, 0);
    });

    test(
      'initializes the Sentry-compatible Dart client with GlitchTip config',
      () async {
        final client = _FakeGlitchTipClient();
        final reporter = GlitchTipErrorReporter(
          dsn: ' https://glitchtip.example/1 ',
          environment: ' production ',
          release: '1.0.0+2',
          tracesSampleRate: 0.01,
          client: client,
        );

        await reporter.initialize();

        expect(reporter.isInitialized, isTrue);
        expect(client.initializeCalls, 1);
        expect(client.initializedConfig?.dsn, 'https://glitchtip.example/1');
        expect(client.initializedConfig?.environment, 'production');
        expect(client.initializedConfig?.release, '1.0.0+2');
        expect(client.initializedConfig?.tracesSampleRate, 0.01);
      },
    );

    test('clamps traces sample rate to the valid SDK range', () async {
      final highClient = _FakeGlitchTipClient();
      final highReporter = GlitchTipErrorReporter(
        dsn: 'https://glitchtip.example/1',
        environment: 'production',
        tracesSampleRate: 2,
        client: highClient,
      );

      await highReporter.initialize();

      final lowClient = _FakeGlitchTipClient();
      final lowReporter = GlitchTipErrorReporter(
        dsn: 'https://glitchtip.example/1',
        environment: 'production',
        tracesSampleRate: -1,
        client: lowClient,
      );

      await lowReporter.initialize();

      expect(highClient.initializedConfig?.tracesSampleRate, 1);
      expect(lowClient.initializedConfig?.tracesSampleRate, 0);
    });

    test('does not capture before initialization', () async {
      final client = _FakeGlitchTipClient();
      final reporter = GlitchTipErrorReporter(
        dsn: 'https://glitchtip.example/1',
        environment: 'production',
        client: client,
      );

      await reporter.captureException(throwable: Exception('boom'));

      expect(client.captured, isEmpty);
    });

    test('captures exceptions after initialization', () async {
      final client = _FakeGlitchTipClient();
      final reporter = GlitchTipErrorReporter(
        dsn: 'https://glitchtip.example/1',
        environment: 'production',
        client: client,
      );
      final trace = StackTrace.current;

      await reporter.initialize();
      await reporter.captureException(
        throwable: Exception('boom'),
        stackTrace: trace,
      );

      expect(client.captured, hasLength(1));
      expect(client.captured.first.throwable, isA<Exception>());
      expect(client.captured.first.stackTrace, trace);
    });

    test(
      'stays disabled when the SDK reports disabled after initialization',
      () async {
        final client = _FakeGlitchTipClient(enabledAfterInitialize: false);
        final reporter = GlitchTipErrorReporter(
          dsn: 'https://glitchtip.example/1',
          environment: 'production',
          client: client,
        );

        await reporter.initialize();
        await reporter.captureException(throwable: Exception('boom'));

        expect(reporter.isInitialized, isFalse);
        expect(client.captured, isEmpty);
      },
    );

    test('stays disabled when SDK initialization throws', () async {
      final client = _FakeGlitchTipClient(initializeError: StateError('bad'));
      final reporter = GlitchTipErrorReporter(
        dsn: 'https://glitchtip.example/1',
        environment: 'production',
        client: client,
      );

      await reporter.initialize();
      await reporter.captureException(throwable: Exception('boom'));

      expect(reporter.isInitialized, isFalse);
      expect(client.initializeCalls, 1);
      expect(client.captured, isEmpty);
    });

    test('close delegates only after successful initialization', () async {
      final client = _FakeGlitchTipClient();
      final reporter = GlitchTipErrorReporter(
        dsn: 'https://glitchtip.example/1',
        environment: 'production',
        client: client,
      );

      await reporter.close();
      expect(client.closeCalls, 0);

      await reporter.initialize();
      await reporter.close();

      expect(client.closeCalls, 1);
      expect(reporter.isInitialized, isFalse);
    });
  });
}
