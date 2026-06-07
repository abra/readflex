import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_bloc.dart';
import 'library_layout_cubit.dart';

/// Alpha applied to muted meta text on the header ("N items" counter,
/// inactive segment label colours). Matches `_kMutedAlpha` in the tile files.
const double _kMutedAlpha = 0.55;

/// Top-of-screen sticky header for the library: serif title + item counter,
/// a search field, the filter-segment pills, and the list/grid toggle.
///
/// Pure presentation — all state changes are surfaced via the three
/// callbacks and are expected to hit the library BLoC / layout cubit in the
/// parent. The FAB is deliberately not part of the header; it lives on
/// [Scaffold.floatingActionButton] (see readwell_demo).
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onCollectionScopePressed,
    required this.onCollectionScopeCleared,
    super.key,
  });

  final LibraryState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LibraryFilter> onFilterChanged;
  final VoidCallback onCollectionScopePressed;
  final VoidCallback onCollectionScopeCleared;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Demo uses literals 20/16/12/4/…; project convention is to stick to
    // AppSpacing tokens, so we take the nearest token in each slot.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Library',
                style: context.text.headlineMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${state.totalCount} items',
                style: context.text.screenCounter.copyWith(
                  color: colors.onSurface.withValues(alpha: _kMutedAlpha),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _LayoutToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchField(
            hintText: 'Search library...',
            controller: searchController,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FilterAndCollectionRow(
            state: state,
            onFilterChanged: onFilterChanged,
            onCollectionScopePressed: onCollectionScopePressed,
            onCollectionScopeCleared: onCollectionScopeCleared,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _FilterAndCollectionRow extends StatelessWidget {
  const _FilterAndCollectionRow({
    required this.state,
    required this.onFilterChanged,
    required this.onCollectionScopePressed,
    required this.onCollectionScopeCleared,
  });

  final LibraryState state;
  final ValueChanged<LibraryFilter> onFilterChanged;
  final VoidCallback onCollectionScopePressed;
  final VoidCallback onCollectionScopeCleared;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.chipTapTarget,
      child: Row(
        children: [
          Expanded(
            child: _FilterSegments(
              active: state.filter,
              onChanged: onFilterChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _CollectionScopeButton(
            scope: state.selectedCollectionScope,
            onPressed: onCollectionScopePressed,
            onClearPressed: onCollectionScopeCleared,
          ),
        ],
      ),
    );
  }
}

class _CollectionScopeButton extends StatelessWidget {
  const _CollectionScopeButton({
    required this.scope,
    required this.onPressed,
    required this.onClearPressed,
  });

  final LibraryCollectionScope? scope;
  final VoidCallback onPressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = scope != null;
    final foreground = selected
        ? colors.onPrimary
        : colors.onSurface.withValues(alpha: _kMutedAlpha);
    final background = selected
        ? colors.primary
        : colors.surfaceContainerHighest.withValues(alpha: 0.5);

    return SizedBox(
      height: AppSizes.chipTapTarget,
      child: Center(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: AppSizes.chipHeight,
                maxWidth: selected ? 176 : AppSizes.chipHeight,
                minHeight: AppSizes.chipHeight,
              ),
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.collection,
                            size: AppIconSize.sm,
                            color: foreground,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              scope!.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onClearPressed,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxs),
                              child: Icon(
                                AppIcons.close,
                                size: AppIconSize.xs,
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: AppSizes.chipHeight,
                      height: AppSizes.chipHeight,
                      child: Center(
                        child: Icon(
                          AppIcons.collection,
                          size: AppIconSize.sm,
                          color: foreground,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling strip of filter chips
/// (`All / Books / Comics / New`). Built on the shared
/// [AppFilterChip] so Library and Dictionary look the same.
class _FilterSegments extends StatelessWidget {
  const _FilterSegments({required this.active, required this.onChanged});

  final LibraryFilter active;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.chipTapTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: LibraryFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final filter = LibraryFilter.values[i];
          return AppFilterChip(
            label: _labelFor(filter),
            selected: filter == active,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }

  static String _labelFor(LibraryFilter filter) => switch (filter) {
    LibraryFilter.all => 'All',
    LibraryFilter.books => 'Books',
    LibraryFilter.articles => 'Articles',
    LibraryFilter.comics => 'Comics',
    LibraryFilter.unread => 'New',
  };
}

/// Two-button toggle that switches the library between list and grid
/// layouts. Bound to [LibraryLayoutCubit] so the active mode persists in
/// user preferences.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryLayoutCubit, LibraryLayoutMode>(
      builder: (context, mode) {
        final cubit = context.read<LibraryLayoutCubit>();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayoutToggleButton(
              icon: AppIcons.viewList,
              active: mode == LibraryLayoutMode.list,
              onTap: () => cubit.setLayoutMode(LibraryLayoutMode.list),
            ),
            const SizedBox(width: AppSpacing.xs),
            _LayoutToggleButton(
              icon: AppIcons.viewGrid,
              active: mode == LibraryLayoutMode.grid,
              onTap: () => cubit.setLayoutMode(LibraryLayoutMode.grid),
            ),
          ],
        );
      },
    );
  }
}

/// One cell of the layout toggle — a 40×40 tappable square that fills when
/// active and fades to 55% muted when inactive.
class _LayoutToggleButton extends StatelessWidget {
  const _LayoutToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Demo button: 40x40 (→ AppSizes.iconButtonSize), radius 10 (→ sm=8,
    // −2), icon 20 (→ AppIconSize.sm). Active surface is `cs.secondary`,
    // active icon uses full onSurface, inactive uses onSurface @ 55%.
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: active ? colors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: AppSizes.chipHeight,
            height: AppSizes.chipHeight,
            child: Center(
              child: Icon(
                icon,
                size: AppIconSize.sm,
                color: active
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: _kMutedAlpha),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
