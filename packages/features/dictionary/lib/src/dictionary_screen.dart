import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:toast_service/toast_service.dart';

import 'confirm_dictionary_deletion_sheet.dart';
import 'dictionary_add_word_sheet.dart';
import 'dictionary_bloc.dart';
import 'dictionary_detail_sheet.dart';
import 'dictionary_selection_cubit.dart';

/// Dictionary tab root screen (route `/dictionary`).
///
/// Browses saved words and phrases as a compact divided list. Each row
/// shows a mastery dot, the serif word, italic part-of-speech kicker,
/// and a one-line translation. Tapping a row opens
/// [DictionaryDetailSheet] with the full entry detail. Long-pressing
/// a row enters multi-select mode; the FAB swaps from add to trash and
/// confirms before bulk-deleting. A right-to-left swipe on a single row
/// triggers the same confirmation flow.
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

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => DictionaryBloc(
            dictionaryRepository: dictionaryRepository,
            fsrsRepository: fsrsRepository,
          )..add(const DictionaryLoadRequested()),
        ),
        BlocProvider(create: (_) => DictionarySelectionCubit()),
      ],
      child: _DictionaryView(onPracticePressed: onPracticePressed),
    );
  }
}

class _DictionaryView extends StatefulWidget {
  const _DictionaryView({this.onPracticePressed});

  final VoidCallback? onPracticePressed;

  @override
  State<_DictionaryView> createState() => _DictionaryViewState();
}

class _DictionaryViewState extends State<_DictionaryView> {
  /// FIFO queue of pending delete descriptors. One entry pushed per
  /// dispatched [DictionaryEntryDeleted] / [DictionaryEntriesDeleted]
  /// event, popped each time the bloc emits a state with a fresh
  /// `deletionVersion`. Replaces the older single-field design that
  /// got overwritten when a second swipe arrived before the first
  /// finished, mis-attributing the success toast.
  final List<_PendingDeletion> _pendingDeletions = [];

  /// Last `deletionVersion` we've already shown a toast for. Used by
  /// [BlocListener.listenWhen] so the listener fires exactly once per
  /// dispatched delete.
  int _consumedDeletionVersion = 0;

  Future<void> _handleDeleteSelected(BuildContext context) async {
    final selection = context.read<DictionarySelectionCubit>();
    final ids = selection.state.selectedIds;
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDictionaryDeletionSheet(
      context,
      count: ids.length,
    );
    if (confirmed != true || !context.mounted) return;
    final bloc = context.read<DictionaryBloc>();
    _pendingDeletions.add(
      _PendingDeletion(
        count: ids.length,
        singleWord: ids.length == 1
            ? _wordOf(bloc.state.entries, ids.first)
            : null,
      ),
    );
    bloc.add(DictionaryEntriesDeleted(ids));
    selection.clear();
  }

  Future<bool> _confirmAndDispatchSwipe(
    BuildContext context,
    DictionaryEntry entry,
  ) async {
    final confirmed = await showConfirmDictionaryDeletionSheet(
      context,
      count: 1,
    );
    if (confirmed != true || !context.mounted) return false;
    _pendingDeletions.add(_PendingDeletion(count: 1, singleWord: entry.word));
    context.read<DictionaryBloc>().add(DictionaryEntryDeleted(entry.id));
    return true;
  }

  /// Used by the detail-sheet delete button. The detail sheet itself
  /// is the user's confirmation, so we skip the bottom sheet here and
  /// just queue up a toast on success/failure.
  void _handleDetailDelete(BuildContext context, DictionaryEntry entry) {
    _pendingDeletions.add(_PendingDeletion(count: 1, singleWord: entry.word));
    context.read<DictionaryBloc>().add(DictionaryEntryDeleted(entry.id));
  }

  /// Locates an entry by id and returns its word, or null if the row is
  /// gone (race between dispatch and a state update).
  static String? _wordOf(List<DictionaryEntry> entries, String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry.word;
    }
    return null;
  }

  void _onDictionaryStateForToast(
    BuildContext context,
    DictionaryState state,
  ) {
    if (_pendingDeletions.isEmpty) return;
    _consumedDeletionVersion = state.deletionVersion;
    final pending = _pendingDeletions.removeAt(0);
    if (state.status == DictionaryStatus.success) {
      if (pending.count == 1 && pending.singleWord != null) {
        showToast(
          context,
          type: NotificationType.success,
          message: '"${pending.singleWord}"',
          messageSuffix: ' deleted',
        );
      } else {
        showToast(
          context,
          type: NotificationType.success,
          message: pending.count == 1
              ? 'Word deleted'
              : '${pending.count} words deleted',
        );
      }
    } else if (state.status == DictionaryStatus.failure) {
      showToast(
        context,
        type: NotificationType.error,
        message: pending.count == 1
            ? 'Failed to delete the word'
            : 'Failed to delete the words',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DictionaryBloc, DictionaryState>(
      // Fires once per dispatched delete (success OR failure) using the
      // `deletionVersion` discriminator — that's what tells a
      // post-delete success apart from any other success emit
      // (load/refresh) that happens while a delete is in flight.
      listenWhen: (prev, curr) =>
          curr.deletionVersion != _consumedDeletionVersion,
      listener: _onDictionaryStateForToast,
      child: BlocBuilder<DictionarySelectionCubit, DictionarySelectionState>(
        builder: (context, selection) {
          return PopScope(
            // Cancel selection mode on the system back gesture instead
            // of leaving the tab.
            canPop: !selection.isActive,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              context.read<DictionarySelectionCubit>().clear();
            },
            child: Scaffold(
              floatingActionButton: _DictionaryFab(
                selectionActive: selection.isActive,
                onAddPressed: () => _openAddWordSheet(context),
                onDeletePressed: () => _handleDeleteSelected(context),
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
                        selection: selection,
                        onPracticePressed: widget.onPracticePressed,
                        onTapEntry: (entry) => _openDetailSheet(
                          context,
                          entry: entry,
                          mastered: state.isMastered(entry.id),
                        ),
                        onLongPressEntry: (entry) => context
                            .read<DictionarySelectionCubit>()
                            .toggle(entry.id),
                        onConfirmSwipeDelete: (entry) =>
                            _confirmAndDispatchSwipe(context, entry),
                      ),
                    ),
                  };
                },
              ),
            ),
          );
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
    showAppBottomSheet<void>(
      context,
      builder: (_) => DictionaryDetailSheet(
        entry: entry,
        mastered: mastered,
        onPractice: widget.onPracticePressed,
        onDelete: () => _handleDetailDelete(context, entry),
      ),
    );
  }
}

