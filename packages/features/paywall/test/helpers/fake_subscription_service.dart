import 'package:subscription_service/subscription_service.dart';

class FakeSubscriptionService implements SubscriptionService {
  bool shouldThrow = false;
  bool _isPremium = false;
  bool upgradeOnRefresh = false;

  @override
  SubscriptionStatus get status =>
      _isPremium ? SubscriptionStatus.premium : SubscriptionStatus.free;

  @override
  bool get isPremium => _isPremium;

  set isPremium(bool value) => _isPremium = value;

  @override
  Future<void> refresh() async {
    if (shouldThrow) throw Exception('refresh failed');
    if (upgradeOnRefresh) _isPremium = true;
  }
}
