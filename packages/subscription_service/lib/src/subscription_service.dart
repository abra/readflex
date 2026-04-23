/// Premium subscription tier of the current user.
enum SubscriptionStatus { free, premium }

/// Contract for reading and refreshing the user's premium subscription
/// status. Used to gate premium-only features (lock icon → paywall).
abstract class SubscriptionService {
  /// Current subscription status.
  SubscriptionStatus get status;

  /// Whether the user has premium access.
  bool get isPremium;

  /// Refresh subscription status from server.
  Future<void> refresh();
}

/// Stub [SubscriptionService] that reports every user as free tier and
/// ignores refresh calls. Used during development until the real
/// implementation (RevenueCat / in-app purchases) is wired in.
class NoopSubscriptionService implements SubscriptionService {
  const NoopSubscriptionService();

  @override
  SubscriptionStatus get status => SubscriptionStatus.free;

  @override
  bool get isPremium => false;

  @override
  Future<void> refresh() async {}
}
