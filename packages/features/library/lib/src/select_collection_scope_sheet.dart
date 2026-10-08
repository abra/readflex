import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_icon.dart';
import 'library_collection_scope_label.dart';

const double _collectionScopeRowHeight = 48;
const double _collectionScopeResultsMaxHeight = 420;
const double _collectionScopeSectionChromeHeight = 36;
const double _collectionScopeBottomBreathingRoom = AppSpacing.xl;
// Rows keep an 8dp inset for their selection pill and a trailing 48dp menu
// target; the list subtracts both so icons and the menu glyph land on the
// 24dp sheet gutter while the pill and target bleed into it.
const double _collectionScopeRowInset = AppSpacing.sm;
const EdgeInsetsDirectional _collectionScopeListPadding =
    EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl - _collectionScopeRowInset,
      0,
      AppSpacing.xl - AppSizes.iconActionOutset,
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

/// The Library row: show the whole library again.
final class LibraryCollectionScopeCleared
    extends LibraryCollectionScopeSheetResult {
  const LibraryCollectionScopeCleared();
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
    // The list dismisses like other sheets; the nested Manage step guards
    // its own draft with AppSheetDismissGuard.
    scrimClosesFlow: true,
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
    // Favourites and Library lead the list; built-in scopes count only when
    // listed.
    final rowCount =
        1 +
        state.pickerBuiltInCollectionScopes.length +
        state.collectionScopes.where((scope) => !scope.isBuiltIn).length;
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
                  ErrorState(
                    message: l10n.libraryLoadCollectionsFailed,
                    retryLabel: l10n.commonRetry,
                    onRetry: () => widget.onRetry?.call(),
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
          : EmptyState(message: l10n.libraryNoCollectionsYet, compact: true),
    );
  }
}

/// Filters and renders collection scopes. The first group has no title:
/// Favourites directly under the search field, then Library and the
/// built-in scopes. Manual collections, sites and authors follow under
/// their titles.
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
    final showsLibraryRow =
        normalizedQuery.isEmpty ||
        l10n.libraryTitle.toLowerCase().contains(normalizedQuery);
    final builtInScopes = _filterScopes(
      state.pickerBuiltInCollectionScopes,
      normalizedQuery,
      l10n,
    );
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
        showsLibraryRow ||
        builtInScopes.isNotEmpty ||
        favouriteScopes.isNotEmpty ||
        manualScopes.isNotEmpty ||
        siteScopes.isNotEmpty ||
        authorScopes.isNotEmpty;

    if (!hasMatches) {
      return EmptyState(
        message: l10n.libraryNoMatchingCollections,
        compact: true,
      );
    }

    final selected = state.selectedCollectionScope;
    return ScrollEdgeFadeStack(
      showBottomFade: false,
      child: ListView(
        padding: _collectionScopeListPadding,
        children: [
          _ScopeSection(
            rows: [
              // Favourites stays first, under the search field, however many
              // built-in scopes the library lists.
              for (final scope in favouriteScopes)
                _CollectionScopeRow(
                  scope: scope,
                  selected: _isSelected(scope, selected),
                  onManage: () => onManage(scope),
                ),
              if (showsLibraryRow)
                _ScopeOptionRow(
                  keyId: 'library',
                  icon: AppIcons.library,
                  label: l10n.libraryTitle,
                  count: state.totalCount,
                  selected: selected == null,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const LibraryCollectionScopeCleared()),
                ),
              // Books, Articles, Comics and New sit with Library: they
              // narrow by what a source is.
              for (final scope in builtInScopes)
                _CollectionScopeRow(
                  scope: scope,
                  selected: _isSelected(scope, selected),
                  onManage: () => onManage(scope),
                ),
            ],
          ),
          for (final (title, scopes) in [
            (l10n.libraryManualCollections, manualScopes),
            (l10n.librarySites, siteScopes),
            (l10n.libraryAuthors, authorScopes),
          ])
            _ScopeSection(
              title: title,
              rows: [
                for (final scope in scopes)
                  _CollectionScopeRow(
                    scope: scope,
                    selected: _isSelected(scope, selected),
                    onManage: () => onManage(scope),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  bool _isSelected(
    LibraryCollectionScope scope,
    LibraryCollectionScope? selected,
  ) => selected?.type == scope.type && selected?.id == scope.id;

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

/// Optional titled group of picker rows; renders nothing without rows.
class _ScopeSection extends StatelessWidget {
  const _ScopeSection({required this.rows, this.title});

  final String? title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _collectionScopeRowInset,
                end: AppSizes.iconActionOutset,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                title!,
                style: context.text.labelSmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ...rows,
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
    final label = libraryCollectionScopeLabel(context.l10n, scope);
    return _ScopeOptionRow(
      keyId: '${scope.type.name}-${scope.id}',
      icon: libraryCollectionScopeIcon(scope.type),
      label: label,
      count: scope.sourceCount,
      selected: selected,
      onTap: () =>
          Navigator.of(context).pop(LibraryCollectionScopeSelected(scope)),
      manageTooltip: scope.canManage
          ? context.l10n.libraryManageCollection(label)
          : null,
      onManage: scope.canManage ? onManage : null,
    );
  }
}

/// One picker row: icon, label, count and an optional trailing ⋮ menu.
class _ScopeOptionRow extends StatelessWidget {
  const _ScopeOptionRow({
    required this.keyId,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.manageTooltip,
    this.onManage,
  });

  final String keyId;
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final String? manageTooltip;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected
        ? colors.selectedControlForeground
        : colors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // The pill bleeds 8dp into both gutters, like Language options.
            if (selected)
              PositionedDirectional(
                start: 0,
                end: AppSizes.iconActionOutset - _collectionScopeRowInset,
                top: 0,
                bottom: 0,
                child: Ink(
                  key: ValueKey('collectionScopeSelection-$keyId'),
                  decoration: BoxDecoration(
                    color: colors.selectedControlBackground,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: onTap,
              child: SizedBox(
                key: ValueKey('collectionScopeRow-$keyId'),
                height: _collectionScopeRowHeight,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _collectionScopeRowInset,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? AppIcons.check : icon,
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
                        '$count',
                        style: context.text.bodyMedium.copyWith(
                          color: foreground,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Rows without a menu keep its 48dp slot so every
                      // count sits on one column.
                      if (onManage != null)
                        AppPlainIconButton(
                          tooltip: manageTooltip!,
                          color: foreground,
                          icon: AppIcons.moreVertical,
                          key: ValueKey('collectionScopeManage-$keyId'),
                          onPressed: onManage,
                        )
                      else
                        const SizedBox(width: AppSizes.buttonHeight),
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
}
