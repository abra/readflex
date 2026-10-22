import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_icon.dart';
import 'library_collection_scope_label.dart';

part 'select_collection_scope_catalog.dart';
part 'select_collection_scope_entry.dart';

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
          child: _CollectionScopeSelector(
            state: widget.state,
            query: _query,
            resultsHeight: _resultsHeight,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onManage: _manage,
            onRetry: widget.onRetry,
          ),
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
}

/// The searchable scope list; kept offstage while a scope is managed.
class _CollectionScopeSelector extends StatelessWidget {
  const _CollectionScopeSelector({
    required this.state,
    required this.query,
    required this.resultsHeight,
    required this.searchController,
    required this.onSearchChanged,
    required this.onManage,
    this.onRetry,
  });

  final LibraryState state;
  final String query;
  final double resultsHeight;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LibraryCollectionScope> onManage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasScopes = state.collectionScopes.isNotEmpty;
    final l10n = context.l10n;

    return ActionBottomSheetLayout(
      title: l10n.libraryCollectionsTitle,
      closeLabel: l10n.commonClose,
      onClose: () => Navigator.of(context).pop(),
      constrainBody: true,
      bodyPadding: EdgeInsets.zero,
      child: hasScopes || state.collectionsLoadFailed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.collectionsLoadFailed)
                  ErrorState(
                    message: l10n.libraryLoadCollectionsFailed,
                    retryLabel: l10n.commonRetry,
                    onRetry: () => onRetry?.call(),
                  ),
                if (hasScopes) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: SearchField(
                      hintText: l10n.librarySearchCollectionsHint,
                      clearButtonSemanticsLabel: l10n.commonClearSearch,
                      controller: searchController,
                      onChanged: onSearchChanged,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Flexible(
                    child: SizedBox(
                      height: resultsHeight,
                      child: _CollectionScopeSections(
                        state: state,
                        query: query,
                        onManage: onManage,
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

/// Filters and renders collection scopes as one lazy list, so only the rows
/// on screen are built however many sites and authors the library has.
class _CollectionScopeSections extends StatefulWidget {
  const _CollectionScopeSections({
    required this.state,
    required this.query,
    required this.onManage,
  });

  final LibraryState state;
  final String query;
  final ValueChanged<LibraryCollectionScope> onManage;

  @override
  State<_CollectionScopeSections> createState() =>
      _CollectionScopeSectionsState();
}

class _CollectionScopeSectionsState extends State<_CollectionScopeSections> {
  _CollectionScopeCatalog? _catalog;
  String? _query;
  _ScopeList _list = (entries: const [], rowCount: 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateEntries();
  }

  @override
  void didUpdateWidget(covariant _CollectionScopeSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state) ||
        oldWidget.query != widget.query) {
      _updateEntries();
    }
  }

  void _updateEntries() {
    final l10n = context.l10n;
    var catalog = _catalog;
    if (catalog == null || !catalog.isFor(widget.state, l10n)) {
      catalog = _catalog = _CollectionScopeCatalog(widget.state, l10n);
    } else if (_query == widget.query) {
      return;
    }
    _query = widget.query;
    _list = catalog.listFor(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    final (:entries, :rowCount) = _list;
    if (entries.isEmpty) {
      return EmptyState(
        message: context.l10n.libraryNoMatchingCollections,
        compact: true,
      );
    }

    return ScrollEdgeFadeStack(
      showBottomFade: false,
      child: ListView.custom(
        padding: _collectionScopeListPadding,
        // Screen readers count the rows, each carrying its own index.
        semanticChildCount: rowCount,
        childrenDelegate: SliverChildBuilderDelegate(
          childCount: entries.length,
          addSemanticIndexes: false,
          (context, index) => switch (entries[index]) {
            _ScopeTitleEntry(:final title) => _ScopeSectionTitle(title: title),
            _LibraryRowEntry(
              :final count,
              :final selected,
              :final semanticIndex,
              :final endsSection,
            ) =>
              _ScopeRowSlot(
                semanticIndex: semanticIndex,
                endsSection: endsSection,
                child: _ScopeOptionRow(
                  keyId: 'library',
                  icon: AppIcons.library,
                  label: context.l10n.libraryTitle,
                  count: count,
                  selected: selected,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const LibraryCollectionScopeCleared()),
                ),
              ),
            _CollectionScopeRowEntry(
              :final scope,
              :final selected,
              :final semanticIndex,
              :final endsSection,
            ) =>
              _ScopeRowSlot(
                semanticIndex: semanticIndex,
                endsSection: endsSection,
                child: _CollectionScopeRow(
                  scope: scope,
                  selected: selected,
                  onManage: () => widget.onManage(scope),
                ),
              ),
          },
        ),
      ),
    );
  }
}

/// A row's place in the list: its index for screen readers and, for the last
/// row of a section, the 16dp gap below, outside its semantics.
class _ScopeRowSlot extends StatelessWidget {
  const _ScopeRowSlot({
    required this.semanticIndex,
    required this.endsSection,
    required this.child,
  });

  final int semanticIndex;
  final bool endsSection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: endsSection ? AppSpacing.lg : 0),
      child: IndexedSemantics(index: semanticIndex, child: child),
    );
  }
}

/// Title above a group of picker rows.
class _ScopeSectionTitle extends StatelessWidget {
  const _ScopeSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: _collectionScopeRowInset,
        end: AppSizes.iconActionOutset,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: context.text.labelSmall.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
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
