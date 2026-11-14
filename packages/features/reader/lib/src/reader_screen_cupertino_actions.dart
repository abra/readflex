import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'reader_chrome_action_button.dart';

/// Gives native captions their natural widths without splitting words.
class ReaderCupertinoChromeActions extends StatelessWidget {
  const ReaderCupertinoChromeActions({
    super.key,
    required this.actions,
    required this.labelStyle,
    required this.showLabels,
  });

  final List<ReaderChromeActionData> actions;
  final TextStyle labelStyle;
  final bool showLabels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final widths = <double>[];
      var captionBaseline = 0.0;
      var captionDescent = 0.0;
      var requiredWidth = 0.0;
      final glyphHeight = actions.fold(
        0.0,
        (height, action) => math.max(height, action.iconSize),
      );
      if (showLabels) {
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        );
        for (final action in actions) {
          painter.text = TextSpan(text: action.label, style: labelStyle);
          painter.layout();
          // Four insets: the button's outer and inner padding on each side.
          final width = math.max(
            AppSizes.buttonHeight + AppSpacing.xs * 2,
            painter.width.ceilToDouble() + AppSpacing.xs * 4,
          );
          widths.add(width);
          requiredWidth += width;
          final baseline = painter.computeDistanceToActualBaseline(
            TextBaseline.alphabetic,
          );
          captionBaseline = math.max(captionBaseline, baseline);
          captionDescent = math.max(
            captionDescent,
            painter.height - baseline,
          );
        }
        painter.dispose();
      }
      final captionHeight = (captionBaseline + captionDescent).ceilToDouble();
      final captionsFit = showLabels && requiredWidth <= constraints.maxWidth;
      final extraWidth = captionsFit
          ? (constraints.maxWidth - requiredWidth) / actions.length
          : 0.0;
      final height = captionsFit
          ? math.max(
              AppSizes.buttonHeight + AppSpacing.xl + AppSpacing.sm,
              glyphHeight + AppSpacing.xs + captionHeight + AppSpacing.xs * 2,
            )
          : readerChromeActionStripHeight;
      return SizedBox(
        key: const ValueKey('readerChromeCapsule'),
        height: height,
        child: Row(
          children: [
            for (final (index, action) in actions.indexed)
              if (captionsFit)
                SizedBox(
                  width: widths[index] + extraWidth,
                  height: height,
                  child: ReaderChromeActionButton(
                    action: action,
                    showLabel: true,
                    glyphHeight: glyphHeight,
                    captionHeight: captionHeight,
                    captionBaseline: captionBaseline,
                  ),
                )
              else
                Expanded(
                  child: ReaderChromeActionButton(
                    action: action,
                    showLabel: false,
                  ),
                ),
          ],
        ),
      );
    },
  );
}
