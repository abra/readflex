import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paywall_feature/src/paywall_cubit.dart';

import 'helpers/fake_subscription_service.dart';

void main() {
  late FakeSubscriptionService subscriptionService;

  setUp(() {
    subscriptionService = FakeSubscriptionService();
  });

  group('PaywallCubit', () {
    blocTest<PaywallCubit, PaywallState>(
      'initial state has idle status and not premium',
      build: () => PaywallCubit(subscriptionService: subscriptionService),
      verify: (cubit) {
        expect(cubit.state.status, PaywallStatus.idle);
        expect(cubit.state.isPremium, isFalse);
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'load emits isPremium from subscription service',
      build: () {
        subscriptionService.isPremium = true;
        return PaywallCubit(subscriptionService: subscriptionService);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const PaywallState(isPremium: true),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'purchase emits purchasing then success when upgraded',
      build: () {
        subscriptionService.upgradeOnRefresh = true;
        return PaywallCubit(subscriptionService: subscriptionService);
      },
      act: (cubit) => cubit.purchase(),
      expect: () => [
        const PaywallState(status: PaywallStatus.purchasing),
        const PaywallState(
          status: PaywallStatus.success,
          isPremium: true,
        ),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'purchase returns to idle when not upgraded',
      build: () => PaywallCubit(subscriptionService: subscriptionService),
      act: (cubit) => cubit.purchase(),
      expect: () => [
        const PaywallState(status: PaywallStatus.purchasing),
        const PaywallState(status: PaywallStatus.idle),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'purchase emits failure on error',
      build: () {
        subscriptionService.shouldThrow = true;
        return PaywallCubit(subscriptionService: subscriptionService);
      },
      act: (cubit) => cubit.purchase(),
      expect: () => [
        const PaywallState(status: PaywallStatus.purchasing),
        const PaywallState(status: PaywallStatus.failure),
      ],
    );
  });
}
