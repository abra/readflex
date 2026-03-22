import 'package:auth_service/auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

final class ProfileState extends Equatable {
  const ProfileState({
    this.authStatus = AuthStatus.unauthenticated,
    this.email,
    this.subscriptionStatus = SubscriptionStatus.free,
    this.isLoading = false,
  });

  final AuthStatus authStatus;
  final String? email;
  final SubscriptionStatus subscriptionStatus;
  final bool isLoading;

  bool get isAuthenticated => authStatus == AuthStatus.authenticated;
  bool get isPremium => subscriptionStatus == SubscriptionStatus.premium;

  ProfileState copyWith({
    AuthStatus? authStatus,
    String? email,
    SubscriptionStatus? subscriptionStatus,
    bool? isLoading,
  }) => ProfileState(
    authStatus: authStatus ?? this.authStatus,
    email: email ?? this.email,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [authStatus, email, subscriptionStatus, isLoading];
}

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
      ProfileState(
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
      emit(const ProfileState());
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
