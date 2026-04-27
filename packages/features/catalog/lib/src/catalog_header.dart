import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'catalog_bloc.dart';
import 'catalog_layout_cubit.dart';

/// Alpha applied to muted meta text on the header ("N items" counter,
/// inactive segment label colours). Matches `_kMutedAlpha` in the tile files.
const double _kMutedAlpha = 0.55;

/// Top-of-screen sticky header for the catalog: serif title + item counter,
/// a search field, the filter-segment pills, and the list/grid toggle.
///
/// Pure presentation — all state changes are surfaced via the three
/// callbacks and are expected to hit the catalog BLoC / layout cubit in the
/// parent. The FAB is deliberately not part of the header; it lives on
/// [Scaffold.floatingActionButton] (see readwell_demo).
class CatalogHeader extends StatelessWidget {
  const CatalogHeader({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    super.key,
  });

  final CatalogState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CatalogFilter> onFilterChanged;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Library',
                style: context.text.headlineMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
              Text(
                '${state.totalCount} items',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: _kMutedAlpha),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchField(
            hintText: 'Search books & articles...',
            controller: searchController,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FilterSegments(
            active: state.filter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.visibleItems.length} results',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: _kMutedAlpha),
                ),
              ),
              const _LayoutToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Horizontally scrolling strip of filter pills (`All / Books / Articles /
/// Saved / Finished`). Active pill is drawn in inverse colours; the rest
/// use the secondary surface. Scroll is deliberate — on narrow screens the
/// trailing pills can be reached with a swipe.
class _FilterSegments extends StatelessWidget {
  const _FilterSegments({required this.active, required this.onChanged});

  final CatalogFilter active;
  final ValueChanged<CatalogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Demo: 40px pill height (matches AppSizes.iconButtonSize), separator
    // 6 (→ xs=4), padding H14 (→ md=12), radius 16 (→ AppRadius.lg).
    // Active pill uses onSurface/surface, inactive uses secondary/onSecondary.
    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CatalogFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final filter = CatalogFilter.values[i];
          final selected = filter == active;

          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? colors.onSurface : colors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => onChanged(filter),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.chipHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Center(
                      child: Text(
                        _labelFor(filter),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: selected ? colors.surface : colors.onSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _labelFor(CatalogFilter filter) => switch (filter) {
    CatalogFilter.all => 'All',
    CatalogFilter.books => 'Books',
    CatalogFilter.articles => 'Articles',
    CatalogFilter.saved => 'Saved',
    CatalogFilter.finished => 'Finished',
  };
}

/// Two-button toggle that switches the catalog between list and grid
/// layouts. Bound to [CatalogLayoutCubit] so the active mode persists in
/// user preferences.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogLayoutCubit, CatalogLayoutMode>(
      builder: (context, mode) {
        final cubit = context.read<CatalogLayoutCubit>();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayoutToggleButton(
              icon: AppIcons.viewList,
              active: mode == CatalogLayoutMode.list,
              onTap: () => cubit.setLayoutMode(CatalogLayoutMode.list),
            ),
            const SizedBox(width: AppSpacing.xs),
            _LayoutToggleButton(
              icon: AppIcons.viewGrid,
              active: mode == CatalogLayoutMode.grid,
              onTap: () => cubit.setLayoutMode(CatalogLayoutMode.grid),
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
    // −2), icon 16 (→ AppIconSize.xs). Active surface is `cs.secondary`,
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
                size: AppIconSize.xs,
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
