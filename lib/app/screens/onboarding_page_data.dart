import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Data for a single onboarding page.
class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const onboardingPageCount = 3;

List<OnboardingPageData> onboardingPages(ReadflexLocalizations l10n) => [
  OnboardingPageData(
    icon: AppIcons.readAnything,
    title: l10n.onboardingReadAnythingTitle,
    description: l10n.onboardingReadAnythingDescription,
  ),
  OnboardingPageData(
    icon: AppIcons.highlightSave,
    title: l10n.onboardingHighlightSaveTitle,
    description: l10n.onboardingHighlightSaveDescription,
  ),
  OnboardingPageData(
    icon: AppIcons.library,
    title: l10n.onboardingOrganizeLibraryTitle,
    description: l10n.onboardingOrganizeLibraryDescription,
  ),
];
