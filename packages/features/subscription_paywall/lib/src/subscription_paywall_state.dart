part of 'subscription_paywall_cubit.dart';

/// Lifecycle of the paywall sheet's purchase action.
enum SubscriptionPaywallStatus { idle, purchasing, success, failure }

/// State of the paywall sheet: purchase lifecycle plus the user's
/// current premium flag.
class SubscriptionPaywallState extends Equatable {
  const SubscriptionPaywallState({
    this.status = SubscriptionPaywallStatus.idle,
    this.isPremium = false,
  });

  final SubscriptionPaywallStatus status;
  final bool isPremium;

  SubscriptionPaywallState copyWith({
    SubscriptionPaywallStatus? status,
    bool? isPremium,
  }) => SubscriptionPaywallState(
    status: status ?? this.status,
    isPremium: isPremium ?? this.isPremium,
  );

  @override
  List<Object?> get props => [status, isPremium];
}
