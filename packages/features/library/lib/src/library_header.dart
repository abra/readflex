import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_label.dart';
import 'library_layout.dart';
import 'library_title_layout.dart';

const double _offlineGap = AppSpacing.xs;
const double _titleActionsGap = AppSpacing.md;

/// Everything on the title line besides the title text: the reserved
/// offline icon.
const double _titleChromeWidth = _offlineGap + AppIconSize.xs;

/// Top-of-screen sticky header for the library: the serif title naming the
/// shown collection, its item count and the Display action, over a
/// [kLibraryHeaderBottomPadding] band the content scrolls
/// under. The title is a heading, not a control: what the Library shows is
/// chosen in one place, the Collections picker (Books, Articles, Comics and
/// New are collections there), opened from the bottom capsule beside "+",
/// under the thumb.
///
/// Display is opened by the owning screen, which also suspends search focus.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.state,
    required this.isOffline,
    required this.onDisplayPressed,
    super.key,
  });

  final LibraryState state;
  final bool isOffline;
  final VoidCallback onDisplayPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final scope = state.selectedCollectionScope;
    final title = scope == null
        ? l10n.libraryTitle
        : libraryCollectionScopeLabel(l10n, scope);

    return Padding(
      padding: EdgeInsets.only(
        top: AppWindowSize.isWide(context) ? AppSpacing.xl : AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LibraryTitleBar(
            title: title,
            isOffline: isOffline,
            onDisplayPressed: onDisplayPressed,
          ),
          // An empty library says so in its body; "0 items" would repeat it.
          if (!state.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                l10n.libraryItemCount(state.scopeItemCount),
                key: const ValueKey('libraryHeaderItemCount'),
                style:
                    (AppWindowSize.isMedium(context)
                            ? context.text.bodyMedium
                            : context.text.bodySmall)
                        .copyWith(
                          color: colors.onSurfaceVariant,
                        ),
              ),
            ),
          const SizedBox(height: kLibraryHeaderBottomPadding),
        ],
      ),
    );
  }
}

/// Title and the Display action on one row, or the action above a
/// full-width title when they do not fit at the current text scale.
class _LibraryTitleBar extends StatelessWidget {
  const _LibraryTitleBar({
    required this.title,
    required this.isOffline,
    required this.onDisplayPressed,
  });

  final String title;
  final bool isOffline;
  final VoidCallback onDisplayPressed;

  @override
  Widget build(BuildContext context) {
    final style = context.text.headlineMedium.copyWith(
      color: context.colors.onSurface,
    );
    final actionOutset = AppPlainIconButton.defaultIconOutsetOf(context);
    // The action target extends into the gutter; its glyph stays on the
    // content edge at either control size.
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg - actionOutset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabel = AppWindowSize.isWide(context);
          final actionsWidth = showLabel
              ? _displayActionWidth(context)
              : AppSizes.buttonHeight;
          final actions = SizedBox(
            width: actionsWidth,
            child: _DisplayMenuButton(
              showLabel: showLabel,
              onPressed: onDisplayPressed,
            ),
          );
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
                constraints.maxWidth - actionOutset - _titleChromeWidth,
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
                padding: EdgeInsetsDirectional.only(
                  end: actionOutset,
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
  const _DisplayMenuButton({required this.showLabel, required this.onPressed});

  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Tooltip(
        message: context.l10n.libraryDisplayOptions,
        excludeFromSemantics: true,
        child: TextButton.icon(
          key: const ValueKey('libraryHeaderDisplayButton'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppSizes.buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            textStyle: context.text.labelLarge,
            foregroundColor: context.colors.onSurfaceVariant,
          ),
          onPressed: onPressed,
          icon: const Icon(AppIcons.settings, size: AppIconSize.md),
          label: Text(context.l10n.libraryDisplayOptions),
        ),
      );
    }
    return AppPlainIconButton(
      key: const ValueKey('libraryHeaderDisplayButton'),
      tooltip: context.l10n.libraryDisplayOptions,
      icon: AppIcons.settings,
      color: context.colors.onSurfaceVariant,
      onPressed: onPressed,
    );
  }
}

double _displayActionWidth(BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(
      text: context.l10n.libraryDisplayOptions,
      style: context.text.labelLarge,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  try {
    return painter.width.ceilToDouble() +
        AppSpacing.lg * 2 +
        AppIconSize.md +
        AppSpacing.sm;
  } finally {
    painter.dispose();
  }
}
