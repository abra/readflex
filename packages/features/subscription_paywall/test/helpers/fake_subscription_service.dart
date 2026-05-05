import 'dart:async';

import 'package:subscription_service/subscription_service.dart';

class FakeSubscriptionService implements SubscriptionService {
  bool shouldThrow = false;
  bool _isPremium = false;
  bool upgradeOnRefresh = false;

  /// When set, `refresh` blocks on this completer's future before
  /// resolving. Tests use this to simulate "user dismissed the paywall
  /// mid-purchase" by closing the cubit while refresh is awaiting.
  Completer<void>? awaitGate;

  @override
  SubscriptionStatus get status =>
      _isPremium ? SubscriptionStatus.premium : SubscriptionStatus.free;

  @override
  bool get isPremium => _isPremium;

  set isPremium(bool value) => _isPremium = value;

  @override
  Future<void> refresh() async {
    if (awaitGate != null) await awaitGate!.future;
    if (shouldThrow) throw Exception('refresh failed');
    if (upgradeOnRefresh) _isPremium = true;
  }
}
