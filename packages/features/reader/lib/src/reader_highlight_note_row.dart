import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'reader_text_line_height.dart';

/// Width a note's leading mark and its gap take from the note text.
const readerHighlightNoteIndent = AppIconSize.xs + AppSpacing.sm;

/// A highlight's note on its own row: a small pencil mark centred on the
/// first line, then `bodySmall` text. Mark and text follow the note's own
/// [textDirection] as one block, independently of the book and the UI.
class ReaderHighlightNoteRow extends StatelessWidget {
  const ReaderHighlightNoteRow({
    required this.note,
    required this.textDirection,
    required this.maxLines,
    this.muted = false,
    super.key,
  });

  final String note;
  final TextDirection textDirection;
  final int? maxLines;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.bodySmall.copyWith(
      color: muted ? colors.onSurfaceVariant : null,
    );
    return Row(
      textDirection: textDirection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppIconSize.xs,
          height: readerTextLineHeight(MediaQuery.textScalerOf(context), style),
          child: Center(
            child: Icon(
              AppIcons.edit,
              size: AppIconSize.xs,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            note,
            style: style,
            textDirection: textDirection,
            textAlign: TextAlign.start,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
