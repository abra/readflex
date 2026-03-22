import 'package:auth_service/auth_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_feature/src/profile_cubit.dart';
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
