import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_bloc.dart';
import 'library_layout_cubit.dart';
import 'library_display_sheet.dart';
import 'library_theme_cubit.dart';

/// Alpha applied to muted meta text on the header ("N items" counter,
/// inactive segment label colours). Matches `_kMutedAlpha` in the tile files.
const double _kMutedAlpha = 0.55;

/// Top-of-screen sticky header for the library: serif title + item counter,
/// display menu, search field, and filter-segment pills.
///
/// Pure presentation — all state changes are surfaced via the three
/// callbacks and are expected to hit the library BLoC / UI cubits in the
/// parent. The FAB is deliberately not part of the header; it lives on
/// [Scaffold.floatingActionButton] (see readwell_demo).
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.state,
    required this.isOffline,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onCollectionScopePressed,
    required this.onCollectionScopeCleared,
    super.key,
  });

  final LibraryState state;
  final bool isOffline;
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
              const SizedBox(width: AppSpacing.sm),
              _LibraryOfflineStatus(visible: isOffline),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        '${state.totalCount} items',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.screenCounter.copyWith(
                          color: colors.onSurface.withValues(
                            alpha: _kMutedAlpha,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const _DisplayMenuButton(),
                  ],
                ),
              ),
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

class _LibraryOfflineStatus extends StatelessWidget {
  const _LibraryOfflineStatus({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final warning = context.appColors.warning;

    return Opacity(
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.offline, size: AppIconSize.xs, color: warning),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              'offline',
              maxLines: 1,
              style: context.text.labelSmall.copyWith(
                color: warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
                            _iconFor(scope!.type),
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

  IconData _iconFor(LibraryCollectionScopeType type) {
    return switch (type) {
      LibraryCollectionScopeType.favourites => AppIcons.collectionFavourites,
      LibraryCollectionScopeType.manual => AppIcons.collection,
      LibraryCollectionScopeType.site => AppIcons.global,
      LibraryCollectionScopeType.author => AppIcons.author,
    };
  }
}

/// Horizontally scrolling strip of filter chips
/// (`All / Books / Comics / New`). Built on the shared
/// [AppFilterChip] to keep Library filters visually consistent.
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

class _DisplayMenuButton extends StatelessWidget {
  const _DisplayMenuButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Display options',
      child: _HeaderIconButton(
        key: const ValueKey('libraryHeaderDisplayButton'),
        icon: AppIcons.moreVertical,
        iconColor: context.colors.onSurface.withValues(alpha: 0.78),
        onTap: () => showLibraryDisplaySheet(
          context: context,
          layoutCubit: context.read<LibraryLayoutCubit>(),
          themeCubit: context.read<LibraryThemeCubit>(),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: AppSizes.chipHeight,
            height: AppSizes.chipHeight,
            child: Center(
              child: Icon(icon, size: AppIconSize.sm, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
