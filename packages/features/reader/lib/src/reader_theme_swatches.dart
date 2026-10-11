import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const double _sampleMinHeight = 36;
const double _swatchGap = AppSpacing.xs;

/// The reader themes as sample pages with their names. Only the selected
/// sample's accent ring and accent name mark the choice.
///
/// All five sit in one row when every name fits its column on one line,
/// else in rows of three. When even three do not fit (large text), they
/// scroll in one row that opens on the selected theme.
class ReaderThemeSwatches extends StatelessWidget {
  const ReaderThemeSwatches({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Ink around each sample. The swatches bleed this far into the sheet
  /// gutter so the sample borders, not the ink, sit on it.
  static const double inkInset = AppSpacing.xs;

  final ReaderThemePreset selected;
  final ValueChanged<ReaderThemePreset> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final swatchWidth = _minSwatchWidth(context);
      final available = constraints.maxWidth;
      int? columns;
      for (final candidate in [ReaderThemePreset.values.length, 3]) {
        if (swatchWidth * candidate + _swatchGap * (candidate - 1) <=
            available) {
          columns = candidate;
          break;
        }
      }
      if (columns == null) {
        return _ThemeSwatchStrip(
          key: const ValueKey('reader-theme-presets'),
          swatchWidth: swatchWidth,
          viewportWidth: available,
          selected: selected,
          onSelected: onSelected,
        );
      }
      final width = (available - _swatchGap * (columns - 1)) / columns;
      return Wrap(
        key: const ValueKey('reader-theme-presets'),
        spacing: _swatchGap,
        runSpacing: AppSpacing.sm,
        children: [
          for (final preset in ReaderThemePreset.values)
            SizedBox(
              width: width,
              child: _ThemeSwatch(
                preset: preset,
                active: preset == selected,
                onTap: () => onSelected(preset),
              ),
            ),
        ],
      );
    },
  );

  // The selected name's weight, so selecting never makes a name wrap.
  // Rounded up: a column exactly as wide as a name must not break it.
  double _minSwatchWidth(BuildContext context) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    try {
      var widest = 0.0;
      for (final preset in ReaderThemePreset.values) {
        painter
          ..text = TextSpan(
            text: _themePresetLabel(context.l10n, preset),
            style: _labelStyle(context, active: true),
          )
          ..layout();
        widest = math.max(widest, painter.width);
      }
      return math.max(
        AppSizes.buttonHeight,
        (widest + inkInset * 2).ceilToDouble(),
      );
    } finally {
      painter.dispose();
    }
  }
}

/// One row of swatches that scrolls under edge fades. It opens with the
/// selected swatch centered, as far as the row allows, then keeps the
/// reader's scroll position.
class _ThemeSwatchStrip extends StatefulWidget {
  const _ThemeSwatchStrip({
    required this.swatchWidth,
    required this.viewportWidth,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final double swatchWidth;
  final double viewportWidth;
  final ReaderThemePreset selected;
  final ValueChanged<ReaderThemePreset> onSelected;

  @override
  State<_ThemeSwatchStrip> createState() => _ThemeSwatchStripState();
}

class _ThemeSwatchStripState extends State<_ThemeSwatchStrip> {
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _selectedCenteredOffset(),
  );

  double _selectedCenteredOffset() {
    final count = ReaderThemePreset.values.length;
    final step = widget.swatchWidth + _swatchGap;
    final overflow = count * step - _swatchGap - widget.viewportWidth;
    final centered =
        widget.selected.index * step +
        (widget.swatchWidth - widget.viewportWidth) / 2;
    return centered.clamp(0, math.max(0, overflow));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollEdgeFadeStack(
    axis: Axis.horizontal,
    surfaceColor:
        Theme.of(context).bottomSheetTheme.backgroundColor ??
        context.colors.surface,
    child: SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: _swatchGap,
        children: [
          for (final preset in ReaderThemePreset.values)
            SizedBox(
              width: widget.swatchWidth,
              child: _ThemeSwatch(
                preset: preset,
                active: preset == widget.selected,
                onTap: () => widget.onSelected(preset),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  final ReaderThemePreset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = preset.data;
    final label = _themePresetLabel(context.l10n, preset);
    final radius = BorderRadius.circular(AppRadius.sm);
    // The sample keeps the preset's own page colors.
    return Semantics(
      key: ValueKey('reader-theme-swatch-${preset.id}'),
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
            child: Padding(
              padding: const EdgeInsets.all(ReaderThemeSwatches.inkInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: math.max(
                      _sampleMinHeight,
                      MediaQuery.textScalerOf(context).scale(15) * 1.28 +
                          AppSpacing.sm,
                    ),
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
                      style: context.text.titleSmall.copyWith(
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
                    style: _labelStyle(context, active: active),
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

TextStyle _labelStyle(BuildContext context, {required bool active}) =>
    context.text.labelSmall.copyWith(
      color: active
          ? context.actionForeground
          : context.colors.onSurfaceVariant,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
    );

String _themePresetLabel(
  ReadflexLocalizations l10n,
  ReaderThemePreset preset,
) => switch (preset) {
  ReaderThemePreset.snow => l10n.readerThemeSnow,
  ReaderThemePreset.paper => l10n.readerThemePaper,
  ReaderThemePreset.warm => l10n.readerThemeWarm,
  ReaderThemePreset.mist => l10n.readerThemeMist,
  ReaderThemePreset.night => l10n.readerThemeNight,
};
