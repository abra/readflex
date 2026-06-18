import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

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

const onboardingPages = [
  OnboardingPageData(
    icon: AppIcons.readAnything,
    title: 'Read anything',
    description:
        'Import books and read comfortably with a customizable reader.',
  ),
  OnboardingPageData(
    icon: AppIcons.highlightSave,
    title: 'Highlight & save',
    description:
        'Select text to create highlights. Add notes for deeper understanding.',
  ),
  OnboardingPageData(
    icon: AppIcons.library,
    title: 'Organize your library',
    description:
        'Keep books and articles in one place and return to your reading progress.',
  ),
];
