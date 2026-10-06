import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_label.dart';
import 'library_layout_cubit.dart';
import 'library_display_sheet.dart';
import 'library_locale_cubit.dart';
import 'library_theme_cubit.dart';

/// Top-of-screen sticky header for the library: serif title + item counter,
/// display menu, search field, and filter-segment pills.
///
/// Pure presentation — all state changes are surfaced via the three
/// callbacks and are expected to hit the library BLoC / UI cubits in the
/// parent. The FAB is deliberately not part of the header; it lives on
/// [Scaffold.floatingActionButton].
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.state,
    required this.isOffline,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onCollectionScopePressed,
    required this.onCollectionScopeCleared,
    super.key,
  });

  final LibraryState state;
  final bool isOffline;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LibraryFilter> onFilterChanged;
  final VoidCallback onCollectionScopePressed;
  final VoidCallback onCollectionScopeCleared;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    // Each row owns its gutters: the title row ends 2dp from the edge so the
    // Display action's 48dp target bleeds into the gutter and its 20dp glyph
    // lands on the 16dp content edge like the search field and chips.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.lg - AppSizes.iconActionOutset,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.libraryTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.headlineMedium.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _LibraryOfflineStatus(visible: isOffline),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _LibraryItemCountBadge(count: state.totalCount),
                const SizedBox(width: AppSpacing.sm),
                const _DisplayMenuButton(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SearchField(
              hintText: l10n.librarySearchHint,
              clearButtonSemanticsLabel: l10n.commonClearSearch,
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _FilterAndCollectionRow(
              state: state,
              onFilterChanged: onFilterChanged,
              onCollectionScopePressed: onCollectionScopePressed,
              onCollectionScopeCleared: onCollectionScopeCleared,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryItemCountBadge extends StatelessWidget {
  const _LibraryItemCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.libraryItemCount(count);
    final compactCount = MaterialLocalizations.of(context).formatDecimal(count);

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppSizes.chipHeight,
            minHeight: 24,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            compactCount,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: context.text.screenCounter.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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

    // Reserve only the icon, not a hidden localized label beside the title.
    return Visibility(
      visible: visible,
      maintainSize: true,
      maintainState: true,
      maintainAnimation: true,
      child: Tooltip(
        message: context.l10n.libraryOffline,
        child: Icon(AppIcons.offline, size: AppIconSize.xs, color: warning),
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
    final label = selected
        ? libraryCollectionScopeLabel(context.l10n, scope!)
        : null;
    final badgeLabel = scope?.isFavourites == true
        ? context.l10n.libraryFavouritesBadge
        : label;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;
    final background = selected
        ? colors.primary
        : colors.surfaceContainerHighest.withValues(alpha: 0.5);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: selected ? 176 : AppSizes.chipTapTarget,
      ),
      child: SizedBox(
        height: AppSizes.chipTapTarget,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Container(
                    key: const ValueKey('library-collection-fill'),
                    width: selected ? double.infinity : AppSizes.chipHeight,
                    height: AppSizes.chipHeight,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Semantics(
                      container: true,
                      label: context.l10n.libraryCollectionsTitle,
                      value: label,
                      button: true,
                      selected: selected,
                      enabled: true,
                      excludeSemantics: true,
                      onTap: onPressed,
                      child: Tooltip(
                        message: label ?? context.l10n.libraryCollectionsTitle,
                        excludeFromSemantics: true,
                        // Like AppFilterChip: the outer box keeps the 48dp
                        // target while the ink stays on the 32dp painted body.
                        child: GestureDetector(
                          onTap: onPressed,
                          behavior: HitTestBehavior.opaque,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: AppSizes.chipTapTarget,
                              minHeight: AppSizes.chipTapTarget,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              widthFactor: 1,
                              child: InkWell(
                                onTap: onPressed,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: AppSizes.chipHeight,
                                    minHeight: AppSizes.chipHeight,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: selected
                                          ? AppSpacing.sm
                                          : (AppSizes.chipHeight -
                                                    AppIconSize.sm) /
                                                2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          selected
                                              ? _iconFor(scope!.type)
                                              : AppIcons.collection,
                                          size: AppIconSize.sm,
                                          color: foreground,
                                        ),
                                        if (label != null) ...[
                                          const SizedBox(width: AppSpacing.xs),
                                          Flexible(
                                            child: Text(
                                              badgeLabel!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.text.labelSmall
                                                  .copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: foreground,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    AppPlainIconButton(
                      tooltip: context.l10n.libraryClearCollectionFilter,
                      onPressed: onClearPressed,
                      icon: AppIcons.close,
                      iconSize: AppIconSize.xs,
                      color: foreground,
                    ),
                ],
              ),
            ],
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
class _FilterSegments extends StatefulWidget {
  const _FilterSegments({required this.active, required this.onChanged});

  final LibraryFilter active;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  State<_FilterSegments> createState() => _FilterSegmentsState();
}

class _FilterSegmentsState extends State<_FilterSegments> {
  final _controller = ScrollController();
  bool _moreAtEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // A chip cut mid-glyph reads as broken; the fade says "scroll for more".
  void _updateFade() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final more = position.maxScrollExtent - position.pixels > 1;
    if (more != _moreAtEnd && mounted) setState(() => _moreAtEnd = more);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final onChanged = widget.onChanged;
    return SizedBox(
      height: AppSizes.chipTapTarget,
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _updateFade();
              return false;
            },
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              itemCount: LibraryFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) {
                final filter = LibraryFilter.values[i];
                return AppFilterChip(
                  label: _labelFor(context, filter),
                  selected: filter == active,
                  onTap: () => onChanged(filter),
                );
              },
            ),
          ),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: ScrollEdgeFade(
              edge: ScrollFadeEdge.end,
              visible: _moreAtEnd,
              height: AppSpacing.xl,
            ),
          ),
        ],
      ),
    );
  }

  static String _labelFor(BuildContext context, LibraryFilter filter) {
    final l10n = context.l10n;
    return switch (filter) {
      LibraryFilter.all => l10n.libraryFilterAll,
      LibraryFilter.books => l10n.libraryFilterBooks,
      LibraryFilter.articles => l10n.libraryFilterArticles,
      LibraryFilter.comics => l10n.libraryFilterComics,
      LibraryFilter.unread => l10n.libraryFilterNew,
    };
  }
}

class _DisplayMenuButton extends StatelessWidget {
  const _DisplayMenuButton();

  @override
  Widget build(BuildContext context) {
    return AppPlainIconButton(
      key: const ValueKey('libraryHeaderDisplayButton'),
      tooltip: context.l10n.libraryDisplayOptions,
      icon: AppIcons.moreVertical,
      color: context.colors.onSurfaceVariant,
      onPressed: () => showLibraryDisplaySheet(
        context: context,
        layoutCubit: context.read<LibraryLayoutCubit>(),
        localeCubit: context.read<LibraryLocaleCubit>(),
        themeCubit: context.read<LibraryThemeCubit>(),
      ),
    );
  }
}
