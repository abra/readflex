import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_highlight_color.dart';

class ReaderHighlightAction {
  const ReaderHighlightAction({
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool loading;
}

class ReaderHighlightControls extends StatelessWidget {
  static const tapTargetSize = 48.0;

  const ReaderHighlightControls({
    required this.selectedColor,
    required this.busy,
    required this.readerTheme,
    required this.dividerColor,
    required this.onColorChanged,
    required this.actions,
    super.key,
  });

  final HighlightColor selectedColor;
  final bool busy;
  final ReaderThemeData readerTheme;
  final Color dividerColor;
  final ValueChanged<HighlightColor> onColorChanged;
  final List<ReaderHighlightAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in HighlightColor.values)
                  _HighlightColorButton(
                    color: color,
                    readerTheme: readerTheme,
                    selected: selectedColor == color,
                    enabled: !busy,
                    onPressed: () => onColorChanged(color),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: AppSizes.chipHeight,
          child: VerticalDivider(
            color: dividerColor,
            thickness: 1,
            width: AppSpacing.sm,
          ),
        ),
        for (final action in actions)
          IconButton(
            tooltip: action.tooltip,
            onPressed: busy ? null : action.onPressed,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(
                ReaderHighlightControls.tapTargetSize,
              ),
              backgroundColor: Colors.transparent,
            ),
            icon: action.loading
                ? const ButtonLoadingIndicator(size: AppIconSize.sm)
                : Icon(
                    action.icon,
                    size: AppIconSize.sm,
                    color: action.color,
                  ),
          ),
      ],
    );
  }
}

class _HighlightColorButton extends StatelessWidget {
  const _HighlightColorButton({
    required this.color,
    required this.readerTheme,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final HighlightColor color;
  final ReaderThemeData readerTheme;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final swatch = readerHighlightColor(color, readerTheme);
    final checkColor = swatch.computeLuminance() > 0.45
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.92);
    final borderColor = context.colors.onSurface.withValues(
      alpha: selected ? 0.42 : 0.16,
    );
    return Semantics(
      label: _localizedHighlightColorName(context, color),
      button: true,
      enabled: enabled,
      selected: selected,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: SizedBox(
        width: ReaderHighlightControls.tapTargetSize,
        height: ReaderHighlightControls.tapTargetSize,
        child: Tooltip(
          message: _localizedHighlightColorName(context, color),
          excludeFromSemantics: true,
          child: InkResponse(
            radius: ReaderHighlightControls.tapTargetSize / 2,
            onTap: enabled ? onPressed : null,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                width: selected ? 24.0 : 20,
                height: selected ? 24.0 : 20,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: selected
                    ? Icon(
                        AppIcons.check,
                        size: AppIconSize.xs,
                        color: checkColor,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _localizedHighlightColorName(
  BuildContext context,
  HighlightColor color,
) {
  final l10n = context.l10n;
  return switch (color) {
    HighlightColor.yellow => l10n.highlightColorYellow,
    HighlightColor.green => l10n.highlightColorGreen,
    HighlightColor.blue => l10n.highlightColorBlue,
    HighlightColor.pink => l10n.highlightColorPink,
    HighlightColor.purple => l10n.highlightColorPurple,
  };
}
