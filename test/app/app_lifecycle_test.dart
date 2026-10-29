import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readflex/app/app_lifecycle.dart';

import '../support/app_fakes.dart';

void main() {
  testWidgets('pausing and resuming keep the dependencies; detach disposes '
      'them once', (tester) async {
    final dependencies = _Dependencies();
    await tester.pumpWidget(
      AppLifecycle(dependencies: dependencies, child: const SizedBox.shrink()),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(dependencies.disposals, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(dependencies.disposals, 1, reason: 'Detach is terminal');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unmounting is not ownership disposal', (tester) async {
    final dependencies = _Dependencies();
    await tester.pumpWidget(
      AppLifecycle(dependencies: dependencies, child: const SizedBox.shrink()),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(dependencies.disposals, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(
      dependencies.disposals,
      0,
      reason: 'The disposed observer must no longer handle lifecycle events',
    );
  });
}

final class _Dependencies extends TestDependenciesContainer {
  int disposals = 0;

  @override
  Future<void> dispose() async {
    disposals++;
  }
}
