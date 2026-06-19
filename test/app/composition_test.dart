import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/config/application_config.dart';

void main() {
  group('createConnectivityService', () {
    test('uses fixed offline service when overridden', () async {
      final service = await createConnectivityService(
        const _Config(connectivityStatusOverride: 'offline'),
        Logger(),
      );

      addTearDown(service.dispose);

      expect(service, isA<FixedConnectivityService>());
      expect(service.status, ConnectivityStatus.offline);
    });

    test('uses fixed online service when overridden', () async {
      final service = await createConnectivityService(
        const _Config(connectivityStatusOverride: 'online'),
        Logger(),
      );

      addTearDown(service.dispose);

      expect(service, isA<FixedConnectivityService>());
      expect(service.status, ConnectivityStatus.online);
    });

    test('rejects unsupported override values', () {
      expect(
        createConnectivityService(
          const _Config(connectivityStatusOverride: 'slow'),
          Logger(),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

base class _Config extends TestConfig {
  const _Config({required this.connectivityStatusOverride});

  @override
  final String connectivityStatusOverride;
}
