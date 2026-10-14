import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'onboarding_app_icon.dart';
import 'onboarding_feature_list.dart';
import 'onboarding_heading.dart';

/// Single onboarding screen shown on the first app launch.
///
/// It greets the reader as Readflex (the app icon and "Welcome to Readflex")
/// and lists what the app does, every feature with the same weight. How to
/// select text is taught later, in the reader, by its one-time tip. Both
/// actions finish onboarding; the caller persists completion and decides
/// where each one leads.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onAddBook,
    required this.onNotNow,
    super.key,
  });

  /// Content and actions stop growing at this width, so a tablet keeps the
  /// phone's single column instead of stretching rows and buttons.
  static const maxContentWidth = AppSizes.centeredColumnMaxWidth;

  /// Space between the greeting and the feature list.
  static const featuresSpacing = AppSpacing.xl + AppSpacing.sm;

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
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.xl),
                            const Center(child: OnboardingAppIcon()),
                            const SizedBox(height: AppSpacing.lg),
                            OnboardingHeading(l10n.onboardingWelcomeTitle),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.onboardingWelcomeSubtitle,
                              style: text.bodyMedium.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: featuresSpacing),
                            const OnboardingFeatureList(),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
