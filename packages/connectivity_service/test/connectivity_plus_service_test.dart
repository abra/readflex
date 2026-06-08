import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityPlusService', () {
    late StreamController<List<ConnectivityResult>> events;

    setUp(() {
      events = StreamController<List<ConnectivityResult>>.broadcast();
    });

    tearDown(() async {
      await events.close();
    });

    ConnectivityPlusService build(ConnectivityStatus initial) =>
        ConnectivityPlusService.forTesting(
          initial: initial,
          events: events.stream,
        );

    test('exposes the injected initial status', () async {
      final service = build(ConnectivityStatus.offline);
      addTearDown(service.dispose);

      expect(service.status, ConnectivityStatus.offline);
    });

    test('emits on transition from online to offline', () async {
      final service = build(ConnectivityStatus.online);
      addTearDown(service.dispose);

      final emissions = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      events.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [ConnectivityStatus.offline]);
      expect(service.status, ConnectivityStatus.offline);
    });

    test('does not emit when an event resolves to the same status', () async {
      // wifi → mobile both map to `online`: consumers shouldn't see a rebuild.
      final service = build(ConnectivityStatus.online);
      addTearDown(service.dispose);

      final emissions = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      events.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty);
    });

    test(
      'statusStream is broadcast — multiple listeners receive events',
      () async {
        final service = build(ConnectivityStatus.online);
        addTearDown(service.dispose);

        final a = <ConnectivityStatus>[];
        final b = <ConnectivityStatus>[];
        final subA = service.statusStream.listen(a.add);
        final subB = service.statusStream.listen(b.add);
        addTearDown(subA.cancel);
        addTearDown(subB.cancel);

        events.add([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);

        expect(a, [ConnectivityStatus.offline]);
        expect(b, [ConnectivityStatus.offline]);
      },
    );

    test('maps vpn-only events to offline', () async {
      final service = build(ConnectivityStatus.online);
      addTearDown(service.dispose);

      final emissions = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      events.add([ConnectivityResult.vpn]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [ConnectivityStatus.offline]);
      expect(service.status, ConnectivityStatus.offline);
    });

    test('keeps vpn plus an underlying interface online', () async {
      final service = build(ConnectivityStatus.online);
      addTearDown(service.dispose);

      final emissions = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      events.add([ConnectivityResult.wifi, ConnectivityResult.vpn]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty);
      expect(service.status, ConnectivityStatus.online);
    });

    test('refresh re-reads platform status and emits changes', () async {
      var platformResults = [ConnectivityResult.wifi];
      final service = ConnectivityPlusService.forTesting(
        initial: ConnectivityStatus.online,
        events: events.stream,
        read: () async => platformResults,
      );
      addTearDown(service.dispose);

      final emissions = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(emissions.add);
      addTearDown(sub.cancel);

      platformResults = [ConnectivityResult.none];
      await service.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(service.status, ConnectivityStatus.offline);
      expect(emissions, [ConnectivityStatus.offline]);
    });

    test('dispose() closes the stream and stops listening', () async {
      final service = build(ConnectivityStatus.online);

      var done = false;
      final sub = service.statusStream.listen(
        (_) {},
        onDone: () => done = true,
      );

      service.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
      await sub.cancel();
    });
  });
}
