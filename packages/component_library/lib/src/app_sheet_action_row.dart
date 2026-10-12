import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

part 'sheet_action_row_layout.dart';
part 'sheet_action_row_slot.dart';

/// Full-width sheet row: text with a utility action, such as Copy, whose
/// glyph shares the header's content edge. The 48dp target extends into the
/// gutter, not outside the row.
///
/// The action is centered on the first line of [child], whose style is
/// [firstLineStyle], and always fits in the row.
///
/// [lead] is optional content above [child], such as its caption and source
/// expression, [leadSpacing] above it. The lead spans both content edges in
/// either direction and keeps the ambient direction: a caption in the
/// interface language stays on the interface's start edge. The action moves
/// down to [child] instead of pushing [child] down.
///
/// [minTextRoom] is the least room above the row's first line of text and
/// below its last; room the 48dp target takes beyond its line counts toward
/// it. With at least half the target's excess over the line, gaps around the
/// row do not change when the text wraps, nor at large text sizes, where a
/// line is taller than the target.
///
/// [textDirection] lets the action follow [child] rather than the app
/// locale: an LTR answer in an RTL interface keeps its copy action trailing
/// the text it copies instead of leading it.
class AppSheetActionRow extends StatelessWidget {
  const AppSheetActionRow({
    required this.child,
    required this.action,
    required this.firstLineStyle,
    this.lead,
    this.leadSpacing = AppSpacing.xs,
    this.minTextRoom = 0,
    this.textDirection,
    super.key,
  });

  final Widget child;
  final Widget action;
  final TextStyle firstLineStyle;
  final Widget? lead;
  final double leadSpacing;
  final double minTextRoom;
  final TextDirection? textDirection;

  /// The width [child] gets in a row [rowWidth] wide with a 48dp action, for
  /// measuring its text before building it.
  static double childWidthFor(double rowWidth) =>
      rowWidth -
      AppSpacing.xl -
      (AppSpacing.xl - AppSizes.iconActionOutset) -
      AppSizes.buttonHeight;

  @override
  Widget build(BuildContext context) {
    final ambient = Directionality.of(context);
    final lead = this.lead;
    final row = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.xl,
        end: AppSpacing.xl - AppSizes.iconActionOutset,
      ),
      child: _SheetActionRowLayout(
        lead: lead == null
            ? null
            : Directionality(textDirection: ambient, child: lead),
        body: child,
        action: action,
        firstLineHeight: _lineHeight(context),
        leadSpacing: leadSpacing,
        leadEndInset: AppSizes.iconActionOutset,
        minTextRoom: minTextRoom,
      ),
    );
    final direction = textDirection;
    if (direction == null) return row;
    return Directionality(textDirection: direction, child: row);
  }

  // A role with a line height spans exactly that multiple of its font size;
  // without one, the font's own metrics decide.
  double _lineHeight(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(firstLineStyle);
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = style.fontSize;
    final height = style.height;
    if (fontSize != null && height != null) {
      return scaler.scale(fontSize) * height;
    }
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
    final lineHeight = painter.preferredLineHeight;
    painter.dispose();
    return lineHeight;
  }
}
