import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

class AppChoiceOption<T> {
  const AppChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.glyph,
    this.labelStyle,
    this.labelKey,
  }) : assert(
         icon == null || glyph == null,
         'glyph replaces the icon; pass one or the other.',
       );

  final T value;
  final String label;
  final IconData? icon;

  /// Decorative widget drawn in the icon box instead of [icon], for glyphs
  /// that are not font icons. It should paint with the ambient [IconTheme]
  /// color so selected and disabled states match icon segments.
  final Widget? glyph;
  final TextStyle? labelStyle;
  final Key? labelKey;
}

/// Single choice with shared selected states and accessible touch targets.
/// Labels wrap into rows when a segmented control would truncate them.
class AppChoiceControl<T> extends StatelessWidget {
  const AppChoiceControl({
    required this.selected,
    required this.options,
    required this.onChanged,
    this.iconOnly = false,
    this.reselectable = false,
    super.key,
  });

  final T selected;
  final List<AppChoiceOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool iconOnly;

  /// Reports a tap on the selected option too, for controls that select the
  /// nearest option to a value they cannot represent exactly: tapping it
  /// then applies that option's own value.
  final bool reselectable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(options.isNotEmpty);
      assert(
        !iconOnly || options.every((option) => option.hasIcon),
        'iconOnly options need an icon or a glyph.',
      );
      final style = context.text.bodyMedium.copyWith(letterSpacing: 0);
      var widest = AppSizes.buttonHeight;
      if (!iconOnly) {
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );
        for (final option in options) {
          painter.text = TextSpan(
            text: option.label,
            style: style.merge(option.labelStyle),
          );
          painter.layout();
          widest = math.max(
            widest,
            painter.width +
                AppSpacing.md * 2 +
                (option.hasIcon ? AppIconSize.sm + AppSpacing.sm : 0),
          );
        }
        painter.dispose();
      }

      Widget label(AppChoiceOption<T> option) => Text(
        option.label,
        key: option.labelKey,
        style: option.labelStyle,
      );

      if (widest * options.length <= constraints.maxWidth) {
        // SegmentedButton reserves a separate tap-target strip by default.
        // The outer constraint supplies the full 48dp surface and hit target.
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
          child: SegmentedButton<T>(
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final option in options)
                ButtonSegment(
                  value: option.value,
                  label: iconOnly
                      ? null
                      : ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight:
                                AppSizes.buttonHeight - AppSpacing.sm * 2,
                          ),
                          child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: label(option),
                          ),
                        ),
                  icon: option.hasIcon
                      ? SizedBox(
                          width: AppIconSize.sm,
                          height: AppSizes.buttonHeight - AppSpacing.sm * 2,
                          child: _AppChoiceIcon(option: option),
                        )
                      : null,
                  tooltip: iconOnly ? option.label : null,
                ),
            ],
            selected: {selected},
            // An empty set is a tap on the selected segment.
            emptySelectionAllowed: reselectable,
            onSelectionChanged: onChanged == null
                ? null
                : (values) =>
                      onChanged!(values.isEmpty ? selected : values.single),
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
          ),
        );
      }

      final columns =
          options.length.isEven &&
              widest * 2 + AppSpacing.sm <= constraints.maxWidth
          ? 2
          : 1;
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      final choiceStyle =
          Theme.of(context).segmentedButtonTheme.style ?? const ButtonStyle();
      ButtonStyle optionStyle(T value) {
        final states = <WidgetState>{
          if (selected == value) WidgetState.selected,
          if (onChanged == null) WidgetState.disabled,
        };
        return choiceStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(
            choiceStyle.foregroundColor?.resolve(states),
          ),
          backgroundColor: WidgetStatePropertyAll(
            choiceStyle.backgroundColor?.resolve(states),
          ),
        );
      }

      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final option in options)
            SizedBox(
              width: width,
              // Keep selection on the named button node, as SegmentedButton does.
              child: MergeSemantics(
                child: Semantics(
                  selected: selected == option.value,
                  inMutuallyExclusiveGroup: true,
                  child: OutlinedButton(
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged!(option.value),
                    style: optionStyle(option.value),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (option.hasIcon) ...[
                          SizedBox.square(
                            dimension: AppIconSize.sm,
                            child: _AppChoiceIcon(option: option),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(child: label(option)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

extension on AppChoiceOption<Object?> {
  bool get hasIcon => icon != null || glyph != null;
}

/// The option's font icon or glyph, centered in the icon box.
class _AppChoiceIcon extends StatelessWidget {
  const _AppChoiceIcon({required this.option});

  final AppChoiceOption<Object?> option;

  @override
  Widget build(BuildContext context) =>
      Center(child: option.glyph ?? Icon(option.icon, size: AppIconSize.sm));
}
