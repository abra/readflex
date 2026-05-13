import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reader_appearance_cubit.dart';

const double _sizeButtonSize = 36;
const double _tabButtonHeight = 40;
const double _tabTrackPadding = 4;
const double _tabContentHeight = 204;
const double _themeCardHeight = 76;
const double _textSizeButtonWidth = 64;
const double _textSizeButtonHeight = 44;
const double _textScaleEpsilon = 0.001;
const Duration _tabIndicatorDuration = Duration(milliseconds: 180);

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TabbedAppearanceControls(),
          ],
        ),
      ),
    );
  }
}

enum _AppearanceTab {
  font('Font'),
  layout('Layout'),
  theme('Theme')
  ;

  const _AppearanceTab(this.label);

  final String label;
}

class _ResetAppearanceButton extends StatelessWidget {
  const _ResetAppearanceButton();

  @override
  Widget build(BuildContext context) {
    final hasOverride = context.select<ReaderAppearanceCubit, bool>(
      (c) => c.state.hasOverride,
    );
    return TextButton(
      onPressed: hasOverride
          ? context.read<ReaderAppearanceCubit>().reset
          : null,
      child: const Text('Reset'),
    );
  }
}

class _TabbedAppearanceControls extends StatefulWidget {
  const _TabbedAppearanceControls();

  @override
  State<_TabbedAppearanceControls> createState() =>
      _TabbedAppearanceControlsState();
}

class _TabbedAppearanceControlsState extends State<_TabbedAppearanceControls> {
  _AppearanceTab _selectedTab = _AppearanceTab.font;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AppearanceTabBar(
          selectedTab: _selectedTab,
          onSelected: (tab) {
            if (tab == _selectedTab) return;
            setState(() => _selectedTab = tab);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: _tabContentHeight,
          child: switch (_selectedTab) {
            _AppearanceTab.font => const _FontPanel(),
            _AppearanceTab.layout => const _LayoutPanel(),
            _AppearanceTab.theme => const _ThemePanel(),
          },
        ),
      ],
    );
  }
}

class _AppearanceTabBar extends StatelessWidget {
  const _AppearanceTabBar({
    required this.selectedTab,
    required this.onSelected,
  });

  final _AppearanceTab selectedTab;
  final ValueChanged<_AppearanceTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      height: _tabButtonHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabs = _AppearanceTab.values;
          final tabWidth =
              (constraints.maxWidth - (_tabTrackPadding * 2)) / tabs.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: _tabIndicatorDuration,
                curve: Curves.easeOutCubic,
                left: _tabTrackPadding + (tabWidth * selectedTab.index),
                top: _tabTrackPadding,
                bottom: _tabTrackPadding,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(_tabTrackPadding),
                child: Row(
                  children: [
                    for (final tab in tabs)
                      Expanded(
                        child: _AppearanceTabButton(
                          label: tab.label,
                          selected: tab == selectedTab,
                          onTap: () => onSelected(tab),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppearanceTabButton extends StatelessWidget {
  const _AppearanceTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _tabButtonHeight - (_tabTrackPadding * 2),
          alignment: Alignment.center,
          child: Text(
            label,
            style: text.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.56),
            ),
          ),
        ),
      ),
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

class _FontPanel extends StatelessWidget {
  const _FontPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(title: 'TYPEFACE'),
        SizedBox(height: AppSpacing.sm),
        _FontRow(),
        SizedBox(height: AppSpacing.md),
        _PanelHeader(title: 'SIZE'),
        SizedBox(height: AppSpacing.sm),
        _SizeControl(),
      ],
    );
  }
}

class _LayoutPanel extends StatelessWidget {
  const _LayoutPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: 'SPACING',
          trailing: _LineHeightValue(),
        ),
        SizedBox(height: AppSpacing.sm),
        _LineSpacingControl(),
        SizedBox(height: AppSpacing.md),
        _PanelHeader(
          title: 'MARGINS',
          trailing: _SideMarginValue(),
        ),
        SizedBox(height: AppSpacing.sm),
        _MarginControl(),
      ],
    );
  }
}

class _ThemePanel extends StatelessWidget {
  const _ThemePanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(title: 'READING THEME'),
        SizedBox(height: AppSpacing.sm),
        _ThemeRow(),
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
    return _ControlGrid(
      children: [
        for (final preset in ReaderFontPreset.values)
          _ChoiceButton(
            label: preset.label,
            fontFamily: preset.fontFamily,
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
    return _ControlGrid(
      children: [
        for (final preset in ReaderThemePreset.values)
          _ThemeChoiceButton(
            preset: preset,
            active: preset.id == themeId,
            onTap: () => cubit.setTheme(preset.id),
          ),
      ],
    );
  }
}

class _ControlGrid extends StatelessWidget {
  const _ControlGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: children[i + 1]),
            ],
          ),
          if (i + 2 < children.length) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.fontFamily,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final divider = context.appColors.divider;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _textSizeButtonHeight,
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
            fontFamily: fontFamily,
            color: active ? cs.surface : cs.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceButton extends StatelessWidget {
  const _ThemeChoiceButton({
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
    final divider = context.appColors.divider;
    final text = context.text;
    final theme = preset.data;
    return Semantics(
      button: true,
      selected: active,
      label: preset.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _themeCardHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: active ? cs.primary : divider,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            preset.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.primaryTextColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeControl extends StatelessWidget {
  const _SizeControl();

  @override
  Widget build(BuildContext context) {
    final textScale = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.textScale,
    );
    final globalTextScale = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.globalAppearance.textScale,
    );
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ReaderAppearanceCubit>();
    final canDecrease =
        textScale > ReaderAppearanceCubit.minTextScale + _textScaleEpsilon;
    final canIncrease =
        textScale < ReaderAppearanceCubit.maxTextScale - _textScaleEpsilon;
    final canReset = (textScale - globalTextScale).abs() > _textScaleEpsilon;
    return Row(
      children: [
        _TextSizeButton(
          label: 'A-',
          enabled: canDecrease,
          onTap: canDecrease
              ? () {
                  final value = textScale - ReaderAppearanceCubit.textScaleStep;
                  cubit.previewTextScale(value);
                  cubit.commitTextScale(value);
                }
              : null,
        ),
        Expanded(
          child: Semantics(
            button: true,
            enabled: canReset,
            label: 'Reset text size',
            child: GestureDetector(
              onTap: canReset ? cubit.resetTextScale : null,
              behavior: HitTestBehavior.opaque,
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
          ),
        ),
        _TextSizeButton(
          label: 'A+',
          enabled: canIncrease,
          large: true,
          onTap: canIncrease
              ? () {
                  final value = textScale + ReaderAppearanceCubit.textScaleStep;
                  cubit.previewTextScale(value);
                  cubit.commitTextScale(value);
                }
              : null,
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
    final divider = context.appColors.divider;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _textSizeButtonWidth,
        height: _textSizeButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: enabled ? divider : divider.withValues(alpha: 0.45),
          ),
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

class _LineHeightValue extends StatelessWidget {
  const _LineHeightValue();

  @override
  Widget build(BuildContext context) {
    final lineHeight = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.lineHeight,
    );
    final cs = context.colors;
    final text = context.text;
    return Text(
      lineHeight.toStringAsFixed(1),
      style: text.labelSmall.copyWith(
        fontWeight: FontWeight.w400,
        color: cs.onSurface.withValues(alpha: 0.55),
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
    final divider = context.appColors.divider;
    final text = context.text;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: active ? cs.onSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: active ? cs.onSurface : divider,
              ),
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
