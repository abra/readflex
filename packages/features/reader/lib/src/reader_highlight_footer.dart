import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'reader_highlight_expand_button.dart';

/// Last row of a saved highlight: its location at the start and, when the
/// text is clipped, Read more / Show less at the end of the same row.
///
/// Leading/trailing follow the app locale. The row pads only the location;
/// the button's themed 16dp padding is its ink bleed, so its label ends on
/// the trailing gutter while the 48dp target reaches the drawer edge.
class ReaderHighlightFooter extends StatelessWidget {
  const ReaderHighlightFooter({
    required this.location,
    required this.canExpand,
    required this.expanded,
    required this.onExpanded,
    this.locationDirection,
    this.endGutter = AppSpacing.lg,
    this.maxButtonWidth = double.infinity,
    super.key,
  });

  final String? location;

  /// Base direction of the location text (a book chapter title keeps the
  /// book's); its alignment stays on the app's leading edge.
  final TextDirection? locationDirection;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onExpanded;

  /// Trailing inset of the location when no button follows it.
  final double endGutter;

  /// Bounds the button beside a location so a long or enlarged label wraps
  /// inside it instead of overflowing the row.
  final double maxButtonWidth;

  @override
  Widget build(BuildContext context) {
    final location = this.location;
    final appRtl = Directionality.of(context) == TextDirection.rtl;
    final label = location == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: canExpand ? 0 : endGutter,
            ),
            child: Text(
              location,
              style: context.text.bodySmall.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textDirection: locationDirection,
              textAlign: appRtl ? TextAlign.right : TextAlign.left,
            ),
          );
    if (!canExpand) return label ?? const SizedBox.shrink();
    final button = ReaderHighlightExpandButton(
      expanded: expanded,
      onPressed: onExpanded,
    );
    if (label == null) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: button);
    }
    return Row(
      children: [
        Expanded(child: label),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxButtonWidth),
          child: button,
        ),
      ],
    );
  }
}
