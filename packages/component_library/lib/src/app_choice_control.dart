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
    this.labelStyle,
    this.labelKey,
  });

  final T value;
  final String label;
  final IconData? icon;
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
    super.key,
  });

  final T selected;
  final List<AppChoiceOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(options.isNotEmpty);
      assert(!iconOnly || options.every((option) => option.icon != null));
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
                (option.icon == null ? 0 : AppIconSize.sm + AppSpacing.sm),
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
                  icon: option.icon == null
                      ? null
                      : SizedBox(
                          width: AppIconSize.sm,
                          height: AppSizes.buttonHeight - AppSpacing.sm * 2,
                          child: Icon(option.icon, size: AppIconSize.sm),
                        ),
                  tooltip: iconOnly ? option.label : null,
                ),
            ],
            selected: {selected},
            onSelectionChanged: onChanged == null
                ? null
                : (values) => onChanged!(values.single),
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
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final option in options)
            SizedBox(
              width: width,
              child: Semantics(
                selected: selected == option.value,
                inMutuallyExclusiveGroup: true,
                child: OutlinedButton(
                  onPressed: onChanged == null
                      ? null
                      : () => onChanged!(option.value),
                  style:
                      (Theme.of(context).segmentedButtonTheme.style ??
                              const ButtonStyle())
                          .copyWith(
                            foregroundColor: WidgetStatePropertyAll(
                              onChanged == null
                                  ? context.colors.onSurface.withValues(
                                      alpha: .38,
                                    )
                                  : selected == option.value
                                  ? context.actionForeground
                                  : context.colors.onSurfaceVariant,
                            ),
                            backgroundColor: WidgetStatePropertyAll(
                              selected == option.value
                                  ? context.colors.primary.withValues(
                                      alpha: .08,
                                    )
                                  : context.colors.surface,
                            ),
                          ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (option.icon != null) ...[
                        Icon(option.icon, size: AppIconSize.sm),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(child: label(option)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
