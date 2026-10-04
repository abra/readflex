import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_label.dart';

const double _collectionScopeRowHeight = 48;
const double _collectionScopeResultsMaxHeight = 420;
const double _collectionScopeSectionChromeHeight = 36;
const double _collectionScopeBottomBreathingRoom = AppSpacing.xl;
// Match the header's icon alignment without shrinking the 48dp hit target.
const double _collectionScopeActionOutset =
    (AppSizes.buttonHeight - AppIconSize.sm) / 2;
const EdgeInsetsDirectional _collectionScopeListPadding =
    EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl,
      0,
      AppSpacing.xl - _collectionScopeActionOutset,
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
  Stream<LibraryState>? states,
  VoidCallback? onRetry,
  LibraryCollectionManagerBuilder? manageBuilder,
}) {
  return showAppBottomSheet<LibraryCollectionScopeSheetResult>(
    context,
    // This flow can contain an unsaved form; Close/Back own dismissal.
    dismissible: manageBuilder == null,
    builder: (_) => StreamBuilder<LibraryState>(
      initialData: state,
      stream: states,
      builder: (context, snapshot) => _CollectionScopeSheet(
        state: snapshot.requireData,
        onRetry: onRetry,
        manageBuilder: manageBuilder,
      ),
    ),
  );
}

typedef LibraryCollectionManagerBuilder =
    Widget Function(
      BuildContext context,
      LibraryCollectionScope scope,
      VoidCallback onBack,
      VoidCallback onClose,
    );

/// Searchable collection selector sheet.
class _CollectionScopeSheet extends StatefulWidget {
  const _CollectionScopeSheet({
    required this.state,
    this.onRetry,
    this.manageBuilder,
  });

  final LibraryState state;
  final VoidCallback? onRetry;
  final LibraryCollectionManagerBuilder? manageBuilder;

  @override
  State<_CollectionScopeSheet> createState() => _CollectionScopeSheetState();
}

class _CollectionScopeSheetState extends State<_CollectionScopeSheet> {
  late final TextEditingController _searchController;
  late double _resultsHeight;
  var _query = '';
  LibraryCollectionScope? _managedScope;

