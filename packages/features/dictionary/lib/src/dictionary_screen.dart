import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

import 'dictionary_add_word_sheet.dart';
import 'dictionary_bloc.dart';
import 'dictionary_detail_sheet.dart';

/// Dictionary tab root screen (route `/dictionary`).
///
/// Browses saved words and phrases as a compact divided list. Each row
/// shows a mastery dot, the serif word, italic part-of-speech kicker,
/// and a one-line translation. Tapping a row opens
/// [DictionaryDetailSheet] with the full entry detail. The FAB opens
/// [DictionaryAddWordSheet] to add a new entry. Owns the
/// [DictionaryBloc] for its subtree.
class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({
    required this.dictionaryRepository,
    required this.fsrsRepository,
    this.onPracticePressed,
    super.key,
  });

  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;

  /// Tapping the Practice button in the screen header invokes this. Wired
  /// at the composition root to switch to the Practice tab. When `null`
  /// the button is hidden.
  final VoidCallback? onPracticePressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('DictionaryScreen');

    return BlocProvider(
      create: (_) => DictionaryBloc(
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
      )..add(const DictionaryLoadRequested()),
      child: _DictionaryView(onPracticePressed: onPracticePressed),
    );
  }
}

class _DictionaryView extends StatelessWidget {
  const _DictionaryView({this.onPracticePressed});

  final VoidCallback? onPracticePressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddWordSheet(context),
        backgroundColor: cs.primary.withValues(alpha: 0.9),
        foregroundColor: cs.onPrimary,
        shape: const CircleBorder(),
        elevation: 3,
        child: const Icon(AppIcons.add, size: 24),
      ),
      body: BlocBuilder<DictionaryBloc, DictionaryState>(
        builder: (context, state) {
          final filtered = state.filteredEntries;

          return switch (state.status) {
            DictionaryStatus.initial || DictionaryStatus.loading =>
              const CenteredCircularProgressIndicator(),
            DictionaryStatus.failure => ErrorState(
              message: 'Failed to load dictionary',
              retryLabel: 'Retry',
              onRetry: () => context.read<DictionaryBloc>().add(
                const DictionaryLoadRequested(),
              ),
            ),
            DictionaryStatus.success => SafeArea(
              bottom: false,
              child: _SuccessBody(
                state: state,
                filtered: filtered,
                onPracticePressed: onPracticePressed,
                onTapEntry: (entry) => _openDetailSheet(
                  context,
                  entry: entry,
                  mastered: state.isMastered(entry.id),
                ),
              ),
            ),
          };
        },
      ),
    );
  }

  void _openAddWordSheet(BuildContext context) {
    final bloc = context.read<DictionaryBloc>();
    showAppBottomSheet<void>(
      context,
      builder: (_) => DictionaryAddWordSheet(
        onSubmit: (data) => bloc.add(
          DictionaryEntryAdded(
            word: data.word,
            translation: data.translation,
            pronunciation: data.pronunciation,
            partOfSpeech: data.partOfSpeech,
          ),
        ),
      ),
    );
  }

  void _openDetailSheet(
    BuildContext context, {
    required DictionaryEntry entry,
    required bool mastered,
  }) {
    final bloc = context.read<DictionaryBloc>();
    showAppBottomSheet<void>(
      context,
      builder: (_) => DictionaryDetailSheet(
        entry: entry,
        mastered: mastered,
        onPractice: onPracticePressed,
        onDelete: () => bloc.add(DictionaryEntryDeleted(entry.id)),
      ),
    );
  }
}

/// Header + scrollable list shown in the success state. Pulled out so
/// the parent can stack it under the FAB without nesting.
class _SuccessBody extends StatelessWidget {
  const _SuccessBody({
    required this.state,
    required this.filtered,
    required this.onPracticePressed,
    required this.onTapEntry,
  });

  final DictionaryState state;
  final List<DictionaryEntry> filtered;
  final VoidCallback? onPracticePressed;
  final ValueChanged<DictionaryEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final appColors = context.appColors;

