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
  Future<void> _handleDeleteSelected(BuildContext context) async {
    final selection = context.read<DictionarySelectionCubit>();
    final ids = selection.state.selectedIds;
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDictionaryDeletionSheet(
      context,
      count: ids.length,
    );
    if (confirmed != true || !context.mounted) return;
    context.read<DictionaryBloc>().add(DictionaryEntriesDeleted(ids));
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
    context.read<DictionaryBloc>().add(DictionaryEntryDeleted(entry.id));
    return true;
  }

  /// Used by the detail-sheet delete button. The detail sheet itself
  /// is the user's confirmation, so we skip the bottom sheet here.
  void _handleDetailDelete(BuildContext context, DictionaryEntry entry) {
    context.read<DictionaryBloc>().add(DictionaryEntryDeleted(entry.id));
  }

  void _onDictionaryStateForToast(
    BuildContext context,
    DictionaryState state,
  ) {
    final effect = state.deletionEffect;
    if (effect == null) return;
    if (effect.success) {
      if (effect.count == 1 && effect.singleWord != null) {
        showToast(
          context,
          type: NotificationType.success,
          message: '"${effect.singleWord}"',
          messageSuffix: ' deleted',
        );
      } else {
        showToast(
          context,
          type: NotificationType.success,
          message: effect.count == 1
              ? 'Word deleted'
              : '${effect.count} words deleted',
        );
      }
    } else {
      showToast(
        context,
        type: NotificationType.error,
        message: effect.count == 1
            ? 'Failed to delete the word'
            : 'Failed to delete the words',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DictionaryBloc, DictionaryState>(
      listenWhen: (prev, curr) =>
          prev.deletionEffect != curr.deletionEffect &&
          curr.deletionEffect != null,
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
/// Library FAB so the UX feels uniform across tabs.
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
              // Compact title row mirrors `LibraryHeader`: title on the
              // left, count + trailing affordance on the right. The
              // mastered/learning counts live inside the filter chips
              // below, so the old standalone "saved words" / "mastered"
              // indicator row is gone.
              Row(
                children: [
                  Text(
                    'Dictionary',
                    style: text.headlineMedium.copyWith(color: cs.onSurface),
                  ),
                  const Spacer(),
                  Text(
                    '${state.entries.length} words',
                    style: text.screenCounter.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  if (onPracticePressed != null) ...[
                    const SizedBox(width: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.lg),
              _FilterChipsBar(
                active: state.filter,
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
                    // library list. Keeping `lg` on rows would make
                    // the Dismissible reach the screen edge while
                    // library's stays inset.
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
        // matches the library list-tile spacing.
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

/// Icon-only header action — quick jump to the Practice tab. Sized to
/// match Library's `_LayoutToggleButton` (40×40 with sm radius) so the
/// header affordance reads consistently across the two screens.
class _PracticeButton extends StatelessWidget {
  const _PracticeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: cs.secondary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: AppSizes.chipHeight,
            height: AppSizes.chipHeight,
            child: Center(
              child: Icon(
                AppIcons.practice,
                size: AppIconSize.sm,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable bar of filter chips above the dictionary list.
class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({required this.active, required this.onSelected});

  final DictionaryFilter active;
  final ValueChanged<DictionaryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = <(DictionaryFilter, String)>[
      (DictionaryFilter.all, 'All'),
      (DictionaryFilter.mastered, 'Mastered'),
      (DictionaryFilter.learning, 'Learning'),
      (DictionaryFilter.recent, 'Recent'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final (filter, label) in entries) ...[
            AppFilterChip(
              label: label,
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
