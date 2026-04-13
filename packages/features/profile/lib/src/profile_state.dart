part of 'profile_cubit.dart';

class ProfileState extends Equatable {
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

  static const _absent = Object();

  ProfileState copyWith({
    AuthStatus? authStatus,
    Object? email = _absent,
    SubscriptionStatus? subscriptionStatus,
    bool? isLoading,
  }) => ProfileState(
    authStatus: authStatus ?? this.authStatus,
    email: email == _absent ? this.email : email as String?,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [authStatus, email, subscriptionStatus, isLoading];
}
