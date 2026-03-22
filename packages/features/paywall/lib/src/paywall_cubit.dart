import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

enum PaywallStatus { idle, purchasing, success, failure }

final class PaywallState extends Equatable {
  const PaywallState({
    this.status = PaywallStatus.idle,
    this.isPremium = false,
  });

  final PaywallStatus status;
  final bool isPremium;

  PaywallState copyWith({
    PaywallStatus? status,
    bool? isPremium,
  }) => PaywallState(
    status: status ?? this.status,
    isPremium: isPremium ?? this.isPremium,
  );

  @override
  List<Object?> get props => [status, isPremium];
}

class PaywallCubit extends Cubit<PaywallState> {
  PaywallCubit({required SubscriptionService subscriptionService})
    : _subscriptionService = subscriptionService,
      super(const PaywallState());

  final SubscriptionService _subscriptionService;

  void load() {
    emit(state.copyWith(isPremium: _subscriptionService.isPremium));
  }

  Future<void> purchase() async {
    emit(state.copyWith(status: PaywallStatus.purchasing));

    try {
      // In a real implementation, this would trigger the platform purchase flow.
      // For now, refresh status to check if the user has become premium.
      await _subscriptionService.refresh();
      final isPremium = _subscriptionService.isPremium;
      emit(
        state.copyWith(
          status: isPremium ? PaywallStatus.success : PaywallStatus.idle,
          isPremium: isPremium,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: PaywallStatus.failure));
    }
  }
}
