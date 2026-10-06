import 'package:flutter/material.dart';

import 'app_button_label.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Inline status block for sheet bodies: a title, an explanatory body and an
/// optional filled command, left-aligned to the sheet's content gutter.
///
/// Definition and Translation use it for "no result", "offline" and failure
/// states that sit beneath the source phrase. [busy] appends a linear
/// progress bar for operations with a visible duration, such as an offline
/// model download. Full-panel states use `ErrorState` / `EmptyState`.
class AppStatusMessage extends StatelessWidget {
  const AppStatusMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.busy = false,
    super.key,
  }) : assert(
         actionLabel != null || onAction == null,
         'onAction requires an actionLabel.',
       );

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: text.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (busy) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: busy ? null : onAction,
            child: AppButtonLabel(actionLabel!),
          ),
        ],
      ],
    );
  }
}
