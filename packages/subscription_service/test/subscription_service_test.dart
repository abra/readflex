import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_service/subscription_service.dart';

void main() {
  group('NoopSubscriptionService', () {
    test('status is free', () {
      const service = NoopSubscriptionService();
      expect(service.status, SubscriptionStatus.free);
    });

    test('isPremium is false', () {
      const service = NoopSubscriptionService();
      expect(service.isPremium, isFalse);
    });

    test('refresh completes without error', () async {
      const service = NoopSubscriptionService();
      await expectLater(service.refresh(), completes);
    });
  });
}
