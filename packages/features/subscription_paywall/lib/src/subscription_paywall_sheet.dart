import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

import 'subscription_paywall_cubit.dart';

/// Opens the [SubscriptionPaywallSheet] as a modal bottom sheet. Call
/// from any surface that gates a premium feature (pro badge in profile,
/// lock icon taps, etc.).
void showSubscriptionPaywallSheet(
  BuildContext context, {
  required SubscriptionService subscriptionService,
}) {
  showAppBottomSheet<void>(
    context,
    builder: (_) => SubscriptionPaywallSheet(
      subscriptionService: subscriptionService,
    ),
  );
}

/// Full-screen bottom sheet that upsells Readflex Premium and runs the
/// purchase flow.
///
/// Provides its own [SubscriptionPaywallCubit] and closes itself once
/// the user becomes premium. Usually launched via
/// [showSubscriptionPaywallSheet], not constructed directly.
class SubscriptionPaywallSheet extends StatelessWidget {
  const SubscriptionPaywallSheet({
    required this.subscriptionService,
    super.key,
  });

  final SubscriptionService subscriptionService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionPaywallCubit(
        subscriptionService: subscriptionService,
      )..load(),
      child: const _SubscriptionPaywallSheetView(),
    );
  }
}

class _SubscriptionPaywallSheetView extends StatelessWidget {
  const _SubscriptionPaywallSheetView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SubscriptionPaywallCubit, SubscriptionPaywallState>(
      listener: (context, state) {
        if (state.status == SubscriptionPaywallStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isPurchasing =
            state.status == SubscriptionPaywallStatus.purchasing;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BottomSheetHeader(
                  title: 'Readflex Premium',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Icon(AppIcons.premium, size: 64),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Unlock Premium Features',
                  style: context.text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                const _FeatureItem(
                  icon: AppIcons.translate,
                  text: 'AI-powered translations with context',
                ),
                const _FeatureItem(
                  icon: AppIcons.sparkles,
                  text: 'AI-generated flashcards',
                ),
                const _FeatureItem(
                  icon: AppIcons.cloudSync,
                  text: 'Cloud sync across devices',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state.status == SubscriptionPaywallStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Purchase failed. Please try again.',
                      style: TextStyle(
                        color: context.colors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed: isPurchasing
                      ? null
                      : () =>
                            context.read<SubscriptionPaywallCubit>().purchase(),
                  child: isPurchasing
                      ? const ButtonLoadingIndicator()
                      : const Text('Subscribe'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
