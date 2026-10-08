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
import 'library_title_layout.dart';

const double _offlineGap = AppSpacing.xs;
const double _titleActionsGap = AppSpacing.md;

/// Everything on the title line besides the title text: the reserved
/// offline icon.
const double _titleChromeWidth = _offlineGap + AppIconSize.xs;

/// Top-of-screen sticky header for the library: the serif title naming the
/// shown collection, its item count, the Display action and the search
/// field. The title is a heading, not a control: what the Library shows is
/// chosen in one place, the Collections picker (Books, Articles, Comics and
/// New are collections there), opened from the bottom capsule beside "+",
/// under the thumb.
///
/// Pure presentation — all state changes are surfaced via callbacks and are
/// expected to hit the library BLoC / UI cubits in the parent.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.state,
    required this.isOffline,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    super.key,
  });

  final LibraryState state;
  final bool isOffline;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final scope = state.selectedCollectionScope;
    final title = scope == null
        ? l10n.libraryTitle
        : libraryCollectionScopeLabel(l10n, scope);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LibraryTitleBar(title: title, isOffline: isOffline),
          // An empty library says so in its body; "0 items" would repeat it.
          if (!state.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                l10n.libraryItemCount(state.scopeItemCount),
                key: const ValueKey('libraryHeaderItemCount'),
                style: context.text.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
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
        ],
      ),
    );
  }
}

/// Title and the Display action on one row, or the action above a
/// full-width title when they do not fit at the current text scale.
class _LibraryTitleBar extends StatelessWidget {
  const _LibraryTitleBar({required this.title, required this.isOffline});

  final String title;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final style = context.text.headlineMedium.copyWith(
      color: context.colors.onSurface,
    );
    const actions = _DisplayMenuButton();

    // The title starts on the 16dp gutter. The row ends 2dp from the edge so
    // the Display action's 48dp target bleeds into the gutter and its 20dp
    // glyph lands on the 16dp content edge like the search field.
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg - AppSizes.iconActionOutset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const actionsWidth = AppSizes.buttonHeight;
          final layout = resolveLibraryTitleLayout(
            title: title,
            style: style,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            locale: Localizations.maybeLocaleOf(context),
            inlineWidth:
                constraints.maxWidth -
                actionsWidth -
                _titleActionsGap -
                _titleChromeWidth,
            stackedWidth:
                constraints.maxWidth -
                AppSizes.iconActionOutset -
                _titleChromeWidth,
          );
          final titleLine = _LibraryTitleLine(
            title: title,
            style: libraryTitleStyle(style, layout.fontScale),
            maxLines: layout.maxLines,
            isOffline: isOffline,
          );

          if (!layout.stacked) {
            return Row(
              children: [
                Expanded(child: titleLine),
                const SizedBox(width: _titleActionsGap),
                actions,
              ],
            );
          }
          return Column(
            key: const ValueKey('libraryHeaderStackedTitle'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerEnd, child: actions),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppSizes.iconActionOutset,
                ),
                child: titleLine,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LibraryTitleLine extends StatelessWidget {
  const _LibraryTitleLine({
    required this.title,
    required this.style,
    required this.maxLines,
    required this.isOffline,
  });

  final String title;
  final TextStyle style;
  final int? maxLines;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Semantics(
            key: const ValueKey('libraryHeaderTitle'),
            header: true,
            child: Text(title, maxLines: maxLines, style: style),
          ),
        ),
        const SizedBox(width: _offlineGap),
        _LibraryOfflineStatus(visible: isOffline),
      ],
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
