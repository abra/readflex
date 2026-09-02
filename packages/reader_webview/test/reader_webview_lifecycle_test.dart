import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/src/reader_webview_lifecycle.dart';

void main() {
  test('applies the initial resumed state when a WebView attaches', () async {
    final calls = <String>[];
    final lifecycle = ReaderWebViewLifecycleCoordinator(
      initialState: AppLifecycleState.resumed,
    );

    lifecycle.attach(
      pause: () async => calls.add('pause'),
      resume: () async => calls.add('resume'),
    );
    await lifecycle.settled;

    expect(calls, ['resume']);
  });

  test('coalesces inactive and paused into one WebView pause', () async {
    final calls = <String>[];
    final lifecycle = ReaderWebViewLifecycleCoordinator(
      initialState: AppLifecycleState.resumed,
    );
    lifecycle.attach(
      pause: () async => calls.add('pause'),
      resume: () async => calls.add('resume'),
    );
    await lifecycle.settled;

    lifecycle.handleAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.handleAppLifecycleState(AppLifecycleState.hidden);
    lifecycle.handleAppLifecycleState(AppLifecycleState.paused);
    await lifecycle.settled;
    lifecycle.handleAppLifecycleState(AppLifecycleState.resumed);
    await lifecycle.settled;

    expect(calls, ['resume', 'pause', 'resume']);
  });

  test('applies the latest lifecycle state after a late attach', () async {
    final calls = <String>[];
    final lifecycle = ReaderWebViewLifecycleCoordinator(
      initialState: AppLifecycleState.resumed,
    );

    lifecycle.handleAppLifecycleState(AppLifecycleState.paused);
    lifecycle.attach(
      pause: () async => calls.add('pause'),
      resume: () async => calls.add('resume'),
    );
    await lifecycle.settled;

    expect(calls, ['pause']);
  });

  test('drops queued work for a replaced WebView controller', () async {
    final calls = <String>[];
    final lifecycle = ReaderWebViewLifecycleCoordinator(
      initialState: AppLifecycleState.resumed,
    );

    lifecycle.attach(
      pause: () async => calls.add('old-pause'),
      resume: () async => calls.add('old-resume'),
    );
    lifecycle.attach(
      pause: () async => calls.add('new-pause'),
      resume: () async => calls.add('new-resume'),
    );
    await lifecycle.settled;

    expect(calls, ['new-resume']);
  });

  test('reports command failures and continues processing', () async {
    final calls = <String>[];
    final errors = <String>[];
    final lifecycle = ReaderWebViewLifecycleCoordinator(
      initialState: AppLifecycleState.paused,
      onError: (resuming, error, stackTrace) {
        errors.add('${resuming ? 'resume' : 'pause'}:$error');
      },
    );
    lifecycle.attach(
      pause: () async => throw StateError('not attached'),
      resume: () async => calls.add('resume'),
    );
    await lifecycle.settled;

    lifecycle.handleAppLifecycleState(AppLifecycleState.resumed);
    await lifecycle.settled;

    expect(errors.single, contains('pause:Bad state: not attached'));
    expect(calls, ['resume']);
  });
}
