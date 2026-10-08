import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'onboarding_page_preview.dart';

/// Single onboarding screen shown on the first app launch.
///
/// Both actions finish onboarding; the caller persists completion and decides
/// where each one leads.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onAddBook,
    required this.onNotNow,
    super.key,
  });

  /// Primary action: finish onboarding and start adding a book.
  final VoidCallback onAddBook;

  /// Secondary action: finish onboarding without importing.
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('OnboardingScreen');

    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Large text scrolls the page; the actions stay reachable below.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Room for the tilted corners and the card's shadow.
                        const SizedBox(height: AppSpacing.xl),
                        // The page sample carries the highlight story, so the
                        // copy below does not repeat it.
                        OnboardingPagePreview(
                          chapter: l10n.onboardingHighlightSaveTitle,
                          highlightedParagraph:
                              l10n.onboardingHighlightSaveDescription,
                          paragraph: l10n.onboardingOrganizeLibraryDescription,
                        ),
                        const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.onboardingReadAnythingTitle,
                            style: text.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.onboardingReadAnythingDescription,
                          style: text.bodyLarge.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: onAddBook,
                    icon: const Icon(AppIcons.add, size: AppIconSize.sm),
                    label: AppButtonLabel(l10n.onboardingAddBook),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onNotNow,
                    child: AppButtonLabel(l10n.onboardingNotNow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
