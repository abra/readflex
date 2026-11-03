import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'onboarding_app_icon.dart';
import 'onboarding_feature_list.dart';
import 'onboarding_heading.dart';

/// A single welcome screen. The caller owns completion and navigation;
/// the layout follows the window without creating another onboarding flow.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onAddBook,
    required this.onNotNow,
    super.key,
  });

  static const maxContentWidth = AppSizes.centeredColumnMaxWidth;
  static const featuresSpacing = AppSpacing.xl + AppSpacing.sm;
  static const maxExpandedWidth = maxContentWidth * 2 + AppSpacing.xxl;

  final VoidCallback onAddBook;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('OnboardingScreen');
    return Scaffold(
      body: SafeArea(
        child: AppWindowSize.isWide(context)
            ? _OnboardingWideView(onAddBook: onAddBook, onNotNow: onNotNow)
            : _OnboardingPhoneView(onAddBook: onAddBook, onNotNow: onNotNow),
      ),
    );
  }
}

class _OnboardingPhoneView extends StatelessWidget {
  const _OnboardingPhoneView({required this.onAddBook, required this.onNotNow});

  final VoidCallback onAddBook;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const Center(
                  child: AppContentFrame(
                    maxWidth: OnboardingScreen.maxContentWidth,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OnboardingGreeting(),
                        SizedBox(height: OnboardingScreen.featuresSpacing),
                        _OnboardingFeaturePanel(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AppContentFrame(
          maxWidth: OnboardingScreen.maxContentWidth,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _OnboardingActions(onAddBook: onAddBook, onNotNow: onNotNow),
        ),
      ],
    );
  }
}

class _OnboardingWideView extends StatelessWidget {
  const _OnboardingWideView({required this.onAddBook, required this.onNotNow});

  final VoidCallback onAddBook;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - AppSpacing.xxl * 2),
          ),
          child: Center(
            child: AppContentFrame(
              maxWidth: OnboardingScreen.maxExpandedWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _OnboardingGreeting(expanded: true),
                        const SizedBox(height: AppSpacing.xl),
                        _OnboardingActions(
                          onAddBook: onAddBook,
                          onNotNow: onNotNow,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  const Expanded(child: _OnboardingFeaturePanel()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingGreeting extends StatelessWidget {
  const _OnboardingGreeting({this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: expanded
              ? AlignmentDirectional.centerStart
              : Alignment.center,
          child: const OnboardingAppIcon(),
        ),
        const SizedBox(height: AppSpacing.xl),
        OnboardingHeading(
          l10n.onboardingWelcomeTitle,
          textAlign: expanded ? TextAlign.start : TextAlign.center,
          style: expanded ? context.text.headlineMedium : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.onboardingWelcomeSubtitle,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: expanded ? TextAlign.start : TextAlign.center,
        ),
      ],
    );
  }
}

class _OnboardingFeaturePanel extends StatelessWidget {
  const _OnboardingFeaturePanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: OnboardingFeatureList(),
      ),
    );
  }
}

class _OnboardingActions extends StatelessWidget {
  const _OnboardingActions({required this.onAddBook, required this.onNotNow});

  final VoidCallback onAddBook;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
    );
  }
}
