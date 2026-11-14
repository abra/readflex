import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'reader_control_styles.dart';

const readerChromeActionStripHeight = 60.0;

@immutable
class ReaderChromeActionData {
  const ReaderChromeActionData({
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.icon,
    this.glyph,
    this.iconSize = AppIconSize.md,
  }) : assert((icon == null) != (glyph == null));

  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? glyph;
  final double iconSize;
}

class ReaderChromeActionButton extends StatelessWidget {
  const ReaderChromeActionButton({
    super.key,
    required this.action,
    required this.showLabel,
    this.glyphHeight,
    this.captionHeight,
    this.captionBaseline,
  });

  final ReaderChromeActionData action;
  final bool showLabel;
  final double? glyphHeight;
  final double? captionHeight;
  final double? captionBaseline;

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Center(
        child: AppPlainIconButton(
          icon: action.icon,
          iconWidget: action.glyph,
          iconSize: action.iconSize,
          tooltip: action.tooltip,
          color: action.color,
          onPressed: action.onPressed,
        ),
      );
    }
    final caption = Text(
      action.label,
      maxLines: captionHeight == null ? 2 : 1,
      softWrap: captionHeight == null,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: readerControlCaptionStyle(context).copyWith(
        color: action.onPressed == null
            ? action.color.withValues(alpha: 0.38)
            : action.color,
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: AppTooltip(
        message: action.tooltip,
        child: AppButton.text(
          onPressed: action.onPressed,

          foregroundColor: action.color,
          disabledForegroundColor: action.color.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),

          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  key: glyphHeight == null
                      ? null
                      : ValueKey('readerChromeActionGlyph-${action.tooltip}'),
                  height: glyphHeight,
                  child: Center(
                    child:
                        action.glyph ??
                        Icon(action.icon, size: action.iconSize),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  key: captionHeight == null
                      ? null
                      : ValueKey('readerChromeActionCaption-${action.tooltip}'),
                  height: captionHeight,
                  child: captionBaseline == null
                      ? caption
                      : Baseline(
                          baseline: captionBaseline!,
                          baselineType: TextBaseline.alphabetic,
                          child: caption,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
