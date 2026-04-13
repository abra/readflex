part of 'subscription_paywall_cubit.dart';

enum SubscriptionPaywallStatus { idle, purchasing, success, failure }

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