  void _manage(LibraryCollectionScope scope) {
    if (widget.manageBuilder == null) {
      Navigator.of(context).pop(LibraryCollectionScopeManageRequested(scope));
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _managedScope = scope);
    }
  }

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

  @override
  void didUpdateWidget(covariant _CollectionScopeSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.collectionScopes != widget.state.collectionScopes) {
      _resultsHeight = _collectionScopeResultsHeight(widget.state);
    }
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
    final managedScope = _managedScope;
    return Stack(
      children: [
        // Preserve the query, focus node and scroll offset while editing.
        Offstage(
          offstage: managedScope != null,
          child: _buildSelector(context),
        ),
        if (managedScope != null)
          widget.manageBuilder!(
            context,
            managedScope,
            () => setState(() => _managedScope = null),
            () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  Widget _buildSelector(BuildContext context) {
    final hasScopes = widget.state.collectionScopes.isNotEmpty;
    final l10n = context.l10n;

    return ActionBottomSheetLayout(
      title: l10n.libraryCollectionsTitle,
      closeLabel: l10n.commonClose,
      onClose: () => Navigator.of(context).pop(),
      constrainBody: true,
      bodyPadding: EdgeInsets.zero,
      child: hasScopes || widget.state.collectionsLoadFailed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.state.collectionsLoadFailed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.libraryLoadCollectionsFailed,
                          style: context.text.bodyMedium.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(AppIcons.refresh),
                          label: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                if (hasScopes) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: SearchField(
                      hintText: l10n.librarySearchCollectionsHint,
                      clearButtonSemanticsLabel: l10n.commonClearSearch,
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Flexible(
                    child: SizedBox(
                      height: _resultsHeight,
                      child: _CollectionScopeSections(
                        state: widget.state,
                        query: _query,
                        onManage: _manage,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                l10n.libraryNoCollectionsYet,
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
  const _CollectionScopeSections({
    required this.state,
    required this.query,
    required this.onManage,
  });

  final LibraryState state;
  final String query;
  final ValueChanged<LibraryCollectionScope> onManage;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final l10n = context.l10n;
    final favouriteScopes = _filterScopes(
      state.favouriteCollectionScopes,
      normalizedQuery,
      l10n,
    );
    final manualScopes = _filterScopes(
      state.manualCollectionScopes,
      normalizedQuery,
      l10n,
    );
    final siteScopes = _filterScopes(
      state.siteCollectionScopes,
      normalizedQuery,
      l10n,
    );
    final authorScopes = _filterScopes(
      state.authorCollectionScopes,
      normalizedQuery,
      l10n,
    );
    final hasMatches =
        favouriteScopes.isNotEmpty ||
        manualScopes.isNotEmpty ||
        siteScopes.isNotEmpty ||
        authorScopes.isNotEmpty;

    if (!hasMatches) {
      return Center(
        child: Text(
          l10n.libraryNoMatchingCollections,
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
            onManage: onManage,
            scopes: favouriteScopes,
            selected: state.selectedCollectionScope,
          ),
          _ScopeSection(
            onManage: onManage,
            title: l10n.libraryManualCollections,
            scopes: manualScopes,
            selected: state.selectedCollectionScope,
          ),
          _ScopeSection(
            onManage: onManage,
            title: l10n.librarySites,
            scopes: siteScopes,
            selected: state.selectedCollectionScope,
          ),
          _ScopeSection(
            onManage: onManage,
            title: l10n.libraryAuthors,
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
    ReadflexLocalizations l10n,
  ) {
    if (normalizedQuery.isEmpty) return scopes;
    return scopes
        .where(
          (scope) => libraryCollectionScopeLabel(
            l10n,
            scope,
          ).toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}

/// Optional titled group inside the collection selector.
class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.onManage,
    required this.scopes,
    required this.selected,
    this.title,
  });

  final String? title;
  final List<LibraryCollectionScope> scopes;
  final LibraryCollectionScope? selected;
  final ValueChanged<LibraryCollectionScope> onManage;

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
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xs,
                end: AppSpacing.xs + _collectionScopeActionOutset,
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
              onManage: () => onManage(scope),
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
  const _CollectionScopeRow({
    required this.scope,
    required this.selected,
    required this.onManage,
  });

  final LibraryCollectionScope scope;
  final bool selected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final label = libraryCollectionScopeLabel(l10n, scope);
    final foreground = selected
        ? colors.selectedControlForeground
        : colors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            if (selected)
              PositionedDirectional(
                start: 0,
                end: _collectionScopeActionOutset,
                top: 0,
                bottom: 0,
                child: Ink(
                  key: ValueKey(
                    'collectionScopeSelection-${scope.type.name}-${scope.id}',
                  ),
                  decoration: BoxDecoration(
                    color: colors.selectedControlBackground,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => Navigator.of(
                context,
              ).pop(LibraryCollectionScopeSelected(scope)),
              child: SizedBox(
                key: ValueKey(
                  'collectionScopeRow-${scope.type.name}-${scope.id}',
                ),
                height: _collectionScopeRowHeight,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: AppSpacing.sm,
                    end: scope.canManage
                        ? 0
                        : AppSpacing.sm + _collectionScopeActionOutset,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? AppIcons.check : _iconFor(scope.type),
                        size: AppIconSize.sm,
                        color: foreground,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyLarge.copyWith(
                            color: selected
                                ? colors.selectedControlForeground
                                : colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        '${scope.sourceCount}',
                        style: context.text.bodyMedium.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (scope.canManage) ...[
                        const SizedBox(width: AppSpacing.md),
                        AppPlainIconButton(
                          tooltip: l10n.libraryManageCollection(label),
                          color: foreground,
                          icon: AppIcons.moreVertical,
                          key: ValueKey(
                            'collectionScopeManage-${scope.type.name}-${scope.id}',
                          ),
                          onPressed: onManage,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
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
