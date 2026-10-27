import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'practice_settings_cubit.dart';
import 'practice_settings_presets.dart';

/// Opens the Practice settings sheet over the hub: new cards a day, what a
/// session reviews, and the memory target. Each choice applies as it is
/// tapped, like Library's Display sheet; the future completes when the
/// sheet closes, so the hub can reload its counts.
Future<void> showPracticeSettingsSheet({
  required BuildContext context,
  required PreferencesService preferencesService,
}) => showAppBottomSheet<void>(
  context,
  scrimClosesFlow: true,
  builder: (_) => BlocProvider(
    create: (_) =>
        PracticeSettingsCubit(preferencesService: preferencesService),
    child: const PracticeSettingsSheet(),
  ),
);

/// The sheet's content; reads [PracticeSettingsCubit] from the tree.
@visibleForTesting
class PracticeSettingsSheet extends StatelessWidget {
  const PracticeSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PracticeSettingsCubit>();
    return ActionBottomSheetLayout.scrollable(
      title: l10n.practiceSettingsTitle,
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.commonClose,
      child: BlocBuilder<PracticeSettingsCubit, PracticeSettingsState>(
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSettingsSection(
              title: l10n.practiceSettingsNewCards,
              child: AppChoiceControl<int>(
                key: const ValueKey('practiceSettingsNewCards'),
                selected: state.newCardsPerDay,
                onChanged: cubit.setNewCardsPerDay,
                options: [
                  for (final preset in practiceNewCardsPresets)
                    AppChoiceOption(value: preset, label: '$preset'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSettingsSection(
              title: l10n.practiceSettingsReview,
              child: AppChoiceControl<bool>(
                key: const ValueKey('practiceSettingsReview'),
                selected: state.reviewHighlights,
                onChanged: cubit.setReviewHighlights,
                options: [
                  AppChoiceOption(
                    value: false,
                    label: l10n.practiceSettingsReviewVocabulary,
                  ),
                  AppChoiceOption(
                    value: true,
                    label: l10n.practiceSettingsReviewWithHighlights,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSettingsSection(
              title: l10n.practiceSettingsMemory,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppChoiceControl<PracticeMemoryTarget>(
                    key: const ValueKey('practiceSettingsMemory'),
                    selected: state.memoryTarget,
                    onChanged: cubit.setMemoryTarget,
                    options: [
                      AppChoiceOption(
                        value: PracticeMemoryTarget.lighter,
                        label: l10n.practiceMemoryLighter,
                      ),
                      AppChoiceOption(
                        value: PracticeMemoryTarget.balanced,
                        label: l10n.practiceMemoryBalanced,
                      ),
                      AppChoiceOption(
                        value: PracticeMemoryTarget.stronger,
                        label: l10n.practiceMemoryStronger,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.practiceMemoryHint,
                    key: const ValueKey('practiceSettingsMemoryHint'),
                    style: context.text.bodySmall.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
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