    return Column(
      children: [
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
                style: text.headlineMedium.copyWith(color: cs.onSurface),
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
                    background: appColors.success.withValues(alpha: 0.12),
                  ),
                  if (onPracticePressed != null) ...[
                    const Spacer(),
                    _PracticeButton(onPressed: onPracticePressed!),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SearchField(
                hintText: 'Search words...',
                onChanged: (query) => context.read<DictionaryBloc>().add(
                  DictionarySearchChanged(query),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterChipsBar(
                active: state.filter,
                totalCount: state.entries.length,
                masteredCount: state.masteredCount,
                learningCount: state.learningCount,
                onSelected: (filter) => context.read<DictionaryBloc>().add(
                  DictionaryFilterChanged(filter),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        Expanded(
          child: ScrollEdgeFadeStack(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: AppIcons.book,
                    message: 'No entries found',
                    subtitle: 'Try a different search term',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      color: appColors.divider.withValues(alpha: 0.4),
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                    itemBuilder: (_, i) {
                      final entry = filtered[i];
                      final mastered = state.isMastered(entry.id);
                      return _DictionaryListRow(
                        key: ValueKey(entry.id),
                        entry: entry,
                        mastered: mastered,
                        onTap: () => onTapEntry(entry),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Compact divided-list row for a single [DictionaryEntry].
///
/// Layout: mastery dot → (serif word + italic part-of-speech) over
/// (one-line translation). Tap target spans the whole row.
class _DictionaryListRow extends StatelessWidget {
  const _DictionaryListRow({
    required this.entry,
    required this.mastered,
    required this.onTap,
    super.key,
  });

  final DictionaryEntry entry;
  final bool mastered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final appColors = context.appColors;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          10,
          AppSpacing.lg,
          10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: mastered
                    ? appColors.successForeground
                    : cs.onSurface.withValues(alpha: 0.30),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          entry.word,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall.copyWith(
                            fontFamily: AppTypography.fontFamilySerif,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (entry.partOfSpeech != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          entry.partOfSpeech!,
                          style: text.labelSmall.copyWith(
                            fontStyle: FontStyle.italic,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.translation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall.copyWith(color: muted),
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

/// Compact text button with a dumbbell icon shown in the header — quick
/// jump to the Practice tab.
class _PracticeButton extends StatelessWidget {
  const _PracticeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(AppIcons.practice, size: 14, color: cs.primary),
      label: Text(
        'Practice',
        style: text.labelSmall.copyWith(
          fontWeight: FontWeight.w500,
          color: cs.primary,
        ),
      ),
    );
  }
}

/// Horizontal scrollable bar of filter chips above the dictionary list.
///
/// "Recent" is intentionally count-less — its limit is fixed (5), not
/// derived from the data, so showing a static "5" next to the chip
/// would be misleading when the user has fewer than 5 entries total.
class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({
    required this.active,
    required this.totalCount,
    required this.masteredCount,
    required this.learningCount,
    required this.onSelected,
  });

  final DictionaryFilter active;
  final int totalCount;
  final int masteredCount;
  final int learningCount;
  final ValueChanged<DictionaryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = <(DictionaryFilter, String, int?)>[
      (DictionaryFilter.all, 'All', totalCount),
      (DictionaryFilter.mastered, 'Mastered', masteredCount),
      (DictionaryFilter.learning, 'Learning', learningCount),
      (DictionaryFilter.recent, 'Recent', null),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final (filter, label, count) in entries) ...[
            _FilterChip(
              label: label,
              count: count,
              selected: active == filter,
              onTap: () => onSelected(filter),
            ),
            if (filter != entries.last.$1) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// A single pill-shaped filter chip. Active state inverts foreground
/// and background to call attention to the current selection.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final foreground = selected
        ? cs.surface
        : cs.onSurface.withValues(alpha: 0.6);
    final background = selected
        ? cs.onSurface
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.labelSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '$count',
                  style: text.labelSmall.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: foreground.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
