import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

part 'subscription_paywall_state.dart';

class SubscriptionPaywallCubit extends Cubit<SubscriptionPaywallState> {
  SubscriptionPaywallCubit({required SubscriptionService subscriptionService})
    : _subscriptionService = subscriptionService,
      super(const SubscriptionPaywallState());

  final SubscriptionService _subscriptionService;

  void load() {
    emit(state.copyWith(isPremium: _subscriptionService.isPremium));
  }

  Future<void> purchase() async {
    emit(state.copyWith(status: SubscriptionPaywallStatus.purchasing));

    try {
      // In a real implementation, this would trigger the platform purchase flow.
      // For now, refresh status to check if the user has become premium.
      await _subscriptionService.refresh();
      final isPremium = _subscriptionService.isPremium;
      emit(
        state.copyWith(
          status: isPremium
              ? SubscriptionPaywallStatus.success
              : SubscriptionPaywallStatus.idle,
          isPremium: isPremium,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: SubscriptionPaywallStatus.failure));
    }
  }
}
