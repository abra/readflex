import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_drawer_messages.dart';
import 'reader_search_cubit.dart';
import 'reader_search_result_tile.dart';

/// The reader's side-sliding search surface, retained while hidden.
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

  // Content gutters align glyphs, not the outer edges of 48dp targets.
  static const _actionEndPadding =
      AppSpacing.lg - (AppSizes.buttonHeight - AppIconSize.md) / 2;

  @override
  void initState() {
    super.initState();
    _field.text = context.read<ReaderSearchCubit>().state.query;
    if (widget.visible) _focusEmptyQuery();
  }

  @override
  void didUpdateWidget(ReaderSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) _focusEmptyQuery();
    if (!widget.visible && oldWidget.visible) _focus.unfocus();
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
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: ExcludeFocus(
          excluding: !widget.visible,
          child: ExcludeSemantics(
            excluding: !widget.visible,
            child: AnimatedSlide(
              offset: widget.visible ? Offset.zero : const Offset(-1, 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Material(
                color: context.colors.surface,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: _content(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() => BlocBuilder<ReaderSearchCubit, ReaderSearchState>(
    builder: (context, state) {
      final l10n = context.l10n;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.sm,
              _actionEndPadding,
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
                  onPressed: widget.onClose,
                  icon: AppIcons.close,
                  iconSize: AppIconSize.md,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: SearchField(
              controller: _field,
              focusNode: _focus,
              hintText: l10n.readerSearchInBook,
              clearButtonSemanticsLabel: l10n.commonClearSearch,
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
            child: ClipRect(child: ScrollEdgeFadeStack(child: _results(state))),
          ),
        ],
      );
    },
  );

  Widget _results(ReaderSearchState state) {
    final l10n = context.l10n;
    final bottom = EdgeInsets.only(
      bottom: appBottomSafeInset(context) + AppSpacing.md,
    );
    if (state.results.isNotEmpty) {
      return ListView.builder(
        key: PageStorageKey('reader-search-${state.query}'),
        controller: _scroll,
        padding: bottom,
        itemCount: state.results.length,
        itemBuilder: (_, index) => ReaderSearchResultTile(
          key: ValueKey('reader-search-result-$index'),
          result: state.results[index],
          selected: state.activeResultIndex == index,
          pageProgressionRtl: widget.pageProgressionRtl,
          onTap: () => widget.onResultSelected(index),
        ),
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
          return ListTile(
            contentPadding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xs,
              _actionEndPadding,
              AppSpacing.xs,
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
              textDirection: widget.pageProgressionRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: context.text.bodyMedium,
            ),
            trailing: AppPlainIconButton(
              tooltip: l10n.readerRemoveFromHistory,
              icon: AppIcons.delete,
              iconSize: AppIconSize.md,
              onPressed: () =>
                  context.read<ReaderSearchCubit>().recentQueryRemoved(query),
            ),
            onTap: () {
              _focus.unfocus();
              context.read<ReaderSearchCubit>().recentQuerySelected(
                query,
                searchBook: widget.onSearch,
              );
            },
          );
        },
      );
    }
    final message =
        state.errorMessage ??
        (state.errorCode != null
            ? l10n.readerSearchFailed
            : state.query.trim().length < ReaderSearchCubit.minQueryLength
            ? readerSearchPromptMessage(l10n, widget.format)
            : state.isLoading
            ? ''
            : l10n.readerNoResultsFound);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
        if (state.errorCode != null || state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FilledButton(
              onPressed: () => context.read<ReaderSearchCubit>().retry(
                searchBook: widget.onSearch,
              ),
              child: AppButtonLabel(l10n.commonRetry),
            ),
          ),
      ],
    );
  }
}
