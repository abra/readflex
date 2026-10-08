import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_appearance_cubit.dart';
import 'reader_font_sheet.dart';
import 'reader_layout_presets.dart';
import 'reader_line_spacing_glyph.dart';
import 'reader_margins_glyph.dart';

const double _compactControlWidth = 152;
const double _themeSwatchHeight = 36;
const double _textScaleEpsilon = 0.001;
const double _smallTextSizeGlyph = 14;
const double _largeTextSizeGlyph = 22;

/// The theme swatches keep a 4dp ink inset around their samples. The body
/// gutter is reduced by that inset so the sample borders land on 24dp, and
/// every other section adds it back. This is the only place that owns it.
const double _swatchInkInset = AppSpacing.xs;
const EdgeInsets _appearanceBodyPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl - _swatchInkInset,
  0,
  AppSpacing.xl - _swatchInkInset,
  AppSpacing.lg,
);
const EdgeInsets _sectionGutterInset = EdgeInsets.symmetric(
  horizontal: _swatchInkInset,
);

Future<void> showReaderAppearanceSheet(
  BuildContext context, {
  bool showPageTurnControls = true,
  VoidCallback? onFullyHidden,
}) {
  final cubit = context.read<ReaderAppearanceCubit>();
  return showAppBottomSheet<void>(
    context,
    scrimClosesFlow: true,
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
class _ReaderAppearanceSheet extends StatefulWidget {
  const _ReaderAppearanceSheet({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  State<_ReaderAppearanceSheet> createState() => _ReaderAppearanceSheetState();
}

class _ReaderAppearanceSheetState extends State<_ReaderAppearanceSheet>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  )..addStatusListener(_onTransitionStatus);
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  late final _appearanceOffset = Tween(
    begin: Offset.zero,
    end: const Offset(-1, 0),
  ).animate(_curve);
  late final _fontOffset = Tween(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(_curve);
  var _fontVisible = false;
  var _transitionDirection = TextDirection.ltr;

  void _onTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      setState(() {});
    }
  }

  void _showFont(bool visible) {
    if (_fontVisible == visible) return;
    setState(() {
      _fontVisible = visible;
      _transitionDirection = Directionality.of(context);
    });
    final target = visible ? 1.0 : 0.0;
    if (context.reduceMotion) {
      _controller.value = target;
    } else {
      _controller.animateTo(target);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _step({
    required bool active,
    required Animation<Offset> position,
    required Widget child,
    bool maintainSize = false,
  }) {
    final content = TickerMode(
      enabled: active,
      child: ExcludeSemantics(
        excluding: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: SlideTransition(
              position: position,
              textDirection: _transitionDirection,
              child: child,
            ),
          ),
        ),
      ),
    );
    final visible = active || _controller.isAnimating;
    return maintainSize
        ? Visibility(
            visible: visible,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: content,
          )
        : Offstage(offstage: !visible, child: content);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_fontVisible,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _showFont(false);
    },
    child: ClipRect(
      child: Stack(
        children: [
          // Appearance alone sizes the flow; font samples cannot enlarge it.
          _step(
            active: !_fontVisible,
            position: _appearanceOffset,
            maintainSize: true,
            child: _AppearanceSettings(
              showPageTurnControls: widget.showPageTurnControls,
              onFont: () => _showFont(true),
            ),
          ),
          Positioned.fill(
            child: _step(
              active: _fontVisible,
              position: _fontOffset,
              child: ReaderFontSheet(
                onBack: () => _showFont(false),
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({
    required this.showPageTurnControls,
    required this.onFont,
  });

  final bool showPageTurnControls;
  final VoidCallback onFont;

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout.scrollable(
      title: context.l10n.readerAppearanceTitle,
      headerTrailing: const _ResetAppearanceButton(),
      closeLabel: context.l10n.commonClose,
      onClose: () => Navigator.of(context).pop(),
      bodyPadding: _appearanceBodyPadding,
      child: _LayeredAppearanceControls(
        showPageTurnControls: showPageTurnControls,
        onFont: onFont,
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
  const _LayeredAppearanceControls({
    required this.showPageTurnControls,
    required this.onFont,
  });

  final bool showPageTurnControls;
  final VoidCallback onFont;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ThemeSection(),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: _sectionGutterInset,
          child: _FontPickerRow(onPressed: onFont),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: _sectionGutterInset,
          child: _ReaderLayoutSettingsPanel(
            showPageTurnControls: showPageTurnControls,
          ),
        ),
      ],
    );
  }
}

/// Theme label on the 24dp gutter; the swatch grid bleeds its ink inset past
/// it, so only the title takes the gutter inset.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    return AppSettingsSection(
      title: context.l10n.readerTheme,
      titlePadding: _sectionGutterInset,
      child: const _ThemeSwatchLevel(),
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
    final radius = BorderRadius.circular(AppRadius.sm);
    // The sample keeps the preset's own page colors; the selected fill and
    // label color are the shared selected-control pair.
    return Semantics(
      key: ValueKey('reader-theme-swatch-${preset.id}'),
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: active ? cs.selectedControlBackground : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
            child: Padding(
              padding: const EdgeInsets.all(_swatchInkInset),
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
                      borderRadius: radius,
                      border: Border.all(
                        color: active
                            ? context.actionForeground
                            : context.appColors.divider,
                        width: active ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.readerAppearanceSample,
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
                          ? cs.selectedControlForeground
                          : cs.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _FontPickerRow extends StatelessWidget {
  const _FontPickerRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fontId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.fontId,
    );
    final preset = ReaderFontPreset.fromId(fontId);
    // Same drill-in row as Display's Language; the value previews the face.
    return AppDrillInRow(
      key: const ValueKey('reader-font-picker'),
      title: context.l10n.readerFont,
      value: preset.label,
      valueStyle: TextStyle(
        fontFamily: preset.fontFamily,
        fontWeight: FontWeight.w600,
      ),
      onTap: onPressed,
    );
  }
}

/// Text size, line spacing and margins share one width. It grows with text
/// scale so the percentage keeps its room and the three stay aligned.
double _compactControlWidthFor(BuildContext context) =>
    AppSizes.buttonHeight * 2 +
    (_compactControlWidth - AppSizes.buttonHeight * 2) *
        (MediaQuery.textScalerOf(context).scale(15) / 15).clamp(
          1,
          double.infinity,
        );

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
    final cs = context.colors;
    return SizedBox(
      key: const ValueKey('reader-text-scale-control'),
      width: _compactControlWidthFor(context),
      height: AppSizes.buttonHeight,
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            _TextSizeStepButton(
              key: const ValueKey('reader-text-scale-decrease'),
              glyphSize: _smallTextSizeGlyph,
              tooltip: context.l10n.readerDecreaseTextSize,
              onTap: _textScaleChange(
                context,
                -ReaderAppearanceCubit.textScaleStep,
              ),
            ),
            Expanded(
              child: _TextSizeValueButton(
                key: const ValueKey('reader-text-scale-value'),
                label: '${(stepperState.textScale * 100).round()}%',
                highlighted: stepperState.highlighted,
                onTap: cubit.resetTextScale,
              ),
            ),
            _TextSizeStepButton(
              key: const ValueKey('reader-text-scale-increase'),
              glyphSize: _largeTextSizeGlyph,
              tooltip: context.l10n.readerIncreaseTextSize,
              onTap: _textScaleChange(
                context,
                ReaderAppearanceCubit.textScaleStep,
              ),
            ),
          ],
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

/// Small or large serif "A" of the text size stepper. The letter is a glyph,
/// not copy: the localized tooltip names the action.
class _TextSizeStepButton extends StatelessWidget {
  const _TextSizeStepButton({
    required this.glyphSize,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final double glyphSize;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox.square(
            dimension: AppSizes.buttonHeight,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  'A',
                  // Follows text scale until the large "A" fills its target.
                  textScaler: MediaQuery.textScalerOf(context).clamp(
                    maxScaleFactor: AppSizes.buttonHeight / _largeTextSizeGlyph,
                  ),
                  style: context.text.labelLarge.copyWith(
                    fontFamily: ReaderFontPreset.serif.fontFamily,
                    fontSize: glyphSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: 0,
                    color: enabled
                        ? cs.onSurfaceVariant
                        : cs.onSurface.withValues(alpha: .38),
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

class _TextSizeValueButton extends StatelessWidget {
  const _TextSizeValueButton({
    required this.label,
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.readerResetTextSize,
      child: Semantics(
        button: true,
        label: context.l10n.readerTextSize,
        value: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: AppSizes.buttonHeight,
            child: Center(
              // Announced once, as the node's value.
              child: ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // A muted caption; the accent marks a per-source override.
                  style: context.text.bodySmall.copyWith(
                    color: highlighted
                        ? context.actionForeground
                        : context.colors.onSurfaceVariant,
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
          controlBelowLabel: true,
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
            controlBelowLabel: true,
            control: const _PageTurnControl(),
          ),
        ],
      ],
    );
  }
}

/// A setting label with its control. Compact controls trail the label and
/// move below it only for large text in a narrow sheet. Labeled choices
/// ([controlBelowLabel]) always span the width below their label, so long
/// translations wrap inside the choice instead of crowding the label.
class _AppearanceSettingRow extends StatelessWidget {
  const _AppearanceSettingRow({
    required this.label,
    required this.control,
    this.controlBelowLabel = false,
  });

  final String label;
  final Widget control;
  final bool controlBelowLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            controlBelowLabel ||
            constraints.maxWidth < 360 &&
                MediaQuery.textScalerOf(context).scale(14) > 18;
        final title = Text(
          label,
          maxLines: stacked ? null : 2,
          overflow: TextOverflow.visible,
          style: context.text.bodyMedium,
        );
        if (stacked) {
          // With the 4dp row gap the label sits 16dp below the previous
          // control and 8dp above its own.
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: AppSpacing.sm),
                if (controlBelowLabel)
                  control
                else
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: control,
                  ),
              ],
            ),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.buttonHeight,
          ),
          child: Row(
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
    return AppChoiceControl<ReaderTextAlignment>(
      key: const ValueKey('reader-text-alignment-control'),
      selected: alignment,
      onChanged: (value) => cubit.setTextAlignment(value),
      options: [
        AppChoiceOption(
          value: ReaderTextAlignment.start,
          icon: AppIcons.alignStart,
          label: context.l10n.readerAlignNormal,
        ),
        AppChoiceOption(
          value: ReaderTextAlignment.justify,
          icon: AppIcons.alignJustify,
          label: context.l10n.readerAlignJustified,
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
    return AppChoiceControl<ReaderPageTurnStyle>(
      key: const ValueKey('reader-page-turn-control'),
      selected: style,
      onChanged: (value) => cubit.setPageTurnStyle(value),
      options: [
        AppChoiceOption(
          value: ReaderPageTurnStyle.horizontal,
          icon: AppIcons.pageTurnHorizontal,
          label: context.l10n.readerPageTurnHorizontalShort,
        ),
        AppChoiceOption(
          value: ReaderPageTurnStyle.vertical,
          icon: AppIcons.pageTurnVertical,
          label: context.l10n.readerPageTurnVerticalShort,
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
    final l10n = context.l10n;
    return SizedBox(
      key: const ValueKey('reader-line-height-control'),
      width: _compactControlWidthFor(context),
      child: AppChoiceControl<ReaderLineSpacingPreset>(
        iconOnly: true,
        // The nearest preset is shown selected; tapping it applies its value.
        reselectable: true,
        selected: ReaderLineSpacingPreset.nearest(lineHeight),
        onChanged: (preset) {
          final value = preset.lineHeight;
          if (value == lineHeight) return;
          cubit.previewLineHeight(value);
          cubit.commitLineHeight(value);
        },
        options: [
          for (final preset in ReaderLineSpacingPreset.values)
            AppChoiceOption(
              value: preset,
              label: _lineSpacingLabel(l10n, preset),
              glyph: ReaderLineSpacingGlyph(
                preset,
                key: ValueKey('reader-line-spacing-${preset.name}'),
              ),
            ),
        ],
      ),
    );
  }
}

String _lineSpacingLabel(
  ReadflexLocalizations l10n,
  ReaderLineSpacingPreset preset,
) => switch (preset) {
  ReaderLineSpacingPreset.compact => l10n.readerLineSpacingCompact,
  ReaderLineSpacingPreset.normal => l10n.readerLineSpacingNormal,
  ReaderLineSpacingPreset.relaxed => l10n.readerLineSpacingRelaxed,
};

class _MarginControl extends StatelessWidget {
  const _MarginControl();

  @override
  Widget build(BuildContext context) {
    final sideMargin = context.select<ReaderAppearanceCubit, double>(
      (c) => c.state.effectiveAppearance.sideMargin,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    final l10n = context.l10n;
    return SizedBox(
      key: const ValueKey('reader-margin-control'),
      width: _compactControlWidthFor(context),
      child: AppChoiceControl<ReaderMarginPreset>(
        iconOnly: true,
        // The nearest preset is shown selected; tapping it applies its value.
        reselectable: true,
        selected: ReaderMarginPreset.nearest(sideMargin),
        onChanged: (preset) {
          final value = preset.sideMargin;
          if (value == sideMargin) return;
          cubit.previewSideMargin(value);
          cubit.commitSideMargin(value);
        },
        options: [
          for (final preset in ReaderMarginPreset.values)
            AppChoiceOption(
              value: preset,
              label: _marginLabel(l10n, preset),
              glyph: ReaderMarginsGlyph(
                preset,
                key: ValueKey('reader-margin-${preset.name}'),
              ),
            ),
        ],
      ),
    );
  }
}

String _marginLabel(ReadflexLocalizations l10n, ReaderMarginPreset preset) =>
    switch (preset) {
      ReaderMarginPreset.narrow => l10n.readerMarginsNarrow,
      ReaderMarginPreset.medium => l10n.readerMarginsMedium,
      ReaderMarginPreset.wide => l10n.readerMarginsWide,
    };
