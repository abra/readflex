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
        'Import books and articles, read comfortably with a customizable reader.',
  ),
  OnboardingPageData(
    icon: AppIcons.highlightSave,
    title: 'Highlight & save',
    description:
        'Select text to create highlights. Add notes for deeper understanding.',
  ),
  OnboardingPageData(
    icon: AppIcons.buildFlashcards,
    title: 'Build flashcards',
    description:
        'Turn highlights into flashcards. AI helps generate hints and examples.',
  ),
  OnboardingPageData(
    icon: AppIcons.translateLearn,
    title: 'Translate & learn words',
    description:
        'Translate selections instantly. Save words to your personal dictionary.',
  ),
  OnboardingPageData(
    icon: AppIcons.practiceRemember,
    title: 'Practice & remember',
    description:
        'Spaced repetition helps you remember what you read. Review daily for best results.',
  ),
];
