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
import 'reader_theme_swatches.dart';

const double _textScaleEpsilon = 0.001;
const double _smallTextSizeGlyph = 14;
const double _largeTextSizeGlyph = 22;
const int _compactLabelMaxLines = 2;

/// The body gutter is reduced by the theme swatches' ink inset so the sample
/// borders land on 24dp; every other section adds it back.
const EdgeInsets _appearanceBodyPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl - ReaderThemeSwatches.inkInset,
  0,
  AppSpacing.xl - ReaderThemeSwatches.inkInset,
  AppSpacing.lg,
);
const EdgeInsets _sectionGutterInset = EdgeInsets.symmetric(
  horizontal: ReaderThemeSwatches.inkInset,
);

/// Opens the reader Appearance sheet. [pdfControls] swaps the text controls
/// (font, size, spacing, alignment, margins) for the PDF page controls:
/// margin crop and page colors. The theme and page turn rows stay.
Future<void> showReaderAppearanceSheet(
  BuildContext context, {
  bool showPageTurnControls = true,
  bool pdfControls = false,
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
        pdfControls: pdfControls,
      ),
    ),
  );
}

/// Bottom sheet shell for per-source reader appearance overrides.
class _ReaderAppearanceSheet extends StatefulWidget {
  const _ReaderAppearanceSheet({
    required this.showPageTurnControls,
    required this.pdfControls,
  });

  final bool showPageTurnControls;
  final bool pdfControls;

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
              pdfControls: widget.pdfControls,
              onFont: () => _showFont(true),
            ),
          ),
          // PDF pages have no font; skip building the font samples.
          if (!widget.pdfControls)
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
    required this.pdfControls,
    required this.onFont,
  });

  final bool showPageTurnControls;
  final bool pdfControls;
  final VoidCallback onFont;

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout.scrollable(
      title: context.l10n.readerAppearanceTitle,
      headerTrailing: const _ResetAppearanceButton(),
      headerCompactTrailing: const _ResetAppearanceButton(compact: true),
      closeLabel: context.l10n.commonClose,
      onClose: () => Navigator.of(context).pop(),
      bodyPadding: _appearanceBodyPadding,
      child: pdfControls
          ? _PdfAppearanceControls(showPageTurnControls: showPageTurnControls)
          : _LayeredAppearanceControls(
              showPageTurnControls: showPageTurnControls,
              onFont: onFont,
            ),
    );
  }
}

