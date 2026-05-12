import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'reader_appearance_cubit.dart';

const double _sizeButtonSize = 36;
const double _previewCardHeight = 152;
const double _textSizeButtonWidth = 64;
const double _textSizeButtonHeight = 44;
const double _textScaleEpsilon = 0.001;

Future<void> showReaderAppearanceSheet(BuildContext context) {
  final cubit = context.read<ReaderAppearanceCubit>();
  return showAppBottomSheet<void>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _ReaderAppearanceSheet(),
    ),
  );
}

class _ReaderAppearanceSheet extends StatelessWidget {
  const _ReaderAppearanceSheet();

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Text & layout',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OverrideStatus(),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(label: 'FONT'),
          const SizedBox(height: AppSpacing.sm),
          const _FontRow(),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(label: 'THEME'),
          const SizedBox(height: AppSpacing.sm),
          const _ThemeRow(),
          const SizedBox(height: AppSpacing.lg),
          const _SizeSection(),
          const SizedBox(height: AppSpacing.lg),
          const _LineSpacingSection(),
          const SizedBox(height: AppSpacing.lg),
          const _MarginSection(),
          const SizedBox(height: AppSpacing.lg),
          const _FontPreview(),
        ],
      ),
    );
  }
}

class _OverrideStatus extends StatelessWidget {
  const _OverrideStatus();

  @override
  Widget build(BuildContext context) {
    final hasOverride = context.select<ReaderAppearanceCubit, bool>(
      (c) => c.state.hasOverride,
    );
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ReaderAppearanceCubit>();
    return Row(
      children: [
        Expanded(
          child: Text(
            hasOverride
                ? 'Custom settings for this source'
                : 'Using global reader settings',
            style: text.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: hasOverride ? cubit.reset : null,
          icon: const Icon(AppIcons.refresh, size: AppIconSize.sm),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow();

  @override
  Widget build(BuildContext context) {
    final fontId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.fontId,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final preset in ReaderFontPreset.values)
          _ChoiceButton(
            label: preset.label,
            active: preset.id == fontId,
            onTap: () => cubit.setFont(preset.id),
          ),
      ],
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final themeId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.themeId,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final preset in ReaderThemePreset.values)
          _ChoiceButton(
            label: preset.label,
            active: preset.id == themeId,
            onTap: () => cubit.setTheme(preset.id),
          ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? cs.onSurface : cs.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          style: text.bodyMedium.copyWith(
            color: active ? cs.surface : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SizeSection extends StatelessWidget {
  const _SizeSection();

  @override
  Widget build(BuildContext context) {
    final textScale = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.textScale,
    );
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ReaderAppearanceCubit>();
    final canDecrease =
        textScale > ReaderAppearanceCubit.minTextScale + _textScaleEpsilon;
    final canIncrease =
        textScale < ReaderAppearanceCubit.maxTextScale - _textScaleEpsilon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(label: 'SIZE'),
            const Spacer(),
            Text(
              '${(textScale * 100).round()}%',
              style: text.labelSmall.copyWith(
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _TextSizeButton(
              label: 'A-',
              enabled: canDecrease,
              onTap: canDecrease
                  ? () {
                      final value =
                          textScale - ReaderAppearanceCubit.textScaleStep;
                      cubit.previewTextScale(value);
                      cubit.commitTextScale(value);
                    }
                  : null,
            ),
            Expanded(
              child: Container(
                height: _textSizeButtonHeight,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '${(textScale * 100).round()}%',
                  style: text.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _TextSizeButton(
              label: 'A+',
              enabled: canIncrease,
              large: true,
              onTap: canIncrease
                  ? () {
                      final value =
                          textScale + ReaderAppearanceCubit.textScaleStep;
                      cubit.previewTextScale(value);
                      cubit.commitTextScale(value);
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _TextSizeButton extends StatelessWidget {
  const _TextSizeButton({
    required this.label,
    required this.enabled,
    this.large = false,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _textSizeButtonWidth,
        height: _textSizeButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: enabled ? 0.5 : 0.25),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          style: text.labelLarge.copyWith(
            fontSize: large ? 18 : 14,
            color: cs.onSurface.withValues(alpha: enabled ? 1 : 0.35),
          ),
        ),
      ),
    );
  }
}

class _LineSpacingSection extends StatelessWidget {
  const _LineSpacingSection();

  @override
  Widget build(BuildContext context) {
    final lineHeight = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.lineHeight,
    );
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ReaderAppearanceCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(label: 'LINE SPACING'),
            const Spacer(),
            Text(
              lineHeight.toStringAsFixed(1),
              style: text.labelSmall.copyWith(
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final value in ReaderAppearanceCubit.lineHeightPresets)
              _LineHeightButton(
                value: value,
                active:
                    (lineHeight - value).abs() <
                    ReaderAppearanceCubit.lineHeightMatchTolerance,
                isLast: value == ReaderAppearanceCubit.lineHeightPresets.last,
                onTap: () {
                  cubit.previewLineHeight(value);
                  cubit.commitLineHeight(value);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LineHeightButton extends StatelessWidget {
  const _LineHeightButton({
    required this.value,
    required this.active,
    required this.isLast,
    required this.onTap,
  });

  final double value;
  final bool active;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: active
                  ? cs.onSurface
                  : cs.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Text(
              value.toStringAsFixed(1),
              style: text.labelSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: active
                    ? cs.surface
                    : cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarginSection extends StatelessWidget {
  const _MarginSection();

  @override
  Widget build(BuildContext context) {
    final sideMargin = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.sideMargin,
    );
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ReaderAppearanceCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(label: 'MARGINS'),
            const Spacer(),
            Text(
              '${sideMargin.round()}%',
              style: text.labelSmall.copyWith(
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _SizeButton(
              icon: AppIcons.remove,
              onTap: () {
                final value = sideMargin - ReaderAppearanceCubit.sideMarginStep;
                cubit.previewSideMargin(value);
                cubit.commitSideMargin(value);
              },
            ),
            Expanded(
              child: Slider(
                value: sideMargin,
                min: ReaderAppearanceCubit.minSideMargin,
                max: ReaderAppearanceCubit.maxSideMargin,
                divisions:
                    (ReaderAppearanceCubit.maxSideMargin -
                            ReaderAppearanceCubit.minSideMargin)
                        .round(),
                onChanged: cubit.previewSideMargin,
                onChangeEnd: cubit.commitSideMargin,
              ),
            ),
            _SizeButton(
              icon: AppIcons.add,
              onTap: () {
                final value = sideMargin + ReaderAppearanceCubit.sideMarginStep;
                cubit.previewSideMargin(value);
                cubit.commitSideMargin(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FontPreview extends StatelessWidget {
  const _FontPreview();

  @override
  Widget build(BuildContext context) {
    final appearance = context
        .select<ReaderAppearanceCubit, ReaderAppearancePreferences>(
          (c) => c.state.effectiveAppearance,
        );
    final cs = context.colors;
    final text = context.text;
    final readerFont = ReaderFontPreset.fromId(appearance.fontId);
    return SizedBox(
      height: _previewCardHeight,
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREVIEW',
              style: text.labelSmall.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Text(
                'The happiness of your life depends upon the quality of your thoughts.',
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontFamily: readerFont.fontFamily,
                  fontSize: text.bodyMedium.fontSize! * appearance.textScale,
                  height: appearance.lineHeight,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _sizeButtonSize,
        height: _sizeButtonSize,
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: AppIconSize.sm, color: cs.onSurface),
      ),
    );
  }
}
