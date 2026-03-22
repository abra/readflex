import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

import 'paywall_cubit.dart';

void showPaywallSheet(
  BuildContext context, {
  required SubscriptionService subscriptionService,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PaywallSheet(
      subscriptionService: subscriptionService,
    ),
  );
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet({required this.subscriptionService});

  final SubscriptionService subscriptionService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PaywallCubit(subscriptionService: subscriptionService)..load(),
      child: const _PaywallSheetView(),
    );
  }
}

class _PaywallSheetView extends StatelessWidget {
  const _PaywallSheetView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaywallCubit, PaywallState>(
      listener: (context, state) {
        if (state.status == PaywallStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isPurchasing = state.status == PaywallStatus.purchasing;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BottomSheetHeader(
                  title: 'Readflex Premium',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: Spacing.large),
                const Icon(Icons.workspace_premium, size: 64),
                const SizedBox(height: Spacing.medium),
                Text(
                  'Unlock Premium Features',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.medium),
                const _FeatureItem(
                  icon: Icons.translate,
                  text: 'AI-powered translations with context',
                ),
                const _FeatureItem(
                  icon: Icons.auto_awesome,
                  text: 'AI-generated flashcards',
                ),
                const _FeatureItem(
                  icon: Icons.cloud_sync,
                  text: 'Cloud sync across devices',
                ),
                const SizedBox(height: Spacing.large),
                if (state.status == PaywallStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.small),
                    child: Text(
                      'Purchase failed. Please try again.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed: isPurchasing
                      ? null
                      : () => context.read<PaywallCubit>().purchase(),
                  child: isPurchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Subscribe'),
                ),
                const SizedBox(height: Spacing.small),
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
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Spacing.small),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
