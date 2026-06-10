import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'reader_appearance_cubit.dart';

const double _sizeButtonSize = 36;
const double _compactControlHeight = AppSizes.buttonHeight;
const double _themeSwatchSize = 44;
const double _textScaleEpsilon = 0.001;

Future<void> showReaderAppearanceSheet(
  BuildContext context, {
  VoidCallback? onFullyHidden,
}) {
  final cubit = context.read<ReaderAppearanceCubit>();
  return showAppBottomSheet<void>(
    context,
    onFullyHidden: onFullyHidden,
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
      title: 'Aa',
      headerTrailing: const _ResetAppearanceButton(),
      headerSpacing: AppSpacing.md,
      child: const SingleChildScrollView(
        child: _LayeredAppearanceControls(),
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
    return TextButton(
      onPressed: canReset ? context.read<ReaderAppearanceCubit>().reset : null,
      child: const Text('Reset'),
    );
  }
}

class _LayeredAppearanceControls extends StatelessWidget {
  const _LayeredAppearanceControls();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ThemeSwatchLevel(),
        _AppearanceLevelDivider(),
        _FontAndSizeLevel(),
        _AppearanceLevelDivider(),
        _LineHeightAndTurningLevel(),
        _AppearanceLevelDivider(),
        _PanelHeader(title: 'MARGINS', trailing: _SideMarginValue()),
        SizedBox(height: AppSpacing.sm),
        _MarginControl(),
        _AppearanceLevelDivider(),
        _PanelHeader(title: 'ALIGNMENT'),
        SizedBox(height: AppSpacing.sm),
        _AlignmentControl(),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label: title),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
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
    return _AppearanceLevel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final preset in ReaderThemePreset.values)
            _ThemeSwatchButton(
              preset: preset,
              active: preset.id == themeId,
              onTap: () => cubit.setTheme(preset.id),
            ),
        ],
      ),
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
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _themeSwatchSize,
                height: _themeSwatchSize,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? cs.primary : context.appColors.divider,
                    width: active ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.primaryTextColor,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 8, height: 8),
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
      ),
    );
  }
}

class _FontAndSizeLevel extends StatelessWidget {
  const _FontAndSizeLevel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _FontCycleControl()),
        SizedBox(width: AppSpacing.md),
        _VerticalAppearanceDivider(),
        SizedBox(width: AppSpacing.md),
        Expanded(child: _CompactSizeControl()),
      ],
    );
  }
}

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
          Text(
            preset.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge.copyWith(
              fontFamily: preset.fontFamily,
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
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

class _CompactSizeControl extends StatelessWidget {
  const _CompactSizeControl();

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(width: AppSpacing.lg),
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

class _LineHeightAndTurningLevel extends StatelessWidget {
  const _LineHeightAndTurningLevel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(title: 'LINE HEIGHT'),
              SizedBox(height: AppSpacing.sm),
              _LineSpacingControl(),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.md),
        _VerticalAppearanceDivider(),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(title: 'TURNING'),
              SizedBox(height: AppSpacing.sm),
              _PageTurnControl(),
            ],
          ),
        ),
      ],
    );
  }
}

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

class _AppearanceLevelDivider extends StatelessWidget {
  const _AppearanceLevelDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: AppSpacing.md,
      thickness: 1,
      color: context.appColors.divider.withValues(alpha: 0.45),
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
        color: context.appColors.divider.withValues(alpha: 0.45),
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
    return Row(
      children: [
        Expanded(
          child: _ChoiceButton(
            label: 'Start',
            active: alignment == ReaderTextAlignment.start,
            onTap: () => cubit.setTextAlignment(ReaderTextAlignment.start),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ChoiceButton(
            label: 'End',
            active: alignment == ReaderTextAlignment.end,
            onTap: () => cubit.setTextAlignment(ReaderTextAlignment.end),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ChoiceButton(
            label: 'Justify',
            active: alignment == ReaderTextAlignment.justify,
            onTap: () => cubit.setTextAlignment(ReaderTextAlignment.justify),
          ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconChoiceButton(
          icon: AppIcons.pageTurnHorizontal,
          label: 'Horizontal',
          active: style == ReaderPageTurnStyle.horizontal,
          onTap: () => cubit.setPageTurnStyle(ReaderPageTurnStyle.horizontal),
        ),
        const SizedBox(width: AppSpacing.lg),
        _IconChoiceButton(
          icon: AppIcons.pageTurnVertical,
          label: 'Vertical',
          active: style == ReaderPageTurnStyle.vertical,
          onTap: () => cubit.setPageTurnStyle(ReaderPageTurnStyle.vertical),
        ),
      ],
    );
  }
}

class _IconChoiceButton extends StatelessWidget {
  const _IconChoiceButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: active
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.56),
          overlayColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        icon: Icon(icon, size: AppIconSize.md),
      ),
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
    final divider = context.appColors.divider;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _compactControlHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? cs.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? cs.onSurface : divider,
          ),
        ),
        child: Text(
          label,
          style: text.bodyMedium.copyWith(
            color: active ? cs.surface : cs.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
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
    return Row(
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
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            key: ValueKey('reader-line-height-${value.toStringAsFixed(1)}'),
            height: _compactControlHeight,
            child: Center(
              child: Text(
                value.toStringAsFixed(1),
                style: text.titleMedium.copyWith(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMarginValue extends StatelessWidget {
  const _SideMarginValue();

  @override
  Widget build(BuildContext context) {
    final sideMargin = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.sideMargin,
    );
    final cs = context.colors;
    final text = context.text;
    return Text(
      sideMargin.round().toString(),
      style: text.labelSmall.copyWith(
        fontWeight: FontWeight.w400,
        color: cs.onSurface.withValues(alpha: 0.55),
      ),
    );
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
    return Row(
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
    final divider = context.appColors.divider;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _sizeButtonSize,
        height: _sizeButtonSize,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: divider),
        ),
        child: Icon(icon, size: AppIconSize.sm, color: cs.onSurface),
      ),
    );
  }
}
