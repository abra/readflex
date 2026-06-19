import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'library_bloc.dart';

const double _collectionScopeRowHeight = 48;
const double _collectionScopeResultsMaxHeight = 420;
const double _collectionScopeSectionChromeHeight = 36;
const double _collectionScopeBottomBreathingRoom = AppSpacing.xl;
const EdgeInsets _collectionScopeListPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  0,
  AppSpacing.xl,
  AppSpacing.lg,
);

sealed class LibraryCollectionScopeSheetResult {
  const LibraryCollectionScopeSheetResult();
}

final class LibraryCollectionScopeSelected
    extends LibraryCollectionScopeSheetResult {
  const LibraryCollectionScopeSelected(this.scope);

  final LibraryCollectionScope scope;
}

final class LibraryCollectionScopeManageRequested
    extends LibraryCollectionScopeSheetResult {
  const LibraryCollectionScopeManageRequested(this.scope);

  final LibraryCollectionScope scope;
}

Future<LibraryCollectionScopeSheetResult?> showLibraryCollectionScopeSheet({
  required BuildContext context,
  required LibraryState state,
}) {
  return showAppBottomSheet<LibraryCollectionScopeSheetResult>(
    context,
    bottomSafeAreaMinimum: null,
    builder: (_) => _CollectionScopeSheet(state: state),
  );
}

/// Searchable collection selector sheet.
class _CollectionScopeSheet extends StatefulWidget {
  const _CollectionScopeSheet({required this.state});

  final LibraryState state;

  @override
  State<_CollectionScopeSheet> createState() => _CollectionScopeSheetState();
}

class _CollectionScopeSheetState extends State<_CollectionScopeSheet> {
  late final TextEditingController _searchController;
  late final double _resultsHeight;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _resultsHeight = _collectionScopeResultsHeight(widget.state);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  double _collectionScopeResultsHeight(LibraryState state) {
    // Keep search results from collapsing the modal when there are no matches.
    final sectionCount = [
      state.manualCollectionScopes,
      state.siteCollectionScopes,
      state.authorCollectionScopes,
    ].where((scopes) => scopes.isNotEmpty).length;
    final rowCount = state.collectionScopes.length;
    final contentHeight =
        rowCount * _collectionScopeRowHeight +
        sectionCount * _collectionScopeSectionChromeHeight +
        _collectionScopeBottomBreathingRoom;
    return contentHeight > _collectionScopeResultsMaxHeight
        ? _collectionScopeResultsMaxHeight
        : contentHeight;
  }

  @override
  Widget build(BuildContext context) {
    final hasScopes = widget.state.collectionScopes.isNotEmpty;

    return ActionBottomSheetLayout(
      title: 'Collections',
      bodyPadding: EdgeInsets.zero,
      child: hasScopes
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: SearchField(
                    hintText: 'Search collections...',
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: _resultsHeight,
                  child: _CollectionScopeSections(
                    state: widget.state,
                    query: _query,
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No collections yet',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

/// Filters and renders collection scopes grouped by source type.
class _CollectionScopeSections extends StatelessWidget {
  const _CollectionScopeSections({required this.state, required this.query});

  final LibraryState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final favouriteScopes = _filterScopes(
      state.favouriteCollectionScopes,
      normalizedQuery,
    );
    final manualScopes = _filterScopes(
      state.manualCollectionScopes,
      normalizedQuery,
    );
    final siteScopes = _filterScopes(
      state.siteCollectionScopes,
      normalizedQuery,
    );
    final authorScopes = _filterScopes(
      state.authorCollectionScopes,
      normalizedQuery,
    );
    final hasMatches =
        favouriteScopes.isNotEmpty ||
        manualScopes.isNotEmpty ||
        siteScopes.isNotEmpty ||
        authorScopes.isNotEmpty;

    if (!hasMatches) {
      return Center(
        child: Text(
          'No matching collections',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ScrollEdgeFadeStack(
      showBottomFade: false,
      child: ListView(
        padding: _collectionScopeListPadding,
        children: [
          _ScopeSection(
            scopes: favouriteScopes,
            selected: state.selectedCollectionScope,
          ),
          _ScopeSection(
            title: 'Manual collections',
            scopes: manualScopes,
            selected: state.selectedCollectionScope,
          ),
          _ScopeSection(
            title: 'Sites',
            scopes: siteScopes,
            selected: state.selectedCollectionScope,
          ),
          _ScopeSection(
            title: 'Authors',
            scopes: authorScopes,
            selected: state.selectedCollectionScope,
          ),
        ],
      ),
    );
  }

  List<LibraryCollectionScope> _filterScopes(
    List<LibraryCollectionScope> scopes,
    String normalizedQuery,
  ) {
    if (normalizedQuery.isEmpty) return scopes;
    return scopes
        .where((scope) => scope.label.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }
}

/// Optional titled group inside the collection selector.
class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.scopes,
    required this.selected,
    this.title,
  });

  final String? title;
  final List<LibraryCollectionScope> scopes;
  final LibraryCollectionScope? selected;

  @override
  Widget build(BuildContext context) {
    if (scopes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                title!,
                style: context.text.labelSmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ...scopes.map(
            (scope) => _CollectionScopeRow(
              scope: scope,
              selected:
                  selected?.type == scope.type && selected?.id == scope.id,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable row for one collection scope, with manage affordance when allowed.
class _CollectionScopeRow extends StatelessWidget {
  const _CollectionScopeRow({required this.scope, required this.selected});

  final LibraryCollectionScope scope;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: () => Navigator.of(
          context,
        ).pop(LibraryCollectionScopeSelected(scope)),
        child: SizedBox(
          key: ValueKey('collectionScopeRow-${scope.type.name}-${scope.id}'),
          height: _collectionScopeRowHeight,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.sm,
              right: scope.canManage ? 0 : AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  _iconFor(scope.type),
                  size: AppIconSize.sm,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    scope.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge.copyWith(
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${scope.sourceCount}',
                  style: context.text.bodyMedium.copyWith(color: foreground),
                ),
                if (scope.canManage) ...[
                  const SizedBox(width: AppSpacing.md),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      key: ValueKey(
                        'collectionScopeManage-${scope.type.name}-${scope.id}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(LibraryCollectionScopeManageRequested(scope)),
                      child: Icon(
                        AppIcons.moreVertical,
                        size: AppIconSize.sm,
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
