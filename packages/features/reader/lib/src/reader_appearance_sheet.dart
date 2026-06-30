import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'reader_appearance_cubit.dart';

const double _compactControlHeight = AppSizes.iconButtonSize;
const double _compactControlSurfaceHeight = _compactControlHeight + 6;
const double _segmentedControlPadding = 3;
const double _marginsControlWidth = 152;
const double _pageTurnControlWidth = 116;
const double _textSizeControlWidth = _marginsControlWidth;
const double _themeSwatchHeight = 36;
const double _textScaleEpsilon = 0.001;

Future<void> showReaderAppearanceSheet(
  BuildContext context, {
  bool showPageTurnControls = true,
  VoidCallback? onFullyHidden,
}) {
  final cubit = context.read<ReaderAppearanceCubit>();
  return showAppBottomSheet<void>(
    context,
    onFullyHidden: onFullyHidden,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ReaderAppearanceSheet(
        showPageTurnControls: showPageTurnControls,
      ),
    ),
  );
}

/// Bottom sheet shell for per-source reader appearance overrides.
class _ReaderAppearanceSheet extends StatelessWidget {
  const _ReaderAppearanceSheet({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  Widget build(BuildContext context) {
    final maxBodyHeight = MediaQuery.sizeOf(context).height * 0.76;
    return ActionBottomSheetLayout(
      title: 'Appearance',
      headerTrailing: const _ResetAppearanceButton(),
      headerSpacing: AppSpacing.md,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxBodyHeight),
        child: SingleChildScrollView(
          child: _LayeredAppearanceControls(
            showPageTurnControls: showPageTurnControls,
          ),
        ),
      ),
    );
  }
}

class _ResetAppearanceButton extends StatelessWidget {
  const _ResetAppearanceButton();

  @override
  Widget build(BuildContext context) {
    final canReset = context.select<ReaderAppearanceCubit, bool>(
      (c) => c.state.hasOverride,
    );
    return TextButton.icon(
      onPressed: canReset ? context.read<ReaderAppearanceCubit>().reset : null,
      icon: const Icon(AppIcons.refresh, size: AppIconSize.sm),
      label: const Text('Reset'),
    );
  }
}

