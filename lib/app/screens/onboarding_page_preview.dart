import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'onboarding_highlight_range.dart';

/// A sample book page on onboarding: a small chapter label above two serif
/// paragraphs, the first with a highlighted phrase.
///
/// It always uses the reader's default page, not the app theme, so it reads
/// as a page in both light and dark mode. The tilt is static decoration.
class OnboardingPagePreview extends StatelessWidget {
  const OnboardingPagePreview({
    required this.chapter,
    required this.highlightedParagraph,
    required this.paragraph,
    super.key,
  });

  final String chapter;

  /// Shown first; [onboardingHighlightRange] picks its highlighted phrase.
  final String highlightedParagraph;
  final String paragraph;

  /// Counter-clockwise in LTR; mirrored in RTL like the rest of the layout.
  static const tilt = -2 * math.pi / 180;

  /// Wide enough for a phone page, so tablets do not stretch the sample.
  static const maxWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    final page = ReaderThemePreset.paper.data;
    final text = context.text;
    final body = AppTypography.serif(
      textStyle: text.bodyMedium,
      color: page.primaryTextColor,
    );
    final range = onboardingHighlightRange(highlightedParagraph);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Transform.rotate(
          angle: rtl ? -tilt : tilt,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: page.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.popover,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl + AppSpacing.xs,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    chapter.toUpperCase(),
                    // Screen readers spell some all-caps words letter by
                    // letter; announce the label as written.
                    semanticsLabel: chapter,
                    style: AppTypography.serif(
                      textStyle: text.kicker,
                      color: page.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: range.textBefore(highlightedParagraph)),
                        TextSpan(
                          text: range.textInside(highlightedParagraph),
                          style: TextStyle(
                            backgroundColor: page.highlightYellow,
                          ),
                        ),
                        TextSpan(text: range.textAfter(highlightedParagraph)),
                      ],
                    ),
                    style: body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(paragraph, style: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
