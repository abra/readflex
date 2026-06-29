import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'reader_appearance_cubit.dart';

const double _stepButtonSize = 40;
const double _compactControlHeight = AppSizes.iconButtonSize;
const double _compactControlSurfaceHeight = _compactControlHeight + 6;
const double _segmentedControlPadding = 3;
const double _marginsControlWidth = 152;
const double _pageTurnControlWidth = 116;
const double _textSizeControlWidth = 192;
const double _fontLabelHeight = 29;
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
        const _FontAndSizeLevel(),
        const SizedBox(height: AppSpacing.sm),
        _LineSpacingAndPageTurnLevel(
          showPageTurnControls: showPageTurnControls,
        ),
        const SizedBox(height: AppSpacing.md),
        const _AlignmentAndMarginsLevel(),
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
    return Row(
      children: [
        for (var i = 0; i < ReaderThemePreset.values.length; i++) ...[
          Expanded(
            child: _ThemeSwatchButton(
              preset: ReaderThemePreset.values[i],
              active: ReaderThemePreset.values[i].id == themeId,
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

/// Combined font picker and text-size controls in one horizontal level.
class _FontAndSizeLevel extends StatelessWidget {
  const _FontAndSizeLevel();

  @override
  Widget build(BuildContext context) {
    return const _AppearancePanel(
      child: Row(
        children: [
          Expanded(child: _FontCycleControl()),
          SizedBox(width: AppSpacing.md),
          _VerticalAppearanceDivider(),
          SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _textSizeControlWidth,
            child: _CompactSizeControl(),
          ),
        ],
      ),
    );
  }
}

/// Tap-to-cycle font selector with dot indicators for available presets.
class _FontCycleControl extends StatelessWidget {
  const _FontCycleControl();

  @override
  Widget build(BuildContext context) {
    final fontId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.fontId,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    final preset = ReaderFontPreset.fromId(fontId);
    final index = ReaderFontPreset.values.indexOf(preset);
    final cs = context.colors;
    final text = context.text;
    return _AppearanceLevel(
      onTap: () {
        final next = ReaderFontPreset
            .values[(index + 1) % ReaderFontPreset.values.length];
        cubit.setFont(next.id);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: _fontLabelHeight,
            width: double.infinity,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  preset.label,
                  key: const ValueKey('reader-font-label'),
                  maxLines: 1,
                  style: text.titleLarge.copyWith(
                    fontFamily: preset.fontFamily,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            key: const ValueKey('reader-font-page-dots'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < ReaderFontPreset.values.length; i++)
                _PageDot(active: i == index),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Compact A-/A+ text-size control used inside the reader appearance sheet.
class _CompactSizeControl extends StatelessWidget {
  const _CompactSizeControl();

  @override
  Widget build(BuildContext context) {
    final textScale = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.textScale,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return _AppearanceLevel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CompactTextSizeButton(
            label: 'A-',
            large: false,
            onTap: _textScaleChange(
              context,
              -ReaderAppearanceCubit.textScaleStep,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _TextScaleValueButton(
            textScale: textScale,
            onTap: cubit.resetTextScale,
          ),
          const SizedBox(width: AppSpacing.sm),
          _CompactTextSizeButton(
            label: 'A+',
            large: true,
            onTap: _textScaleChange(
              context,
              ReaderAppearanceCubit.textScaleStep,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextScaleValueButton extends StatelessWidget {
  const _TextScaleValueButton({required this.textScale, required this.onTap});

  final double textScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${(textScale * 100).round()}%';
    return Tooltip(
      message: 'Reset text size',
      child: Semantics(
        button: true,
        label: 'Reset text size',
        value: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 48,
            height: _compactControlHeight,
            child: Center(
              child: Text(
                label,
                style: context.text.labelLarge.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
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

class _CompactTextSizeButton extends StatelessWidget {
  const _CompactTextSizeButton({
    required this.label,
    required this.large,
    required this.onTap,
  });

  final String label;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: _compactControlHeight,
        child: Center(
          child: Text(
            label,
            style: context.text
                .readerTextSizeControl(large: large)
                .copyWith(
                  fontSize: large ? 24 : 20,
                  color: cs.onSurface.withValues(
                    alpha: onTap == null ? 0.35 : 1,
                  ),
                ),
          ),
        ),
      ),
    );
  }
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

/// Shared tappable row container for compact appearance controls.
class _AppearanceLevel extends StatelessWidget {
  const _AppearanceLevel({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _compactControlHeight),
        child: child,
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _VerticalAppearanceDivider extends StatelessWidget {
  const _VerticalAppearanceDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _compactControlHeight + 20,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: context.appColors.divider.withValues(alpha: 0.24),
      ),
    );
  }
}

class _LineSpacingAndPageTurnLevel extends StatelessWidget {
  const _LineSpacingAndPageTurnLevel({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(title: 'Line spacing'),
              SizedBox(height: AppSpacing.xs),
              _LineSpacingControl(),
            ],
          ),
        ),
        if (showPageTurnControls) ...[
          const SizedBox(width: AppSpacing.md),
          const _VerticalAppearanceDivider(),
          const SizedBox(width: AppSpacing.md),
          const SizedBox(
            width: _pageTurnControlWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PanelHeader(title: 'Page turn'),
                SizedBox(height: AppSpacing.xs),
                _PageTurnControl(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AlignmentAndMarginsLevel extends StatelessWidget {
  const _AlignmentAndMarginsLevel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(title: 'Text alignment'),
              SizedBox(height: AppSpacing.xs),
              _AlignmentControl(),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.md),
        _VerticalAppearanceDivider(),
        SizedBox(width: AppSpacing.md),
        SizedBox(
          width: _marginsControlWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(title: 'Page margins'),
              SizedBox(height: AppSpacing.xs),
              _MarginControl(),
            ],
          ),
        ),
      ],
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
    return _SegmentedControl(
      children: [
        _SegmentedButton(
          icon: AppIcons.alignStart,
          label: 'Start',
          showLabel: false,
          active: alignment == ReaderTextAlignment.start,
          onTap: () => cubit.setTextAlignment(ReaderTextAlignment.start),
        ),
        _SegmentedButton(
          icon: AppIcons.alignEnd,
          label: 'End',
          showLabel: false,
          active: alignment == ReaderTextAlignment.end,
          onTap: () => cubit.setTextAlignment(ReaderTextAlignment.end),
        ),
        _SegmentedButton(
          icon: AppIcons.alignJustify,
          label: 'Justify',
          showLabel: false,
          active: alignment == ReaderTextAlignment.justify,
          onTap: () => cubit.setTextAlignment(ReaderTextAlignment.justify),
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
    return _SegmentedControl(
      children: [
        _SegmentedButton(
          icon: AppIcons.pageTurnHorizontal,
          label: 'Horizontal',
          showLabel: false,
          active: style == ReaderPageTurnStyle.horizontal,
          onTap: () => cubit.setPageTurnStyle(ReaderPageTurnStyle.horizontal),
        ),
        _SegmentedButton(
          icon: AppIcons.pageTurnVertical,
          label: 'Vertical',
          showLabel: false,
          active: style == ReaderPageTurnStyle.vertical,
          onTap: () => cubit.setPageTurnStyle(ReaderPageTurnStyle.vertical),
        ),
      ],
    );
  }
}

class _LineSpacingControl extends StatelessWidget {
  const _LineSpacingControl();

  @override
  Widget build(BuildContext context) {
    final lineHeight = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.lineHeight,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return _SegmentedControl(
      children: [
        for (final value in ReaderAppearanceCubit.lineHeightPresets)
          _SegmentedButton(
            key: ValueKey('reader-line-height-${value.toStringAsFixed(1)}'),
            label: value.toStringAsFixed(1),
            active:
                (lineHeight - value).abs() <
                ReaderAppearanceCubit.lineHeightMatchTolerance,
            onTap: () {
              cubit.previewLineHeight(value);
              cubit.commitLineHeight(value);
            },
          ),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_segmentedControlPadding),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 3),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedButton extends StatelessWidget {
  const _SegmentedButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.showLabel = true,
    super.key,
  });

  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final foreground = active
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.7);
    final selectedRadius = AppRadius.sm - _segmentedControlPadding;
    final button = Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: active ? cs.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(selectedRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(selectedRadius),
          child: SizedBox(
            height: _compactControlHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(icon, size: AppIconSize.sm, color: foreground),
                if (icon != null && showLabel) ...[
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (showLabel)
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge.copyWith(
                        color: foreground,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (showLabel) return button;
    return Tooltip(message: label, child: button);
  }
}

class _MarginControl extends StatelessWidget {
  const _MarginControl();

  @override
  Widget build(BuildContext context) {
    final sideMargin = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.sideMargin,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    final canDecrease =
        sideMargin > ReaderAppearanceCubit.minSideMargin + _textScaleEpsilon;
    final canIncrease =
        sideMargin < ReaderAppearanceCubit.maxSideMargin - _textScaleEpsilon;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StepIconButton(
          icon: AppIcons.remove,
          onTap: canDecrease
              ? () {
                  final value =
                      sideMargin - ReaderAppearanceCubit.sideMarginStep;
                  cubit.previewSideMargin(value);
                  cubit.commitSideMargin(value);
                }
              : null,
        ),
        _MarginValueBadge(
          sideMargin: sideMargin,
          onTap: cubit.resetSideMargin,
        ),
        _StepIconButton(
          icon: AppIcons.add,
          onTap: canIncrease
              ? () {
                  final value =
                      sideMargin + ReaderAppearanceCubit.sideMarginStep;
                  cubit.previewSideMargin(value);
                  cubit.commitSideMargin(value);
                }
              : null,
        ),
      ],
    );
  }
}

class _MarginValueBadge extends StatelessWidget {
  const _MarginValueBadge({required this.sideMargin, required this.onTap});

  final double sideMargin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ValueBadge(
      label: '${sideMargin.round()}%',
      tooltip: 'Reset page margins',
      onTap: onTap,
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        value: label,
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 48,
              height: _compactControlSurfaceHeight,
              child: Center(
                child: Text(
                  label,
                  style: context.text.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
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

class _StepIconButton extends StatelessWidget {
  const _StepIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final enabled = onTap != null;
    final foreground = cs.onSurface.withValues(alpha: enabled ? 0.74 : 0.28);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _stepButtonSize,
        height: _compactControlSurfaceHeight,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: AppIconSize.sm, color: foreground),
      ),
    );
  }
}
