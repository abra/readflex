import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/src/reader_load_session.dart';

void main() {
  test(
    'startup timing separates first content and initial location once per generation',
    () {
      final stages = <String>[];
      final session = ReaderLoadSession(
        onFailed: (_) {},
        onTiming: (stage, elapsed) {
          expect(elapsed, greaterThanOrEqualTo(Duration.zero));
          stages.add(stage);
        },
      );
      addTearDown(session.dispose);
      session.start();
      session.markReady();
      session.markReady();
      expect(stages, ['webview-created', 'first-content-ready']);
      session.markReady(loadComplete: true);
      session.markReady(loadComplete: true);
      session.recoverRenderer();
      session.start();
      session.markReady(loadComplete: true);
      expect(stages, [
        'webview-created',
        'first-content-ready',
        'initial-location-ready',
        'webview-created',
        'first-content-ready',
        'initial-location-ready',
      ]);
      session.dispose();
      session.markReady();
      session.markReady(loadComplete: true);
      expect(stages, hasLength(6));
    },
  );

  test('timing callback failures do not affect load state', () {
    final session = ReaderLoadSession(
      onFailed: (_) {},
      onTiming: (_, _) => throw StateError('Diagnostic sink failed'),
    );
    addTearDown(session.dispose);
    expect(session.start, returnsNormally);
    expect(session.markReady(), isTrue);
    expect(session.markReady(loadComplete: true), isTrue);
    expect(session.recoverRenderer(), isTrue);
  });

  test('late failure cannot relabel a completed startup', () {
    final stages = <String>[];
    final failures = <ReaderLoadFailure>[];
    final session = ReaderLoadSession(
      onFailed: failures.add,
      onTiming: (stage, _) => stages.add(stage),
    );
    addTearDown(session.dispose);
    session.start();
    session.markReady(loadComplete: true);
    session.fail(const ReaderLoadFailure(ReaderLoadFailureKind.network));
    expect(stages, [
      'webview-created',
      'first-content-ready',
      'initial-location-ready',
    ]);
    expect(failures.single.kind, ReaderLoadFailureKind.network);
  });

  test('failed startup reports one terminal timing and no late readiness', () {
    final stages = <String>[];
    final session = ReaderLoadSession(
      onFailed: (_) {},
      onTiming: (stage, _) => stages.add(stage),
    );
    addTearDown(session.dispose);
    session.start();
    session.fail(const ReaderLoadFailure(ReaderLoadFailureKind.network));
    session.fail(const ReaderLoadFailure(ReaderLoadFailureKind.document));
    expect(session.markReady(), isFalse);
    expect(session.markReady(loadComplete: true), isFalse);
    expect(stages, ['webview-created', 'failed-network']);
  });

  test(
    'failure after first content is not reported as completed restoration',
    () {
      final stages = <String>[];
      final session = ReaderLoadSession(
        onFailed: (_) {},
        onTiming: (stage, _) => stages.add(stage),
      );
      addTearDown(session.dispose);
      session.start();
      session.markReady();
      session.fail(const ReaderLoadFailure(ReaderLoadFailureKind.document));
      expect(session.markReady(loadComplete: true), isFalse);
      expect(stages, [
        'webview-created',
        'first-content-ready',
        'failed-document',
      ]);
    },
  );

  testWidgets('load timeout becomes terminal and ignores late readiness', (
    tester,
  ) async {
    final failures = <ReaderLoadFailure>[];
    final session = ReaderLoadSession(
      onFailed: failures.add,
      timeout: const Duration(seconds: 1),
    );
    addTearDown(session.dispose);
    session.start();
    await tester.pump(const Duration(seconds: 1));
    expect(failures.single.kind, ReaderLoadFailureKind.timeout);
    expect(session.markReady(), isFalse);
  });

  testWidgets(
    'renderer recovery replaces generation once and preserves the watchdog',
    (tester) async {
      final failures = <ReaderLoadFailure>[];
      final session = ReaderLoadSession(
        onFailed: failures.add,
        timeout: const Duration(seconds: 1),
      );
      addTearDown(session.dispose);
      session.start();
      expect(session.markReady(), isTrue);
      expect(session.recoverRenderer(), isTrue);
      expect(session.generation, 1);
      session.start();
      await tester.pump(const Duration(seconds: 1));
      expect(failures.single.kind, ReaderLoadFailureKind.timeout);
      expect(session.recoverRenderer(), isFalse);
      expect(failures, hasLength(1));
    },
  );

  test(
    'repeated renderer death fails instead of looping, even after readiness',
    () {
      final failures = <ReaderLoadFailure>[];
      final session = ReaderLoadSession(onFailed: failures.add);
      addTearDown(session.dispose);
      session.start();
      session.markReady();
      expect(session.recoverRenderer(), isTrue);
      session.start();
      session.markReady();
      expect(session.recoverRenderer(), isFalse);
      expect(failures.single.kind, ReaderLoadFailureKind.rendererTerminated);
    },
  );

  testWidgets('disposed and completed sessions cancel their load watchdog', (
    tester,
  ) async {
    final failures = <ReaderLoadFailure>[];
    final session = ReaderLoadSession(
      onFailed: failures.add,
      timeout: const Duration(seconds: 1),
    );
    session.start();
    session.markReady();
    await tester.pump(const Duration(seconds: 2));
    expect(failures, isEmpty);
    session.recoverRenderer();
    session.start();
    session.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(failures, isEmpty);
    expect(session.markReady(), isFalse);
  });
}
