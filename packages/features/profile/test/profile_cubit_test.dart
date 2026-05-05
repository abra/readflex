import 'dart:async';

import 'package:auth_service/auth_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/src/profile_cubit.dart';
import 'package:subscription_service/subscription_service.dart';

void main() {
  group('ProfileCubit', () {
    late NoopAuthService authService;
    late NoopSubscriptionService subscriptionService;

    setUp(() {
      authService = NoopAuthService();
      subscriptionService = const NoopSubscriptionService();
    });

    tearDown(() => authService.dispose());

    blocTest<ProfileCubit, ProfileState>(
      'load emits state with auth and subscription status',
      build: () => ProfileCubit(
        authService: authService,
        subscriptionService: subscriptionService,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const ProfileState(
          authStatus: AuthStatus.unauthenticated,
          subscriptionStatus: SubscriptionStatus.free,
        ),
      ],
    );

    blocTest<ProfileCubit, ProfileState>(
      'signOut resets to unauthenticated state',
      build: () => ProfileCubit(
        authService: authService,
        subscriptionService: subscriptionService,
      ),
      act: (cubit) => cubit.signOut(),
      expect: () => [
        const ProfileState(isLoading: true),
        const ProfileState(),
      ],
    );

    // Race-protection: signOut typically triggers a route change back
    // to the auth gate, which can tear down the profile scope (and
    // thus close the cubit) before AuthService.signOut resolves.
    // Without an `isClosed` guard the post-await emit would throw
    // StateError ("Cannot emit new states after calling close").
    test(
      'signOut: post-await emit is skipped when cubit closes mid-call',
      () async {
        final gatedAuth = _GatedAuthService();
        addTearDown(gatedAuth.dispose);

        final cubit = ProfileCubit(
          authService: gatedAuth,
          subscriptionService: subscriptionService,
        );

        unawaited(cubit.signOut());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isLoading, isTrue);

        await cubit.close();
        gatedAuth.signOutGate.complete();
        await Future<void>.delayed(Duration.zero);

        // Reaching this line without StateError is the assertion: state
        // stays at the pre-close value (`isLoading: true`) because the
        // post-await emit was intercepted by the guard.
        expect(cubit.isClosed, isTrue);
        expect(cubit.state.isLoading, isTrue);
      },
    );
  });

  group('ProfileState', () {
    test('isAuthenticated returns true when authenticated', () {
      const state = ProfileState(authStatus: AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
    });

    test('isPremium returns true when premium', () {
      const state = ProfileState(
        subscriptionStatus: SubscriptionStatus.premium,
      );
      expect(state.isPremium, isTrue);
    });

    test('defaults are unauthenticated and free', () {
      const state = ProfileState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isPremium, isFalse);
    });
  });
}

/// Auth service that blocks `signOut` on a completer so a test can
/// dismiss the cubit while the call is in flight, then resolve the
/// completer to verify the post-await emit is safely skipped.
class _GatedAuthService extends NoopAuthService {
  final Completer<void> signOutGate = Completer<void>();

  @override
  Future<void> signOut() async {
    await signOutGate.future;
  }
}
