import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:material_ui/material_ui.dart';

import 'app_button.dart';
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
    this.proportionalWidth = false,
    super.key,
  });

  final T selected;
  final List<AppChoiceOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool iconOnly;

  /// Lets Cupertino segments share space according to their label widths.
  /// Labels that still do not fit use the usual wrapping choices.
  final bool proportionalWidth;

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
      final useProportionalWidth =
          context.isCupertino && proportionalWidth && !iconOnly;
      var widest = AppSizes.buttonHeight;
      var totalWidth = 0.0;
      if (!iconOnly) {
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );
        for (final option in options) {
          final labelStyle = style.merge(option.labelStyle);
          painter.text = TextSpan(
            text: option.label,
            style:
                useProportionalWidth &&
                    (labelStyle.fontWeight ?? FontWeight.w400).value <
                        FontWeight.w600.value
                ? labelStyle.copyWith(fontWeight: FontWeight.w600)
                : labelStyle,
          );
          painter.layout();
          final contentWidth =
              painter.width +
              (option.hasIcon ? AppIconSize.sm + AppSpacing.sm : 0);
          final width = useProportionalWidth
              ? math.max(AppSizes.buttonHeight, contentWidth) +
                    AppSpacing.md * 2
              : math.max(
                  AppSizes.buttonHeight,
                  contentWidth + AppSpacing.md * 2,
                );
          widest = math.max(widest, width);
          totalWidth += width;
        }
        painter.dispose();
      }

      final requiredWidth = useProportionalWidth
          ? totalWidth
          : widest * options.length;
      if (requiredWidth <= constraints.maxWidth &&
          (!context.isCupertino || options.length > 1)) {
        if (context.isCupertino) {
          final selectedIndex = options.indexWhere(
            (option) => option.value == selected,
          );
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
            child: IgnorePointer(
              ignoring: onChanged == null,
              child: cupertino.CupertinoSlidingSegmentedControl<int>(
                proportionalWidth: useProportionalWidth,
                groupValue: selectedIndex < 0 ? null : selectedIndex,
                disabledChildren: onChanged == null
                    ? {for (var i = 0; i < options.length; i++) i}
                    : const {},
                onValueChanged: (index) {
                  if (index != null && onChanged != null) {
                    onChanged!(options[index].value);
                  }
                },
                children: {
                  for (var i = 0; i < options.length; i++)
                    i: Semantics(
                      enabled: onChanged != null,
                      child: GestureDetector(
                        onTap:
                            reselectable &&
                                onChanged != null &&
                                selected == options[i].value
                            ? () => onChanged!(options[i].value)
                            : null,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: AppSizes.buttonHeight,
                            minWidth: useProportionalWidth
                                ? AppSizes.buttonHeight
                                : 0,
                          ),
                          child: Center(
                            child: DefaultTextStyle.merge(
                              style: style.copyWith(
                                fontWeight: selected == options[i].value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              child: _AppCupertinoChoiceContent(
                                option: options[i],
                                iconOnly: iconOnly,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                },
              ),
            ),
          );
        }
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
                            child: _AppChoiceLabel(option: option),
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
      if (context.isCupertino) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              SizedBox(
                width: width,
                child: MergeSemantics(
                  child: Semantics(
                    selected: selected == option.value,
                    inMutuallyExclusiveGroup: true,
                    child: AppButton.tonal(
                      onPressed: onChanged == null
                          ? null
                          : () => onChanged!(option.value),
                      backgroundColor: selected == option.value
                          ? context.colors.selectedControlBackground
                          : cupertino.CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                      foregroundColor: selected == option.value
                          ? context.actionForeground
                          : context.colors.onSurface,
                      child: _AppCupertinoChoiceContent(
                        option: option,
                        iconOnly: iconOnly,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
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
                        Flexible(child: _AppChoiceLabel(option: option)),
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

class _AppCupertinoChoiceContent extends StatelessWidget {
  const _AppCupertinoChoiceContent({
    required this.option,
    required this.iconOnly,
  });

  final AppChoiceOption<Object?> option;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (option.hasIcon) ...[
          SizedBox.square(
            dimension: AppIconSize.sm,
            child: _AppChoiceIcon(option: option),
          ),
          if (!iconOnly) const SizedBox(width: AppSpacing.sm),
        ],
        if (!iconOnly) Flexible(child: _AppChoiceLabel(option: option)),
      ],
    );
    return iconOnly
        ? Semantics(label: option.label, excludeSemantics: true, child: content)
        : content;
  }
}

extension on AppChoiceOption<Object?> {
  bool get hasIcon => icon != null || glyph != null;
}

/// The option's label in its own style, e.g. a font preview's typeface.
class _AppChoiceLabel extends StatelessWidget {
  const _AppChoiceLabel({required this.option});

  final AppChoiceOption<Object?> option;

  @override
  Widget build(BuildContext context) =>
      Text(option.label, key: option.labelKey, style: option.labelStyle);
}

/// The option's font icon or glyph, centered in the icon box.
class _AppChoiceIcon extends StatelessWidget {
  const _AppChoiceIcon({required this.option});

  final AppChoiceOption<Object?> option;

  @override
  Widget build(BuildContext context) =>
      Center(child: option.glyph ?? Icon(option.icon, size: AppIconSize.sm));
}