/// Swaps the FAB icon based on whether a multi-select is active. Add
/// (`+`) when idle, trash when ≥1 entry is selected. Mirror of the
/// Catalog FAB so the UX feels uniform across tabs.
class _DictionaryFab extends StatelessWidget {
  const _DictionaryFab({
    required this.selectionActive,
    required this.onAddPressed,
    required this.onDeletePressed,
  });

  final bool selectionActive;
  final VoidCallback onAddPressed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton(
      onPressed: selectionActive ? onDeletePressed : onAddPressed,
      backgroundColor: selectionActive
          ? cs.error
          : cs.primary.withValues(alpha: 0.9),
      foregroundColor: selectionActive ? cs.onError : cs.onPrimary,
      shape: const CircleBorder(),
      elevation: 3,
      // Tab branches stay alive in StatefulShellRoute, so two FABs
      // would otherwise share the default Hero tag and clash.
      heroTag: null,
      child: Icon(
        selectionActive ? AppIcons.delete : AppIcons.add,
        size: 24,
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
    required this.selection,
    required this.onPracticePressed,
    required this.onTapEntry,
    required this.onLongPressEntry,
    required this.onConfirmSwipeDelete,
  });

  final DictionaryState state;
  final List<DictionaryEntry> filtered;
  final DictionarySelectionState selection;
  final VoidCallback? onPracticePressed;
  final ValueChanged<DictionaryEntry> onTapEntry;
  final ValueChanged<DictionaryEntry> onLongPressEntry;
  final Future<bool> Function(DictionaryEntry) onConfirmSwipeDelete;

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
                    // Horizontal padding lives on the list (not on each
                    // row) so the swipe-to-delete background is inset
                    // from the screen edges — same shape as the
                    // catalog list. Keeping `lg` on rows would make
                    // the Dismissible reach the screen edge while
                    // catalog's stays inset.
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      80,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      color: appColors.divider.withValues(alpha: 0.4),
                      height: 1,
                    ),
                    itemBuilder: (_, i) {
                      final entry = filtered[i];
                      final mastered = state.isMastered(entry.id);
                      final row = _DictionaryListRow(
                        key: ValueKey(entry.id),
                        entry: entry,
                        mastered: mastered,
                        isSelected: selection.contains(entry.id),
                        onTap: () {
                          if (selection.isActive) {
                            onLongPressEntry(entry);
                          } else {
                            onTapEntry(entry);
                          }
                        },
                        onLongPress: () => onLongPressEntry(entry),
                      );
                      // Swipe-to-delete is suppressed during multi-select
                      // so two destructive paths don't compete for the
                      // same gesture.
                      if (selection.isActive) return row;
                      return Dismissible(
                        key: ValueKey('dict-row-${entry.id}'),
                        direction: DismissDirection.endToStart,
                        background: const _SwipeDeleteBackground(),
                        confirmDismiss: (_) => onConfirmSwipeDelete(entry),
                        child: row,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: cs.error,
      child: Icon(AppIcons.delete, color: cs.onError),
    );
  }
}

/// Compact divided-list row for a single [DictionaryEntry].
///
/// Layout: mastery dot → (serif word + italic part-of-speech) over
/// (one-line translation). Tap target spans the whole row. When
/// [isSelected], the row paints a tinted background and the mastery
/// dot is replaced by a primary-colored check.
class _DictionaryListRow extends StatelessWidget {
  const _DictionaryListRow({
    required this.entry,
    required this.mastered,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    super.key,
  });

  final DictionaryEntry entry;
  final bool mastered;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final appColors = context.appColors;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        // Horizontal `lg` lives on the parent ListView so the
        // swipe-delete background insets itself naturally; the row
        // adds a small `xs` inset of its own so the leading mastery
        // dot doesn't sit flush against the tile's left edge —
        // matches the catalog list-tile spacing.
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Fixed leading slot — both the mastery dot (6dp) and the
              // selection check (14dp) sit inside the same square so the
              // text column doesn't jump horizontally when the user
              // long-presses to start selection.
              SizedBox(
                width: 14,
                height: 14,
                child: Center(
                  child: isSelected
                      ? Icon(AppIcons.check, size: 14, color: cs.primary)
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: mastered
                                ? appColors.successForeground
                                : cs.onSurface.withValues(alpha: 0.30),
                            shape: BoxShape.circle,
                          ),
                        ),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

/// Display-side metadata captured at delete-dispatch time so the
/// post-delete toast can reference the correct word / count even if
/// other deletes overlap or land first.
class _PendingDeletion {
  const _PendingDeletion({required this.count, this.singleWord});

  final int count;
  final String? singleWord;
}