/// Vertical stack of compact appearance control rows.
class _LayeredAppearanceControls extends StatelessWidget {
  const _LayeredAppearanceControls({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeader(title: 'Theme'),
        const SizedBox(height: AppSpacing.xs),
        const _ThemeSwatchLevel(),
        const SizedBox(height: AppSpacing.sm),
        const _FontLevel(),
        const SizedBox(height: AppSpacing.sm),
        _ReaderLayoutSettingsPanel(
          showPageTurnControls: showPageTurnControls,
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeSwatchLevel extends StatelessWidget {
  const _ThemeSwatchLevel();

  @override
  Widget build(BuildContext context) {
    final themeId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.themeId,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    final activePreset = ReaderThemePreset.fromId(themeId);
    return Row(
      key: const ValueKey('reader-theme-presets'),
      children: [
        for (var i = 0; i < ReaderThemePreset.values.length; i++) ...[
          Expanded(
            child: _ThemeSwatchButton(
              preset: ReaderThemePreset.values[i],
              active: ReaderThemePreset.values[i] == activePreset,
              onTap: () => cubit.setTheme(ReaderThemePreset.values[i].id),
            ),
          ),
          if (i != ReaderThemePreset.values.length - 1)
            const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ThemeSwatchButton extends StatelessWidget {
  const _ThemeSwatchButton({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  final ReaderThemePreset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final theme = preset.data;
    return Semantics(
      button: true,
      selected: active,
      label: preset.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: _themeSwatchHeight,
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: active ? cs.primary : context.appColors.divider,
                  width: active ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Aa',
                style: text.titleSmall.copyWith(
                  color: theme.primaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              preset.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall.copyWith(
                color: active
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.62),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontLevel extends StatelessWidget {
  const _FontLevel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: _FontPresetControl(),
    );
  }
}

class _FontPresetControl extends StatelessWidget {
  const _FontPresetControl();

  @override
  Widget build(BuildContext context) {
    final fontId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.fontId,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    final activePreset = ReaderFontPreset.fromId(fontId);
    return Row(
      key: const ValueKey('reader-font-presets'),
      children: [
        for (var i = 0; i < ReaderFontPreset.values.length; i++) ...[
          Expanded(
            child: _FontPresetButton(
              preset: ReaderFontPreset.values[i],
              active: ReaderFontPreset.values[i] == activePreset,
              onTap: () => cubit.setFont(ReaderFontPreset.values[i].id),
            ),
          ),
          if (i != ReaderFontPreset.values.length - 1)
            const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _FontPresetButton extends StatelessWidget {
  const _FontPresetButton({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  final ReaderFontPreset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label: preset.label,
      child: Material(
        color: active
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: _compactControlSurfaceHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    preset.label,
                    key: ValueKey('reader-font-${preset.id}'),
                    maxLines: 1,
                    style: context.text.labelMedium.copyWith(
                      color: active
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.72),
                      fontFamily: preset.fontFamily,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  const _FontSizeControl();

  @override
  Widget build(BuildContext context) {
    final stepperState = context
        .select<ReaderAppearanceCubit, ({double textScale, bool highlighted})>(
          (c) => (
            textScale: c.state.effectiveAppearance.textScale,
            highlighted: c.state.sourceOverride.textScale != null,
          ),
        );
    final cubit = context.read<ReaderAppearanceCubit>();
    return _AppearanceStepper(
      width: _textSizeControlWidth,
      stepperKey: const ValueKey('reader-text-scale-control'),
      valueLabel: '${(stepperState.textScale * 100).round()}%',
      valueTooltip: 'Reset text size',
      valueSemanticLabel: 'Text size',
      highlightValue: stepperState.highlighted,
      decreaseIcon: AppIcons.remove,
      increaseIcon: AppIcons.add,
      decreaseTooltip: 'Decrease text size',
      increaseTooltip: 'Increase text size',
      decreaseKey: const ValueKey('reader-text-scale-decrease'),
      increaseKey: const ValueKey('reader-text-scale-increase'),
      valueKey: const ValueKey('reader-text-scale-value'),
      onDecrease: _textScaleChange(
        context,
        -ReaderAppearanceCubit.textScaleStep,
      ),
      onIncrease: _textScaleChange(
        context,
        ReaderAppearanceCubit.textScaleStep,
      ),
      onValueTap: cubit.resetTextScale,
    );
  }
}

VoidCallback? _textScaleChange(BuildContext context, double delta) {
  final textScale = context.select<ReaderAppearanceCubit, double>(
    (c) => c.state.effectiveAppearance.textScale,
  );
  final next = textScale + delta;
  final canChange = delta < 0
      ? textScale > ReaderAppearanceCubit.minTextScale + _textScaleEpsilon
      : textScale < ReaderAppearanceCubit.maxTextScale - _textScaleEpsilon;
  if (!canChange) return null;
  final cubit = context.read<ReaderAppearanceCubit>();
  return () {
    cubit.previewTextScale(next);
    cubit.commitTextScale(next);
  };
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: child,
    );
  }
}

class _ReaderLayoutSettingsPanel extends StatelessWidget {
  const _ReaderLayoutSettingsPanel({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  Widget build(BuildContext context) {
    return _AppearancePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AppearanceSettingRow(
            label: 'Font size',
            control: _FontSizeControl(),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _AppearanceSettingRow(
            label: 'Line spacing',
            control: _LineSpacingControl(),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _AppearanceSettingRow(
            label: 'Text alignment',
            control: _AlignmentControl(),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _AppearanceSettingRow(
            label: 'Page margins',
            control: _MarginControl(),
          ),
          if (showPageTurnControls) ...[
            const SizedBox(height: AppSpacing.xs),
            const _AppearanceSettingRow(
              label: 'Page turn',
              control: _PageTurnControl(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppearanceSettingRow extends StatelessWidget {
  const _AppearanceSettingRow({
    required this.label,
    required this.control,
  });

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _compactControlSurfaceHeight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.74),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          control,
        ],
      ),
    );
  }
}

class _AlignmentControl extends StatelessWidget {
  const _AlignmentControl();

  @override
  Widget build(BuildContext context) {
    final alignment = context
        .select<ReaderAppearanceCubit, ReaderTextAlignment>(
          (c) => c.state.effectiveAppearance.textAlignment,
        );
    final cubit = context.read<ReaderAppearanceCubit>();
    return _AppearanceIconSegmentedControl<ReaderTextAlignment>(
      width: _marginsControlWidth,
      selectedValue: alignment,
      onSelected: (value) => cubit.setTextAlignment(value),
      segments: const [
        _AppearanceIconSegment(
          value: ReaderTextAlignment.start,
          icon: AppIcons.alignStart,
          tooltip: 'Align start',
        ),
        _AppearanceIconSegment(
          value: ReaderTextAlignment.justify,
          icon: AppIcons.alignJustify,
          tooltip: 'Justify text',
        ),
        _AppearanceIconSegment(
          value: ReaderTextAlignment.end,
          icon: AppIcons.alignEnd,
          tooltip: 'Align end',
        ),
      ],
    );
  }
}

class _PageTurnControl extends StatelessWidget {
  const _PageTurnControl();

  @override
  Widget build(BuildContext context) {
    final style = context.select<ReaderAppearanceCubit, ReaderPageTurnStyle>(
      (c) => c.state.effectiveAppearance.pageTurnStyle,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return _AppearanceIconSegmentedControl<ReaderPageTurnStyle>(
      width: _pageTurnControlWidth,
      selectedValue: style,
      onSelected: (value) => cubit.setPageTurnStyle(value),
      segments: const [
        _AppearanceIconSegment(
          value: ReaderPageTurnStyle.horizontal,
          icon: AppIcons.pageTurnHorizontal,
          tooltip: 'Horizontal page turn',
        ),
        _AppearanceIconSegment(
          value: ReaderPageTurnStyle.vertical,
          icon: AppIcons.pageTurnVertical,
          tooltip: 'Vertical page turn',
        ),
      ],
    );
  }
}

class _LineSpacingControl extends StatelessWidget {
  const _LineSpacingControl();

  @override
  Widget build(BuildContext context) {
    final stepperState = context
        .select<ReaderAppearanceCubit, ({double lineHeight, bool highlighted})>(
          (c) => (
            lineHeight: c.state.effectiveAppearance.lineHeight,
            highlighted: c.state.sourceOverride.lineHeight != null,
          ),
        );
    final cubit = context.read<ReaderAppearanceCubit>();
    final lineHeight = stepperState.lineHeight;
    final decreaseValue = _lineHeightStepValue(lineHeight, -1);
    final increaseValue = _lineHeightStepValue(lineHeight, 1);
    void setLineHeight(double value) {
      cubit.previewLineHeight(value);
      cubit.commitLineHeight(value);
    }

    return _AppearanceStepper(
      width: _marginsControlWidth,
      stepperKey: const ValueKey('reader-line-height-control'),
      valueLabel: _lineHeightLabel(lineHeight),
      valueTooltip: 'Reset line spacing',
      valueSemanticLabel: 'Line spacing',
      highlightValue: stepperState.highlighted,
      decreaseIcon: AppIcons.remove,
      increaseIcon: AppIcons.add,
      decreaseTooltip: 'Decrease line spacing',
      increaseTooltip: 'Increase line spacing',
      decreaseKey: const ValueKey('reader-line-height-decrease'),
      increaseKey: const ValueKey('reader-line-height-increase'),
      valueKey: const ValueKey('reader-line-height-value'),
      onDecrease: decreaseValue == null
          ? null
          : () => setLineHeight(decreaseValue),
      onIncrease: increaseValue == null
          ? null
          : () => setLineHeight(increaseValue),
      onValueTap: cubit.resetLineHeight,
    );
  }
}

class _MarginControl extends StatelessWidget {
  const _MarginControl();

  @override
  Widget build(BuildContext context) {
    final stepperState = context
        .select<ReaderAppearanceCubit, ({double sideMargin, bool highlighted})>(
          (c) => (
            sideMargin: c.state.effectiveAppearance.sideMargin,
            highlighted: c.state.sourceOverride.sideMargin != null,
          ),
        );
    final cubit = context.read<ReaderAppearanceCubit>();
    final sideMargin = stepperState.sideMargin;
    final canDecrease =
        sideMargin > ReaderAppearanceCubit.minSideMargin + _textScaleEpsilon;
    final canIncrease =
        sideMargin < ReaderAppearanceCubit.maxSideMargin - _textScaleEpsilon;
    void setSideMargin(double value) {
      cubit.previewSideMargin(value);
      cubit.commitSideMargin(value);
    }

    return _AppearanceStepper(
      width: _marginsControlWidth,
      stepperKey: const ValueKey('reader-margin-control'),
      valueLabel: '${sideMargin.round()}%',
      valueTooltip: 'Reset page margins',
      valueSemanticLabel: 'Page margins',
      highlightValue: stepperState.highlighted,
      decreaseIcon: AppIcons.remove,
      increaseIcon: AppIcons.add,
      decreaseTooltip: 'Decrease page margins',
      increaseTooltip: 'Increase page margins',
      decreaseKey: const ValueKey('reader-margin-decrease'),
      increaseKey: const ValueKey('reader-margin-increase'),
      valueKey: const ValueKey('reader-margin-value'),
      onDecrease: canDecrease
          ? () => setSideMargin(
              sideMargin - ReaderAppearanceCubit.sideMarginStep,
            )
          : null,
      onIncrease: canIncrease
          ? () => setSideMargin(
              sideMargin + ReaderAppearanceCubit.sideMarginStep,
            )
          : null,
      onValueTap: cubit.resetSideMargin,
    );
  }
}

class _AppearanceStepper extends StatelessWidget {
  const _AppearanceStepper({
    required this.valueLabel,
    required this.valueTooltip,
    required this.valueSemanticLabel,
    required this.highlightValue,
    required this.decreaseIcon,
    required this.increaseIcon,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.onDecrease,
    required this.onIncrease,
    required this.onValueTap,
    this.width = _marginsControlWidth,
    this.stepperKey,
    this.decreaseKey,
    this.increaseKey,
    this.valueKey,
  });

  final double width;
  final String valueLabel;
  final String valueTooltip;
  final String valueSemanticLabel;
  final bool highlightValue;
  final IconData decreaseIcon;
  final IconData increaseIcon;
  final String decreaseTooltip;
  final String increaseTooltip;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onValueTap;
  final Key? stepperKey;
  final Key? decreaseKey;
  final Key? increaseKey;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final radius = BorderRadius.circular(AppRadius.sm);
    return SizedBox(
      key: stepperKey,
      width: width,
      height: _compactControlSurfaceHeight,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(_segmentedControlPadding),
          child: Row(
            children: [
              _StepperIconButton(
                key: decreaseKey,
                icon: decreaseIcon,
                tooltip: decreaseTooltip,
                onTap: onDecrease,
              ),
              Expanded(
                child: _StepperValueButton(
                  key: valueKey,
                  label: valueLabel,
                  tooltip: valueTooltip,
                  semanticLabel: valueSemanticLabel,
                  highlighted: highlightValue,
                  onTap: onValueTap,
                ),
              ),
              _StepperIconButton(
                key: increaseKey,
                icon: increaseIcon,
                tooltip: increaseTooltip,
                onTap: onIncrease,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final enabled = onTap != null;
    final foreground = cs.onSurface.withValues(alpha: enabled ? 0.76 : 0.28);
    final radius = BorderRadius.circular(
      AppRadius.sm - _segmentedControlPadding,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: _compactControlHeight,
            height: _compactControlHeight,
            child: Icon(icon, size: AppIconSize.sm, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _StepperValueButton extends StatelessWidget {
  const _StepperValueButton({
    required this.label,
    required this.tooltip,
    required this.semanticLabel,
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final String label;
  final String tooltip;
  final String semanticLabel;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final radius = BorderRadius.circular(
      AppRadius.sm - _segmentedControlPadding,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel,
        value: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: _compactControlHeight,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge.copyWith(
                  color: highlighted
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceIconSegmentedControl<T> extends StatelessWidget {
  const _AppearanceIconSegmentedControl({
    required this.width,
    required this.selectedValue,
    required this.segments,
    required this.onSelected,
  });

  final double width;
  final T selectedValue;
  final List<_AppearanceIconSegment<T>> segments;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return SizedBox(
      width: width,
      height: _compactControlSurfaceHeight,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(_segmentedControlPadding),
          child: Row(
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                Expanded(
                  child: _AppearanceIconSegmentButton<T>(
                    segment: segments[i],
                    active: segments[i].value == selectedValue,
                    onSelected: onSelected,
                  ),
                ),
                if (i != segments.length - 1) const SizedBox(width: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceIconSegmentButton<T> extends StatelessWidget {
  const _AppearanceIconSegmentButton({
    required this.segment,
    required this.active,
    required this.onSelected,
  });

  final _AppearanceIconSegment<T> segment;
  final bool active;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final foreground = active
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.68);
    final radius = BorderRadius.circular(
      AppRadius.sm - _segmentedControlPadding,
    );
    return Tooltip(
      message: segment.tooltip,
      child: Semantics(
        button: true,
        selected: active,
        label: segment.tooltip,
        child: Material(
          color: active
              ? cs.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: () => onSelected(segment.value),
            borderRadius: radius,
            child: SizedBox(
              height: _compactControlHeight,
              child: Icon(
                segment.icon,
                size: AppIconSize.sm,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceIconSegment<T> {
  const _AppearanceIconSegment({
    required this.value,
    required this.icon,
    required this.tooltip,
  });

  final T value;
  final IconData icon;
  final String tooltip;
}

double? _lineHeightStepValue(double lineHeight, int direction) {
  final nextIndex = _nearestLineHeightPresetIndex(lineHeight) + direction;
  if (nextIndex < 0 ||
      nextIndex >= ReaderAppearanceCubit.lineHeightPresets.length) {
    return null;
  }
  return ReaderAppearanceCubit.lineHeightPresets[nextIndex];
}

String _lineHeightLabel(double lineHeight) {
  final nearest =
      ReaderAppearanceCubit.lineHeightPresets[_nearestLineHeightPresetIndex(
        lineHeight,
      )];
  if ((lineHeight - nearest).abs() <
      ReaderAppearanceCubit.lineHeightMatchTolerance) {
    return nearest.toStringAsFixed(1);
  }
  return lineHeight.toStringAsFixed(2);
}

int _nearestLineHeightPresetIndex(double lineHeight) {
  final presets = ReaderAppearanceCubit.lineHeightPresets;
  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < presets.length; i++) {
    final distance = (lineHeight - presets[i]).abs();
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }
  return nearestIndex;
}
