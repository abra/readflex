import 'package:flutter/material.dart';

import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Compact preview of currently selected text.
class SelectionPreviewCard extends StatelessWidget {
  const SelectionPreviewCard({
    required this.text,
    this.backgroundColor,
    this.maxLines = 3,
    super.key,
  });

  final String text;
  final Color? backgroundColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
