import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';

import 'reader_highlight_expand_button.dart';
import 'reader_drawer_layout.dart';

/// Last row of a saved highlight: its location at the start and, when the
/// text is clipped, Read more / Show less at the end of the same row.
///
/// Leading/trailing follow the app locale. The row pads only the location;
/// the button's platform padding is its ink bleed. Native bottom panels
/// inset that target by another 12dp to align its label with their 24dp gutter.
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
    final contentInset = readerDrawerContentInset(context);
    final appRtl = Directionality.of(context) == TextDirection.rtl;
    final label = location == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(
              start: contentInset,
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
    final expandButton = ReaderHighlightExpandButton(
      expanded: expanded,
      onPressed: onExpanded,
    );
    final button = contentInset == AppSpacing.lg
        ? expandButton
        : Padding(
            padding: EdgeInsetsDirectional.only(
              end: contentInset - AppSpacing.md,
            ),
            child: expandButton,
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
