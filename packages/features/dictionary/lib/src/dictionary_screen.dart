import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

import 'dictionary_bloc.dart';

/// Dictionary tab root screen (route `/dictionary`).
///
/// Browses saved words and phrases with search, shows the "mastered"
/// badge for entries the FSRS scheduler has graduated, and lets the user
/// expand a card to see usage examples and the source. Owns the
/// [DictionaryBloc] for its subtree.
class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({
    required this.dictionaryRepository,
    required this.fsrsRepository,
    super.key,
  });

  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('DictionaryScreen');

    return BlocProvider(
      create: (_) => DictionaryBloc(
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
      )..add(const DictionaryLoadRequested()),
      child: const _DictionaryView(),
    );
  }
}

class _DictionaryView extends StatefulWidget {
  const _DictionaryView();

  @override
  State<_DictionaryView> createState() => _DictionaryViewState();
}

class _DictionaryViewState extends State<_DictionaryView> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final appColors = context.appColors;

    return BlocBuilder<DictionaryBloc, DictionaryState>(
      builder: (context, state) {
        // Cache the derived getter once per build to avoid repeated
        // list allocation in itemCount / itemBuilder.
        final filtered = state.filteredEntries;

        return switch (state.status) {
          DictionaryStatus.initial ||
          DictionaryStatus.loading => const CenteredCircularProgressIndicator(),
          DictionaryStatus.failure => ErrorState(
            message: 'Failed to load dictionary',
            retryLabel: 'Retry',
            onRetry: () => context.read<DictionaryBloc>().add(
              const DictionaryLoadRequested(),
            ),
          ),
          DictionaryStatus.success => SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dictionary',
                        style: text.headlineMedium.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text(
                            '${state.entries.length} saved words',
                            style: text.labelSmall.copyWith(
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          AppBadge(
                            label: '${state.masteredCount} mastered',
                            foreground: appColors.successForeground,
                            background: appColors.success.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SearchField(
                        hintText: 'Search words...',
                        onChanged: (query) => context
                            .read<DictionaryBloc>()
                            .add(DictionarySearchChanged(query)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
                // ─── List ───
                Expanded(
                  child: ScrollEdgeFadeStack(
                    child: filtered.isEmpty
                        ? const EmptyState(
                            icon: AppIcons.book,
                            message: 'No words found',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              80,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (_, i) {
                              final entry = filtered[i];
                              final expanded = _expandedIndex == i;
                              return _WordCard(
                                key: ValueKey(entry.id),
                                entry: entry,
                                expanded: expanded,
                                mastered: state.isMastered(entry.id),
                                onTap: () => setState(
                                  () => _expandedIndex = expanded ? null : i,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        };
      },
    );
  }
}

// ─── Header Widgets ─────────────────────────────────────────

// ─── Word Card ──────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.entry,
    required this.expanded,
    required this.mastered,
    required this.onTap,
    super.key,
  });

  final DictionaryEntry entry;
  final bool expanded;
  final bool mastered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final appColors = context.appColors;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _WordTitle(
                              entry: entry,
                              mastered: mastered,
                              appColors: appColors,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            _PronunciationRow(entry: entry),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Icon(
                          AppIcons.volumeUp,
                          size: AppIconSize.sm,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    entry.translation,
                    style: context.text.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded) _ExpandedSection(entry: entry, appColors: appColors),
          ],
        ),
      ),
    );
  }
}

class _WordTitle extends StatelessWidget {
  const _WordTitle({
    required this.entry,
    required this.mastered,
    required this.appColors,
  });

  final DictionaryEntry entry;
  final bool mastered;
  final AppColorsExt appColors;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Row(
      children: [
        Text(
          entry.word,
          style: context.text.titleMedium.copyWith(
            fontFamily: AppTypography.fontFamilySerif,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        if (mastered) ...[
          const SizedBox(width: AppSpacing.sm),
          AppBadge(
            label: 'Mastered',
            foreground: appColors.successForeground,
            background: appColors.success.withValues(alpha: 0.12),
          ),
        ],
      ],
    );
  }
}

class _PronunciationRow extends StatelessWidget {
  const _PronunciationRow({required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    if (entry.pronunciation == null && entry.partOfSpeech == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (entry.pronunciation != null)
          Text(
            entry.pronunciation!,
            style: context.text.labelSmall.copyWith(
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        if (entry.pronunciation != null && entry.partOfSpeech != null)
          const SizedBox(width: AppSpacing.sm),
        if (entry.partOfSpeech != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              entry.partOfSpeech!,
              style: context.text.labelSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpandedSection extends StatelessWidget {
  const _ExpandedSection({required this.entry, required this.appColors});

  final DictionaryEntry entry;
  final AppColorsExt appColors;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: appColors.divider, height: 1),
          const SizedBox(height: AppSpacing.md),
          if (entry.usageExamples.isNotEmpty)
            Text(
              entry.usageExamples.first,
              style: context.text.bodySmall.copyWith(
                fontFamily: AppTypography.fontFamilySerif,
                fontStyle: FontStyle.italic,
                color: cs.onSurface.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          if (entry.usageExamples.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          if (entry.sourceId != null)
            RichText(
              text: TextSpan(
                style: context.text.labelSmall.copyWith(
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
                children: [
                  const TextSpan(text: 'from '),
                  TextSpan(
                    text: entry.sourceId!,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.7),
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
