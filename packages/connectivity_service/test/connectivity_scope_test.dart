import 'dart:async';

import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [ConnectivityScope] with a controllable stream. Stays tiny on
/// purpose — the scope doesn't need anything else from the service contract.
class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this._initial);

  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _initial;

  @override
  ConnectivityStatus get status => _initial;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  void emit(ConnectivityStatus next) {
    _initial = next;
    _controller.add(next);
  }

  @override
  void dispose() => _controller.close();
}

void main() {
  group('ConnectivityScope', () {
    testWidgets('exposes the current status to descendants', (tester) async {
      final service = _FakeConnectivityService(ConnectivityStatus.online);
      addTearDown(service.dispose);

      ConnectivityStatus? observed;
      await tester.pumpWidget(
        ConnectivityScope(
          service: service,
          child: Builder(
            builder: (context) {
              observed = ConnectivityScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(observed, ConnectivityStatus.online);
    });

    testWidgets('rebuilds descendants when status changes', (tester) async {
      final service = _FakeConnectivityService(ConnectivityStatus.online);
      addTearDown(service.dispose);

      var buildCount = 0;
      await tester.pumpWidget(
        ConnectivityScope(
          service: service,
          child: Builder(
            builder: (context) {
              buildCount++;
              ConnectivityScope.of(context); // subscribe
              return const SizedBox();
            },
          ),
        ),
      );
      expect(buildCount, 1);

      service.emit(ConnectivityStatus.offline);
      await tester.pumpAndSettle();
      expect(buildCount, 2);
    });

    testWidgets('throws when used without a ConnectivityScope ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => ConnectivityScope.of(context),
              throwsA(isA<FlutterError>()),
            );
            return const SizedBox();
          },
        ),
      );
    });
  });
}
