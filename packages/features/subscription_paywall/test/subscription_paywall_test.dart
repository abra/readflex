import 'dart:async';

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

    // Race-protection: the user can dismiss the paywall (gesture-down,
    // back button, navigation) while the platform purchase / refresh
    // call is still in flight. Without an `isClosed` guard, the post-
    // await emit would throw StateError ("Cannot emit new states after
    // calling close"). The guard makes purchase a no-op past close.
    test(
      'purchase: post-await emit is skipped when cubit closes mid-call',
      () async {
        subscriptionService.awaitGate = Completer<void>();
        final cubit = SubscriptionPaywallCubit(
          subscriptionService: subscriptionService,
        );

        unawaited(cubit.purchase());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, SubscriptionPaywallStatus.purchasing);

        await cubit.close();
        subscriptionService.awaitGate!.complete();
        await Future<void>.delayed(Duration.zero);

        // Reaching this without StateError is the assertion: state
        // stayed at the pre-close `purchasing` because the post-await
        // emit was intercepted.
        expect(cubit.isClosed, isTrue);
        expect(cubit.state.status, SubscriptionPaywallStatus.purchasing);
      },
    );
  });
}
