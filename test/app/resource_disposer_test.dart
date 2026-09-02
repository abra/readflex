import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/resource_disposer.dart';

void main() {
  group('ResourceDisposer', () {
    test('disposes resources once in reverse creation order', () async {
      final calls = <String>[];
      final disposer = ResourceDisposer(logger: Logger())
        ..add('first', () => calls.add('first'))
        ..add('second', () async => calls.add('second'));

      await Future.wait([disposer.dispose(), disposer.dispose()]);

      expect(calls, ['second', 'first']);
    });

    test('continues disposing after a callback fails', () async {
      final calls = <String>[];
      final disposer = ResourceDisposer(logger: Logger())
        ..add('first', () => calls.add('first'))
        ..add('failing', () => throw StateError('failed'))
        ..add('last', () => calls.add('last'));

      await disposer.dispose();

      expect(calls, ['last', 'first']);
    });

    test('retains externally owned resources during rollback', () async {
      final calls = <String>[];
      final disposer = ResourceDisposer(logger: Logger())
        ..add(
          'external',
          () => calls.add('external'),
          disposeOnRollback: false,
        )
        ..add('owned', () => calls.add('owned'));

      await disposer.dispose(rollback: true);

      expect(calls, ['owned']);
    });

    test('rejects resources added after disposal starts', () async {
      final disposer = ResourceDisposer(logger: Logger());

      final disposal = disposer.dispose();

      expect(
        () => disposer.add('late', () {}),
        throwsA(isA<StateError>()),
      );
      await disposal;
    });
  });
}
