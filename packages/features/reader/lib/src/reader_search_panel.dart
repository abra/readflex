import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_drawer_layout.dart';
import 'reader_drawer_messages.dart';
import 'reader_search_cubit.dart';
import 'reader_search_result_tile.dart';
import 'reader_swipe_to_delete.dart';

/// The reader's search sheet. Retained while hidden so the query, results
/// and scroll offset survive match navigation.
class ReaderSearchPanel extends StatefulWidget {
  const ReaderSearchPanel({
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.onClose,
    required this.onSearch,
    required this.onResultSelected,
    super.key,
  });

  final bool visible;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final VoidCallback onClose;
  final ReaderBookSearch onSearch;
  final ValueChanged<int> onResultSelected;

  @override
  State<ReaderSearchPanel> createState() => _ReaderSearchPanelState();
}

class _ReaderSearchPanelState extends State<ReaderSearchPanel> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _activeTileKey = GlobalKey();
  int _revealAttempts = 0;

  // Builder tiles far from the current offset do not exist yet; each pass
  // jumps by the list's extrapolated extent before aligning precisely.
  static const _maxRevealPasses = 3;

  @override
  void initState() {
    super.initState();
    _field.text = context.read<ReaderSearchCubit>().state.query;
    if (widget.visible) {
      _focusEmptyQuery();
      _revealActiveResult();
    }
  }

  @override
  void didUpdateWidget(ReaderSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _focusEmptyQuery();
      _revealActiveResult();
    }
    if (!widget.visible && oldWidget.visible) _focus.unfocus();
  }

  /// Reopening during match navigation brings the active result into view.
  void _revealActiveResult() {
    final state = context.read<ReaderSearchCubit>().state;
    final index = state.activeResultIndex;
    if (index == null || index < 0 || index >= state.results.length) return;
    _revealAttempts = 0;
    _scheduleReveal(index);
  }

  void _scheduleReveal(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.visible) return;
      final state = context.read<ReaderSearchCubit>().state;
      if (state.activeResultIndex != index) return;
      final tile = _activeTileKey.currentContext;
      final row = tile?.findRenderObject();
      if (tile != null && row != null) {
        // Only the results list, not a sheet scrolled as a whole.
        Scrollable.of(tile).position.ensureVisible(
          row,
          alignment: 0.5,
          duration: context.motion(AppMotion.short),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (!_scroll.hasClients || _revealAttempts++ >= _maxRevealPasses) {
        return;
      }
      final position = _scroll.position;
      final count = state.results.length;
      final estimate = count <= 1
          ? 0.0
          : position.maxScrollExtent * index / (count - 1);
      position.jumpTo(
        estimate.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      _scheduleReveal(index);
    });
  }

  void _focusEmptyQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.visible && _field.text.isEmpty) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReaderSearchCubit, ReaderSearchState>(
      listenWhen: (previous, current) => previous.query != current.query,
      listener: (_, state) {
        if (_field.text == state.query) return;
        _field.value = TextEditingValue(
          text: state.query,
          selection: TextSelection.collapsed(offset: state.query.length),
        );
      },
      child: AppInlineSheet(
        visible: widget.visible,
        onClose: widget.onClose,
        semanticsLabel: context.l10n.readerSearchAction,
        header: _ReaderSearchHeader(onClose: widget.onClose),
        // The list's bottom padding carries the system inset, like the
        // Contents sheet; the sheet itself sits on the keyboard.
        body: _content(),
      ),
    );
  }

  Widget _content() => BlocBuilder<ReaderSearchCubit, ReaderSearchState>(
    builder: (context, state) {
      final l10n = context.l10n;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SearchField(
              controller: _field,
              focusNode: _focus,
              hintText: l10n.readerSearchInBook,
              clearButtonSemanticsLabel: l10n.commonClearSearch,
              textInputAction: TextInputAction.search,
              onChanged: (value) => context
                  .read<ReaderSearchCubit>()
                  .queryChanged(value, searchBook: widget.onSearch),
            ),
          ),
          if (state.results.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.readerSearchMatches(state.results.length),
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 2,
            child: state.isLoading
                ? LinearProgressIndicator(
                    value: state.progress > 0 ? state.progress : null,
                  )
                : null,
          ),
          const Divider(height: 1),
          Expanded(
            child: ClipRect(
              child: ScrollEdgeFadeStack(child: _results(context, state)),
            ),
          ),
        ],
      );
    },
  );

  /// [context] is the builder's, inside the sheet: its MediaQuery has the
  /// keyboard inset removed, which the list padding must see.
  Widget _results(BuildContext context, ReaderSearchState state) {
    final l10n = context.l10n;
    final bottom = EdgeInsets.only(
      bottom: readerDrawerListBottomPadding(context),
    );
    if (state.results.isNotEmpty) {
      return ListView.builder(
        key: PageStorageKey('reader-search-${state.query}'),
        controller: _scroll,
        padding: bottom,
        itemCount: state.results.length,
        itemBuilder: (_, index) {
          final selected = state.activeResultIndex == index;
          return KeyedSubtree(
            key: selected ? _activeTileKey : null,
            child: ReaderSearchResultTile(
              key: ValueKey('reader-search-result-$index'),
              result: state.results[index],
              selected: selected,
              pageProgressionRtl: widget.pageProgressionRtl,
              onTap: () => widget.onResultSelected(index),
            ),
          );
        },
      );
    }
    if (state.query.isEmpty && state.recentQueries.isNotEmpty) {
      return ListView.builder(
        controller: _scroll,
        padding: bottom,
        itemCount: state.recentQueries.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Text(
                l10n.readerRecentSearches,
                style: context.text.labelMedium,
              ),
            );
          }
          final query = state.recentQueries[index - 1];
          return ReaderSwipeToDelete(
            id: query,
            label: l10n.readerRemoveFromHistory,
            collapse: true,
            onDelete: () =>
                context.read<ReaderSearchCubit>().recentQueryRemoved(query),
            child: _ReaderRecentSearchTile(
              query: query,
              pageProgressionRtl: widget.pageProgressionRtl,
              onTap: () {
                _focus.unfocus();
                context.read<ReaderSearchCubit>().recentQuerySelected(
                  query,
                  searchBook: widget.onSearch,
                );
              },
            ),
          );
        },
      );
    }
    final Widget placeholder;
    if (state.errorCode != null || state.errorMessage != null) {
      placeholder = ErrorState(
        message: state.errorMessage ?? l10n.readerSearchFailed,
        retryLabel: l10n.commonRetry,
        busy: state.isLoading,
        onRetry: () => context.read<ReaderSearchCubit>().retry(
          searchBook: widget.onSearch,
        ),
      );
    } else if (state.query.trim().length < ReaderSearchCubit.minQueryLength) {
      placeholder = EmptyState(
        compact: true,
        message: readerSearchPromptMessage(l10n, widget.format),
      );
    } else if (state.isLoading) {
      return const SizedBox.shrink();
    } else {
      placeholder = EmptyState(
        compact: true,
        icon: AppIcons.searchOff,
        message: l10n.readerNoResultsFound,
      );
    }
    // Centered like a list body, but scrollable when the keyboard leaves
    // less room than the placeholder needs.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _scroll,
        padding: bottom,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - bottom.bottom),
          ),
          child: placeholder,
        ),
      ),
    );
  }
}

/// Title and Close: the part of the search sheet that drags it.
class _ReaderSearchHeader extends StatelessWidget {
  const _ReaderSearchHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      // The sheet's grab handle supplies the gap above the title.
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        0,
        readerDrawerActionEndPadding,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.readerSearchAction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleLarge,
            ),
          ),
          AppPlainIconButton(
            tooltip: l10n.commonClose,
            onPressed: onClose,
            icon: AppIcons.close,
          ),
        ],
      ),
    );
  }
}

/// A recent query: the clock marks history apart from results. Removal is
/// the row's swipe and semantics action, so no trailing control is drawn.
class _ReaderRecentSearchTile extends StatelessWidget {
  const _ReaderRecentSearchTile({
    required this.query,
    required this.pageProgressionRtl,
    required this.onTap,
  });

  final String query;
  final bool pageProgressionRtl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(
        AppIcons.clock,
        size: AppIconSize.xs,
        color: context.colors.onSurfaceVariant,
      ),
      title: Text(
        query,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: pageProgressionRtl
            ? TextDirection.rtl
            : TextDirection.ltr,
        style: context.text.bodyMedium,
      ),
      onTap: onTap,
    );
  }
}
