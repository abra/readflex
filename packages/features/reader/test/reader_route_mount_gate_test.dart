import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_route_mount_gate.dart';

void main() {
  testWidgets('mounts child immediately on an already-ready route', (
    tester,
  ) async {
    var childBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderRouteMountGate(
          builder: (_, canMountChild) {
            if (!canMountChild) return const Text('waiting');
            childBuilds += 1;
            return const Text('reader');
          },
        ),
      ),
    );

    expect(find.text('reader'), findsOneWidget);
    expect(find.text('waiting'), findsNothing);
    expect(childBuilds, 1);
  });

  testWidgets('waits for the configured delay before mounting child', (
    tester,
  ) async {
    var childBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderRouteMountGate(
          delay: const Duration(milliseconds: 300),
          builder: (_, canMountChild) {
            if (!canMountChild) return const Text('waiting');
            childBuilds += 1;
            return const Text('reader');
          },
        ),
      ),
    );

    expect(find.text('waiting'), findsOneWidget);
    expect(find.text('reader'), findsNothing);
    expect(childBuilds, 0);

    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('waiting'), findsOneWidget);
    expect(find.text('reader'), findsNothing);
    expect(childBuilds, 0);

    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('waiting'), findsNothing);
    expect(find.text('reader'), findsOneWidget);
    expect(childBuilds, 1);
  });
}
