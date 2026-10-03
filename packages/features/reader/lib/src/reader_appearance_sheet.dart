import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_appearance_cubit.dart';

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
    return ActionBottomSheetLayout.scrollable(
      title: context.l10n.readerAppearanceTitle,
      headerTrailing: const _ResetAppearanceButton(),
      closeLabel: context.l10n.commonClose,
      onClose: () => Navigator.of(context).pop(),
      child: _LayeredAppearanceControls(
        showPageTurnControls: showPageTurnControls,
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
    if (MediaQuery.textScalerOf(context).scale(15) > 20) {
      return AppPlainIconButton(
        icon: AppIcons.refresh,
        tooltip: context.l10n.readerReset,
        onPressed: canReset
            ? context.read<ReaderAppearanceCubit>().reset
            : null,
      );
    }
    return TextButton.icon(
      onPressed: canReset ? context.read<ReaderAppearanceCubit>().reset : null,
      icon: const Icon(AppIcons.refresh, size: AppIconSize.sm),
      label: AppButtonLabel(context.l10n.readerReset),
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
        AppSettingsSection(
          title: context.l10n.readerTheme,
          child: const _ThemeSwatchLevel(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: context.l10n.readerFont,
          child: const _FontPresetControl(),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ReaderLayoutSettingsPanel(
          showPageTurnControls: showPageTurnControls,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.localeOf(context),
        );
        var minimumWidth = AppSizes.buttonHeight;
        for (final preset in ReaderThemePreset.values) {
          painter.text = TextSpan(
            text: _themePresetLabel(context, preset),
            style: context.text.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          );
          painter.layout();
          if (painter.width > minimumWidth) minimumWidth = painter.width;
        }
        painter.dispose();
        final count = ReaderThemePreset.values.length;
        final columns =
            minimumWidth * count + AppSpacing.xs * (count - 1) <=
                constraints.maxWidth
            ? count
            : 2;
        final width =
            (constraints.maxWidth - AppSpacing.xs * (columns - 1)) / columns;
        return Wrap(
          key: const ValueKey('reader-theme-presets'),
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in ReaderThemePreset.values)
              SizedBox(
                width: width,
                child: _ThemeSwatchButton(
                  preset: preset,
                  active: preset == activePreset,
                  onTap: () => cubit.setTheme(preset.id),
                ),
              ),
          ],
        );
      },
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
    final label = _themePresetLabel(context, preset);
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height:
                  (MediaQuery.textScalerOf(context).scale(15) * 1.28 +
                          AppSpacing.sm)
                      .clamp(_themeSwatchHeight, double.infinity),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: active
                      ? context.actionForeground
                      : context.appColors.divider,
                  width: active ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Aa',
                style: text.titleSmall.copyWith(
                  color: theme.primaryTextColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: text.labelSmall.copyWith(
                color: active
                    ? context.actionForeground
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

String _themePresetLabel(BuildContext context, ReaderThemePreset preset) {
  final l10n = context.l10n;
  return switch (preset) {
    ReaderThemePreset.snow => l10n.readerThemeSnow,
    ReaderThemePreset.paper => l10n.readerThemePaper,
    ReaderThemePreset.warm => l10n.readerThemeWarm,
    ReaderThemePreset.mist => l10n.readerThemeMist,
    ReaderThemePreset.night => l10n.readerThemeNight,
  };
}

class _FontPresetControl extends StatelessWidget {
  const _FontPresetControl();

  @override
  Widget build(BuildContext context) {
    final fontId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.fontId,
    );
    return AppChoiceControl<ReaderFontPreset>(
      key: const ValueKey('reader-font-presets'),
      selected: ReaderFontPreset.fromId(fontId),
      onChanged: (preset) =>
          context.read<ReaderAppearanceCubit>().setFont(preset.id),
      options: [
        for (final preset in ReaderFontPreset.values)
          AppChoiceOption(
            value: preset,
            label: preset.label,
            labelKey: ValueKey('reader-font-${preset.id}'),
            labelStyle: TextStyle(
              fontSize: context.text.labelMedium.fontSize,
              fontWeight: FontWeight.w600,
              fontFamily: preset.fontFamily,
              letterSpacing: 0,
            ),
          ),
      ],
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
      valueTooltip: context.l10n.readerResetTextSize,
      valueSemanticLabel: context.l10n.readerTextSize,
      highlightValue: stepperState.highlighted,
      decreaseIcon: AppIcons.remove,
      increaseIcon: AppIcons.add,
      decreaseTooltip: context.l10n.readerDecreaseTextSize,
      increaseTooltip: context.l10n.readerIncreaseTextSize,
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

class _ReaderLayoutSettingsPanel extends StatelessWidget {
  const _ReaderLayoutSettingsPanel({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AppearanceSettingRow(
          label: context.l10n.readerFontSize,
          control: const _FontSizeControl(),
        ),
        const SizedBox(height: AppSpacing.xs),
        _AppearanceSettingRow(
          label: context.l10n.readerLineSpacing,
          control: const _LineSpacingControl(),
        ),
        const SizedBox(height: AppSpacing.xs),
        _AppearanceSettingRow(
          label: context.l10n.readerTextAlignment,
          control: const _AlignmentControl(),
        ),
        const SizedBox(height: AppSpacing.xs),
        _AppearanceSettingRow(
          label: context.l10n.readerPageMargins,
          control: const _MarginControl(),
        ),
        if (showPageTurnControls) ...[
          const SizedBox(height: AppSpacing.xs),
          _AppearanceSettingRow(
            label: context.l10n.readerPageTurn,
            control: const _PageTurnControl(),
          ),
        ],
      ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 360 &&
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final title = Text(
          label,
          maxLines: stacked ? null : 2,
          overflow: TextOverflow.visible,
          style: context.text.bodyMedium,
        );
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.buttonHeight,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: control,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: AppSpacing.md),
                    control,
                  ],
                ),
        );
      },
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
    return SizedBox(
      width: _marginsControlWidth,
      child: AppChoiceControl<ReaderTextAlignment>(
        iconOnly: true,
        selected: alignment,
        onChanged: (value) => cubit.setTextAlignment(value),
        options: [
          AppChoiceOption(
            value: ReaderTextAlignment.start,
            icon: AppIcons.alignStart,
            label: context.l10n.readerAlignStart,
          ),
          AppChoiceOption(
            value: ReaderTextAlignment.justify,
            icon: AppIcons.alignJustify,
            label: context.l10n.readerJustifyText,
          ),
          AppChoiceOption(
            value: ReaderTextAlignment.end,
            icon: AppIcons.alignEnd,
            label: context.l10n.readerAlignEnd,
          ),
        ],
      ),
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
    return SizedBox(
      width: _pageTurnControlWidth,
      child: AppChoiceControl<ReaderPageTurnStyle>(
        iconOnly: true,
        selected: style,
        onChanged: (value) => cubit.setPageTurnStyle(value),
        options: [
          AppChoiceOption(
            value: ReaderPageTurnStyle.horizontal,
            icon: AppIcons.pageTurnHorizontal,
            label: context.l10n.readerHorizontalPageTurn,
          ),
          AppChoiceOption(
            value: ReaderPageTurnStyle.vertical,
            icon: AppIcons.pageTurnVertical,
            label: context.l10n.readerVerticalPageTurn,
          ),
        ],
      ),
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
      valueTooltip: context.l10n.readerResetLineSpacing,
      valueSemanticLabel: context.l10n.readerLineSpacing,
      highlightValue: stepperState.highlighted,
      decreaseIcon: AppIcons.remove,
      increaseIcon: AppIcons.add,
      decreaseTooltip: context.l10n.readerDecreaseLineSpacing,
      increaseTooltip: context.l10n.readerIncreaseLineSpacing,
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
      valueTooltip: context.l10n.readerResetPageMargins,
      valueSemanticLabel: context.l10n.readerPageMargins,
      highlightValue: stepperState.highlighted,
      decreaseIcon: AppIcons.remove,
      increaseIcon: AppIcons.add,
      decreaseTooltip: context.l10n.readerDecreasePageMargins,
      increaseTooltip: context.l10n.readerIncreasePageMargins,
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
      width:
          AppSizes.buttonHeight * 2 +
          (width - AppSizes.buttonHeight * 2) *
              (MediaQuery.textScalerOf(context).scale(15) / 15).clamp(
                1,
                double.infinity,
              ),
      height: AppSizes.buttonHeight,
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: context.colors.outlineVariant),
        ),
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
    final foreground = enabled
        ? cs.onSurfaceVariant
        : cs.onSurface.withValues(alpha: .38);
    final radius = BorderRadius.circular(AppRadius.sm);
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
            width: AppSizes.buttonHeight,
            height: AppSizes.buttonHeight,
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
    final radius = BorderRadius.circular(AppRadius.sm);
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
            height: AppSizes.buttonHeight,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge.copyWith(
                  color: highlighted ? context.actionForeground : cs.onSurface,
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
