import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// The commands in the bottom row of the reader's text selection menu, in
/// menu order. Highlight is not here: it sits beside the color swatches.
///
/// Mirrors the reader's text actions composed in `routing.dart`; a test
/// compares the two so the onboarding picture cannot drift from the reader.
final onboardingSelectionMenuActions =
    <({IconData icon, String Function(ReadflexLocalizations l10n) label})>[
      (icon: AppIcons.copy, label: (l10n) => l10n.commonCopy),
      (icon: AppIcons.translate, label: (l10n) => l10n.translationAction),
      (icon: AppIcons.dictionary, label: (l10n) => l10n.dictionaryAction),
    ];

/// A sample book page on onboarding with a selected word and, above it, the
/// reader's text selection menu as it really looks: five highlight colors and
/// Highlight, then the commands of [onboardingSelectionMenuActions].
///
/// The page is always the reader's default Paper page; the menu uses the app
/// theme like the real one (`reader_screen_context_panel.dart`), so both read
/// true in light and dark mode. The selected word takes the app's selection
/// color.
///
/// It is a picture: it never takes input, it scales down as a whole on
/// narrow screens, ignores text scaling, and screen readers hear one
/// description instead of buttons that do nothing.
class OnboardingSelectionSample extends StatelessWidget {
  const OnboardingSelectionSample({super.key});

  /// Counter-clockwise in LTR; mirrored in RTL like the rest of the layout.
  static const tilt = -2 * math.pi / 180;

  /// The real menu: a 4dp inset, five 48dp swatches, an 8dp divider and the
  /// 48dp Highlight button.
  static const menuWidth =
      AppSpacing.xs * 2 +
      AppSizes.buttonHeight * 5 +
      AppSpacing.sm +
      AppSizes.buttonHeight;

  /// Height of each of the menu's two rows, as in the reader.
  static const menuRowHeight = 52.0;

  static const cardPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg + AppSpacing.xs,
  );

  /// Unscaled width of the page card.
  static const cardWidth = menuWidth + AppSpacing.lg * 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final page = ReaderThemePreset.paper.data;

    return Semantics(
      container: true,
      image: true,
      label: l10n.onboardingSelectionSampleLabel(
        l10n.commonCopy,
        l10n.translationAction,
        l10n.dictionaryAction,
      ),
      excludeSemantics: true,
      child: IgnorePointer(
        child: MediaQuery.withNoTextScaling(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Transform.rotate(
                angle: rtl ? -tilt : tilt,
                child: SizedBox(
                  width: cardWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: page.backgroundColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.popover,
                    ),
                    child: Padding(
                      padding: cardPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SelectionMenuSample(page: page),
                          const SizedBox(height: AppSpacing.lg),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: _SampleSentence(page: page),
                          ),
                        ],
                      ),
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

/// The reader's two-row text selection menu, drawn from the same tokens and
/// shared components; nothing in it reacts to input.
class _SelectionMenuSample extends StatelessWidget {
  const _SelectionMenuSample({required this.page});

  final ReaderThemeData page;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final foreground = colors.onSurface;
    final divider = colors.outlineVariant;
    final radius = BorderRadius.circular(AppRadius.lg);

    return DecoratedBox(
      key: const ValueKey('onboardingSelectionMenu'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(
          color: divider.withValues(alpha: 0.72),
          width: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
        boxShadow: AppShadows.popover,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: OnboardingSelectionSample.menuWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: OnboardingSelectionSample.menuRowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      for (final color in HighlightColor.values)
                        AppColorSwatchButton(
                          // An enabled look; IgnorePointer above keeps the
                          // callback from ever running.
                          color: _paperHighlight(color, page),
                          selected: color == HighlightColor.yellow,
                          tooltip: _highlightColorName(color, l10n),
                          size: AppIconSize.md,
                          onPressed: _noop,
                        ),
                      SizedBox(
                        height: AppSizes.chipHeight,
                        child: VerticalDivider(
                          color: divider,
                          width: AppSpacing.sm,
                        ),
                      ),
                      SizedBox.square(
                        dimension: AppSizes.buttonHeight,
                        child: Icon(
                          AppIcons.highlight,
                          size: AppIconSize.sm,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: divider),
              SizedBox(
                height: OnboardingSelectionSample.menuRowHeight,
                child: Row(
                  children: [
                    for (final action in onboardingSelectionMenuActions)
                      Expanded(
                        child: _MenuCommandSample(
                          icon: action.icon,
                          label: action.label(l10n),
                          color: foreground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A glyph above its label, like the reader menu's command buttons.
class _MenuCommandSample extends StatelessWidget {
  const _MenuCommandSample({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppIconSize.sm, color: color),
        const SizedBox(height: AppSpacing.xxs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The page's sample sentence with its word painted as selected text.
class _SampleSentence extends StatelessWidget {
  const _SampleSentence({required this.page});

  final ReaderThemeData page;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final word = l10n.onboardingSelectionSampleWord;
    final sentence = l10n.onboardingSelectionSampleSentence(word);
    final start = sentence.indexOf(word);
    final style = AppTypography.serif(
      textStyle: context.text.bodyMedium,
      color: page.primaryTextColor,
    );
    if (start < 0) return Text(sentence, style: style);

    final selectionColor =
        DefaultSelectionStyle.of(context).selectionColor ??
        context.colors.primary.withValues(alpha: 0.4);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: sentence.substring(0, start)),
          TextSpan(
            text: word,
            style: TextStyle(backgroundColor: selectionColor),
          ),
          TextSpan(text: sentence.substring(start + word.length)),
        ],
      ),
      style: style,
    );
  }
}

/// The swatch fill the reader uses on its default Paper page.
Color _paperHighlight(HighlightColor color, ReaderThemeData page) =>
    switch (color) {
      HighlightColor.yellow => page.highlightYellow,
      HighlightColor.green => page.highlightGreen,
      HighlightColor.blue => page.highlightBlue,
      HighlightColor.pink => page.highlightPink,
      HighlightColor.purple => page.highlightPurple,
    };

String _highlightColorName(HighlightColor color, ReadflexLocalizations l10n) =>
    switch (color) {
      HighlightColor.yellow => l10n.highlightColorYellow,
      HighlightColor.green => l10n.highlightColorGreen,
      HighlightColor.blue => l10n.highlightColorBlue,
      HighlightColor.pink => l10n.highlightColorPink,
      HighlightColor.purple => l10n.highlightColorPurple,
    };
