import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_icon.dart';
import 'library_collection_scope_label.dart';

/// The collection switcher at the start of the Library's bottom capsule:
/// the shown collection's icon and name with a chevron, so what the Library
/// shows and where to change it sit under the thumb. It is the Library's
/// only way into the Collections picker; the header title is a heading.
///
/// Inside a collection it takes the paired selected colours, so a narrowed
/// Library reads as such from the bottom too. A long name truncates to one
/// line; the capsule bounds its width.
class LibraryCollectionsButton extends StatelessWidget {
  const LibraryCollectionsButton({
    required this.scope,
    required this.onPressed,
    super.key,
  });

  /// The shown collection; `null` for the whole Library.
  final LibraryCollectionScope? scope;
  final VoidCallback onPressed;

  /// Natural width before the capsule bounds the label, using its real style.
  static double naturalWidthOf(
    BuildContext context,
    LibraryCollectionScope? scope, {
    required TextScaler textScaler,
  }) {
    var style = AppButton.textStyleOf(context, variant: AppButtonVariant.text);
    style = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    final painter = TextPainter(
      text: TextSpan(
        text: scope == null
            ? context.l10n.libraryTitle
            : libraryCollectionScopeLabel(context.l10n, scope),
        style: style,
      ),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    try {
      return AppPlainIconButton.defaultIconOutsetOf(context) +
          AppPlainIconButton.defaultIconSizeOf(context) +
          AppSpacing.sm +
          painter.width +
          AppSpacing.xs +
          AppIconSize.xs +
          AppSpacing.md;
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final scope = this.scope;
    final scoped = scope != null;
    final title = scoped
        ? libraryCollectionScopeLabel(l10n, scope)
        : l10n.libraryTitle;
    final foreground = scoped
        ? colors.selectedControlForeground
        : colors.onSurface;

    // One node: "Choose collection, <title>".
    return MergeSemantics(
      child: Semantics(
        label: l10n.libraryChooseCollection,
        value: title,
        child: AppButton.text(
          key: const ValueKey('libraryCollectionsButton'),
          onPressed: onPressed,
          foregroundColor: foreground,
          backgroundColor: scoped ? colors.selectedControlBackground : null,
          shape: const StadiumBorder(),
          // The leading glyph sits centred in the stadium's round end,
          // level with the "+" glyph in its circle.
          padding: EdgeInsetsDirectional.only(
            start: AppPlainIconButton.defaultIconOutsetOf(context),
            end: AppSpacing.md,
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  scoped
                      ? libraryCollectionScopeIcon(scope.type)
                      : AppIcons.library,
                  size: AppPlainIconButton.defaultIconSizeOf(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.chevronDown,
                  size: AppIconSize.xs,
                  color: scoped ? foreground : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
