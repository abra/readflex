import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_paywall/src/subscription_paywall_cubit.dart';

import 'helpers/fake_subscription_service.dart';

void main() {
  late FakeSubscriptionService subscriptionService;

  setUp(() {
    subscriptionService = FakeSubscriptionService();
  });

  group('SubscriptionPaywallCubit', () {
    blocTest<SubscriptionPaywallCubit, SubscriptionPaywallState>(
      'initial state has idle status and not premium',
      build: () => SubscriptionPaywallCubit(
        subscriptionService: subscriptionService,
      ),
      verify: (cubit) {
        expect(cubit.state.status, SubscriptionPaywallStatus.idle);
        expect(cubit.state.isPremium, isFalse);
      },
    );

    blocTest<SubscriptionPaywallCubit, SubscriptionPaywallState>(
      'load emits isPremium from subscription service',
      build: () {
        subscriptionService.isPremium = true;
        return SubscriptionPaywallCubit(
          subscriptionService: subscriptionService,
        );
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const SubscriptionPaywallState(isPremium: true),
      ],
    );

    blocTest<SubscriptionPaywallCubit, SubscriptionPaywallState>(
      'purchase emits purchasing then success when upgraded',
      build: () {
        subscriptionService.upgradeOnRefresh = true;
        return SubscriptionPaywallCubit(
          subscriptionService: subscriptionService,
        );
      },
      act: (cubit) => cubit.purchase(),
      expect: () => [
        const SubscriptionPaywallState(
          status: SubscriptionPaywallStatus.purchasing,
        ),
        const SubscriptionPaywallState(
          status: SubscriptionPaywallStatus.success,
          isPremium: true,
        ),
      ],
    );

    blocTest<SubscriptionPaywallCubit, SubscriptionPaywallState>(
      'purchase returns to idle when not upgraded',
      build: () => SubscriptionPaywallCubit(
        subscriptionService: subscriptionService,
      ),
      act: (cubit) => cubit.purchase(),
      expect: () => [
        const SubscriptionPaywallState(
          status: SubscriptionPaywallStatus.purchasing,
        ),
        const SubscriptionPaywallState(
          status: SubscriptionPaywallStatus.idle,
        ),
      ],
    );

    blocTest<SubscriptionPaywallCubit, SubscriptionPaywallState>(
      'purchase emits failure on error',
      build: () {
        subscriptionService.shouldThrow = true;
        return SubscriptionPaywallCubit(
          subscriptionService: subscriptionService,
        );
      },
      act: (cubit) => cubit.purchase(),
      expect: () => [
        const SubscriptionPaywallState(
          status: SubscriptionPaywallStatus.purchasing,
        ),
        const SubscriptionPaywallState(
          status: SubscriptionPaywallStatus.failure,
        ),
      ],
    );
  });
}
