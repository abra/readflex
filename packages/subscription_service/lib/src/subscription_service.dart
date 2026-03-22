/// Premium subscription status.
enum SubscriptionStatus { free, premium }

/// Service to check and manage premium subscription.
abstract class SubscriptionService {
  /// Current subscription status.
  SubscriptionStatus get status;

  /// Whether the user has premium access.
  bool get isPremium;

  /// Refresh subscription status from server.
  Future<void> refresh();
}

/// Stub — always free tier.
class NoopSubscriptionService implements SubscriptionService {
  const NoopSubscriptionService();

  @override
  SubscriptionStatus get status => SubscriptionStatus.free;

  @override
  bool get isPremium => false;

  @override
  Future<void> refresh() async {}
}
