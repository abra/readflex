import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// What Readflex does, as four short rows of equal weight under the
/// onboarding greeting: the files it opens, saved articles, translation and
/// dictionary lookup, highlights with notes.
///
/// The lookup row names the reader's real selection menu labels, so the copy
/// matches the buttons the reader will see.
class OnboardingFeatureList extends StatelessWidget {
  const OnboardingFeatureList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: [
        OnboardingFeatureRow(
          icon: AppIcons.book,
          title: l10n.onboardingFeatureBooksTitle,
          description: l10n.onboardingFeatureBooksDescription,
        ),
        OnboardingFeatureRow(
          icon: AppIcons.language,
          title: l10n.onboardingFeatureArticlesTitle,
          description: l10n.onboardingFeatureArticlesDescription,
        ),
        OnboardingFeatureRow(
          icon: AppIcons.translate,
          title: l10n.onboardingFeatureLookupTitle,
          description: l10n.onboardingFeatureLookupDescription(
            l10n.translationAction,
            l10n.dictionaryAction,
          ),
        ),
        OnboardingFeatureRow(
          icon: AppIcons.highlight,
          title: l10n.onboardingFeatureHighlightsTitle,
          description: l10n.onboardingFeatureHighlightsDescription,
        ),
      ],
    );
  }
}

/// One feature: an accent glyph on a tonal tile, a title and one line of
/// detail. Screen readers hear the title and detail as one item.
class OnboardingFeatureRow extends StatelessWidget {
  const OnboardingFeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  /// Side of the tile behind the glyph.
  static const tileSize = 40.0;

  /// Gap between the tile and the text, the list rows' cover-to-text gap.
  static const tileToTextGap = AppSpacing.md + AppSpacing.xxs;

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return MergeSemantics(
      child: Row(
        children: [
          SizedBox.square(
            dimension: tileSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: AppIconSize.sm,
                color: context.actionForeground,
              ),
            ),
          ),
          const SizedBox(width: tileToTextGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  title,
                  style: text.titleSmall.copyWith(color: colors.onSurface),
                ),
                Text(
                  description,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
