import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/src/reader_load_session.dart';

void main() {
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