/// Reset with its label, or [compact], the icon alone: the header shows the
/// labeled one while it fits beside the title.
class _ResetAppearanceButton extends StatelessWidget {
  const _ResetAppearanceButton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canReset = context.select<ReaderAppearanceCubit, bool>(
      (c) => c.state.hasOverride,
    );
    if (compact) {
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

/// Book and article controls: the theme, the compact rows (font, size,
/// spacing, margins), then the labeled choices.
class _LayeredAppearanceControls extends StatelessWidget {
  const _LayeredAppearanceControls({
    required this.showPageTurnControls,
    required this.onFont,
  });

  final bool showPageTurnControls;
  final VoidCallback onFont;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ThemeSection(),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: _sectionGutterInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactSettingRows(onFont: onFont),
              const SizedBox(height: AppSpacing.lg),
              AppSettingsSection(
                title: l10n.readerTextAlignment,
                child: const _AlignmentControl(),
              ),
              if (showPageTurnControls) ...[
                const SizedBox(height: AppSpacing.lg),
                AppSettingsSection(
                  title: l10n.readerPageTurn,
                  child: const _PageTurnControl(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// PDF pages: the theme, margin crop, page colors and page turn. Text
/// controls do not apply to page images.
class _PdfAppearanceControls extends StatelessWidget {
  const _PdfAppearanceControls({required this.showPageTurnControls});

  final bool showPageTurnControls;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ThemeSection(),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: _sectionGutterInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSettingsSection(
                title: l10n.readerPdfMargins,
                child: const _PdfMarginsControl(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSettingsSection(
                title: l10n.readerPdfPageColors,
                child: const _PdfPageColorsControl(),
              ),
              if (showPageTurnControls) ...[
                const SizedBox(height: AppSpacing.lg),
                AppSettingsSection(
                  title: l10n.readerPageTurn,
                  child: const _PageTurnControl(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PdfMarginsControl extends StatelessWidget {
  const _PdfMarginsControl();

  @override
  Widget build(BuildContext context) {
    final trimmed = context.select<ReaderAppearanceCubit, bool>(
      (c) => c.state.effectiveAppearance.trimPageMargins,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return AppChoiceControl<bool>(
      key: const ValueKey('reader-pdf-margins-control'),
      selected: trimmed,
      onChanged: (value) => cubit.setTrimPageMargins(value),
      options: [
        AppChoiceOption(
          value: false,
          icon: AppIcons.pageWhole,
          label: context.l10n.readerPdfMarginsWhole,
        ),
        AppChoiceOption(
          value: true,
          icon: AppIcons.pageTrimmed,
          label: context.l10n.readerPdfMarginsTrimmed,
        ),
      ],
    );
  }
}

class _PdfPageColorsControl extends StatelessWidget {
  const _PdfPageColorsControl();

  @override
  Widget build(BuildContext context) {
    final colors = context.select<ReaderAppearanceCubit, ReaderPageColors>(
      (c) => c.state.effectiveAppearance.pageColors,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return AppChoiceControl<ReaderPageColors>(
      key: const ValueKey('reader-pdf-page-colors-control'),
      selected: colors,
      onChanged: (value) => cubit.setPageColors(value),
      options: [
        AppChoiceOption(
          value: ReaderPageColors.theme,
          icon: AppIcons.pageColorsTheme,
          label: context.l10n.readerPdfPageColorsTheme,
        ),
        AppChoiceOption(
          value: ReaderPageColors.original,
          icon: AppIcons.pageColorsOriginal,
          label: context.l10n.readerPdfPageColorsOriginal,
        ),
      ],
    );
  }
}

/// Theme label on the 24dp gutter; the swatches bleed their ink inset past
/// it, so only the title takes the gutter inset.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final themeId = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.themeId,
    );
    final cubit = context.read<ReaderAppearanceCubit>();
    return AppSettingsSection(
      title: context.l10n.readerTheme,
      titlePadding: _sectionGutterInset,
      child: ReaderThemeSwatches(
        selected: ReaderThemePreset.fromId(themeId),
        onSelected: (preset) => cubit.setTheme(preset.id),
      ),
    );
  }
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

/// The font row, then text size, line spacing and margins. Each control
/// takes exactly half the column, so its start edge meets the split of the
/// two-option choices below. The three move below their labels together.
class _CompactSettingRows extends StatelessWidget {
  const _CompactSettingRows({required this.onFont});

  final VoidCallback onFont;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = [
      (l10n.readerFontSize, const _FontSizeControl()),
      (l10n.readerLineSpacing, const _LineSpacingControl()),
      (l10n.readerPageMargins, const _MarginControl()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = _stacksCompactRows(
          context,
          width: constraints.maxWidth,
          labels: [for (final (label, _) in rows) label],
        );
        final gap = SizedBox(
          height: stacked ? AppSpacing.lg : AppSpacing.sm,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FontPickerRow(onPressed: onFont),
            for (final (label, control) in rows) ...[
              gap,
              _CompactSettingRow(
                label: label,
                stacked: stacked,
                control: control,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Whether the compact rows put their controls below their labels: for large
/// text in a narrow sheet, when half the column cannot hold three 48dp
/// segments, or when a label would need a third line beside its control.
bool _stacksCompactRows(
  BuildContext context, {
  required double width,
  required List<String> labels,
}) {
  final textScaler = MediaQuery.textScalerOf(context);
  if (width < 360 && textScaler.scale(14) > 18) return true;
  final half = width / 2;
  if (half < AppSizes.buttonHeight * 3) return true;
  final painter = TextPainter(
    textDirection: Directionality.of(context),
    textScaler: textScaler,
    locale: Localizations.maybeLocaleOf(context),
    maxLines: _compactLabelMaxLines,
  );
  try {
    for (final label in labels) {
      painter
        ..text = TextSpan(text: label, style: context.text.bodyMedium)
        ..layout(maxWidth: half - AppSpacing.md);
      if (painter.didExceedMaxLines) return true;
    }
    return false;
  } finally {
    painter.dispose();
  }
}

/// A label with its control in the end half of the row, or, [stacked], a
/// caption above the full-width control like the labeled choices.
class _CompactSettingRow extends StatelessWidget {
  const _CompactSettingRow({
    required this.label,
    required this.stacked,
    required this.control,
  });

  final String label;
  final bool stacked;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    if (stacked) return AppSettingsSection(title: label, child: control);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
              child: Text(
                label,
                maxLines: _compactLabelMaxLines,
                style: context.text.bodyMedium,
              ),
            ),
          ),
          Expanded(child: control),
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
    return AppChoiceControl<ReaderLineSpacingPreset>(
      key: const ValueKey('reader-line-height-control'),
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
    return AppChoiceControl<ReaderMarginPreset>(
      key: const ValueKey('reader-margin-control'),
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
    );
  }
}

String _marginLabel(ReadflexLocalizations l10n, ReaderMarginPreset preset) =>
    switch (preset) {
      ReaderMarginPreset.narrow => l10n.readerMarginsNarrow,
      ReaderMarginPreset.medium => l10n.readerMarginsMedium,
      ReaderMarginPreset.wide => l10n.readerMarginsWide,
    };
