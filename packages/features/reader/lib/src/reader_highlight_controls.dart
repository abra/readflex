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
                  ReaderHighlightColorButton(
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
            width: AppSpacing.sm,
          ),
        ),
        for (final action in actions)
          if (action.loading)
            AppPlainIconButton(
              tooltip: action.tooltip,
              onPressed: null,
              color: action.color,
              iconWidget: const ButtonLoadingIndicator(size: AppIconSize.sm),
            )
          else
            AppPlainIconButton(
              tooltip: action.tooltip,
              onPressed: busy ? null : action.onPressed,
              color: action.color,
              icon: action.icon,
            ),
      ],
    );
  }
}

/// Shared swatch semantics and hit target for selection tools and filters.
class ReaderHighlightColorButton extends StatelessWidget {
  const ReaderHighlightColorButton({
    required this.color,
    required this.readerTheme,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final HighlightColor color;
  final ReaderThemeData readerTheme;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final name = _localizedHighlightColorName(context, color);
    return AppColorSwatchButton(
      color: readerHighlightColor(color, readerTheme),
      selected: selected,
      tooltip: name,
      size: AppIconSize.md,
      onPressed: enabled ? onPressed : null,
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
