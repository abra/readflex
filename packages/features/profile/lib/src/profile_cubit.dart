import 'package:auth_service/auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

part 'profile_state.dart';

/// Drives the account portion of [ProfileScreen]: auth state, current
/// email, and premium status.
///
/// Snapshots values from [AuthService] and [SubscriptionService] on
/// [load], and handles [signOut] with a loading flag and non-fatal error
/// logging.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required AuthService authService,
    required SubscriptionService subscriptionService,
  }) : _authService = authService,
       _subscriptionService = subscriptionService,
       super(const ProfileState());

  final AuthService _authService;
  final SubscriptionService _subscriptionService;

  void load() {
    emit(
      state.copyWith(
        authStatus: _authService.status,
        email: _authService.currentUser?.email,
        subscriptionStatus: _subscriptionService.status,
      ),
    );
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.signOut();
      // Sign-out kicks off a route change (back to auth gate) that can
      // tear down the profile scope before this future resolves, closing
      // the cubit. Bail out instead of throwing on emit-after-close.
      if (isClosed) return;
      emit(
        state.copyWith(
          authStatus: AuthStatus.unauthenticated,
          email: null,
          subscriptionStatus: SubscriptionStatus.free,
          isLoading: false,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      // Route through BlocBase.addError → AppBlocObserver.onError → logger.
      // Sign-out failure is non-fatal for app state (user stays authenticated),
      // but must be visible in logs to debug production auth issues.
      addError(e, st);
      emit(state.copyWith(isLoading: false));
    }
  }
}
