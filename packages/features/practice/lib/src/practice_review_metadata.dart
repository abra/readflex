import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

/// Quiet source metadata with a separate, fully readable review schedule.
class PracticeReviewMetadata extends StatelessWidget {
  const PracticeReviewMetadata({
    required this.reviewLabel,
    this.sourceTitle,
    this.sourceMaxLines = 1,
    super.key,
  });

  final String reviewLabel;
  final String? sourceTitle;
  final int? sourceMaxLines;

  @override
  Widget build(BuildContext context) {
    final source = sourceTitle?.trim();
    final style = context.text.bodySmall.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xxs,
      children: [
        if (source != null && source.isNotEmpty)
          Text(
            source,
            maxLines: sourceMaxLines,
            overflow: sourceMaxLines == null ? null : TextOverflow.ellipsis,
            textDirection: Bidi.detectRtlDirectionality(source)
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: style,
          ),
        Text(reviewLabel, style: style),
      ],
    );
  }
}
