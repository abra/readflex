import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Compact preview of currently selected text.
///
/// [textDirection] is the direction of the quoted content, detected by the
/// caller from the text itself; it must not follow the app locale, so an
/// Arabic quote stays right-aligned in an English UI and vice versa.
class SelectionPreviewCard extends StatelessWidget {
  const SelectionPreviewCard({
    required this.text,
    this.textDirection,
    this.backgroundColor,
    this.maxLines = 3,
    super.key,
  });

  final String text;
  final TextDirection? textDirection;
  final Color? backgroundColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
