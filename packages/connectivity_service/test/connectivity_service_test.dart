import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopConnectivityService', () {
    late NoopConnectivityService service;

    setUp(() => service = NoopConnectivityService());
    tearDown(() => service.dispose());

    test('status is online', () {
      expect(service.status, ConnectivityStatus.online);
    });

    test('statusStream is a broadcast stream', () {
      expect(service.statusStream.isBroadcast, isTrue);
    });
  });
}
