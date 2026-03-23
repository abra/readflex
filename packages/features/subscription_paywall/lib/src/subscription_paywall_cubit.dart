import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

enum SubscriptionPaywallStatus { idle, purchasing, success, failure }

final class SubscriptionPaywallState extends Equatable {
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
    } catch (e) {
      emit(state.copyWith(status: SubscriptionPaywallStatus.failure));
    }
  }
}
