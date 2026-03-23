import 'package:flutter/material.dart';

import 'theme/app_radius.dart';
import 'theme/spacing.dart';

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
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
