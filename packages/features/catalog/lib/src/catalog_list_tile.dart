import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_tile_cover.dart';

/// Alpha applied to muted metadata (secondary text, icons) in list rows.
const double _kMutedAlpha = 0.55;

/// List-mode row for a [Book].
///
/// Layout: 44×60 cover on the left, two-line text column on the right
/// (title + author + a meta strip with the format + progress). A bottom
/// hairline is drawn except on the last row (see [showDivider]).
class BookLibraryListTile extends StatelessWidget {
  const BookLibraryListTile({
    required this.book,
    required this.showDivider,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    super.key,
  });

  final Book book;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final progress = (book.readingProgress * 100).round();

    return _ListRowShell(
      cover: BookTileCover(
        book: book,
        showAuthor: false,
        showTitle: false,
        showProgress: false,
      ),
      title: book.title,
      subtitle: book.author,
      showDivider: showDivider,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      metaBuilder: (context, mutedColor) => [
        // Material analogue for demo's LucideIcons.bookOpen. No sub-sm
        // icon size token exists, so we bypass AppIconSize and use the
        // exact demo-tuned literal (10).
        Icon(AppIcons.book, size: 10, color: mutedColor),
        const SizedBox(width: AppSpacing.xs),
        Text('Book', style: _metaStyle(mutedColor)),
        _MetaDot(mutedColor: mutedColor),
        Text(book.format.name.toUpperCase(), style: _metaStyle(mutedColor)),
        _MetaDot(mutedColor: mutedColor),
        if (book.isFinished)
          ..._doneBadge(context)
        else if (progress > 0)
          Text(
            '$progress%',
            style: _metaStyle(context.colors.onSurface).copyWith(
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text('New', style: _metaStyle(mutedColor)),
      ],
    );
  }
}

/// Layout scaffold for the book list tile. Owns the row geometry
/// (60×90 cover, 14dp gap, title/meta column).
///
/// Layout: up-to-3-line title on top, single combined meta strip
/// underneath (subtitle prepended in front of the type-specific
/// segments). Bottom hairline drawn for all rows except the last.
class _ListRowShell extends StatelessWidget {
  const _ListRowShell({
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.metaBuilder,
    required this.showDivider,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  final Widget cover;
  final String title;
  final String? subtitle;
  final List<Widget> Function(BuildContext context, Color mutedColor)
  metaBuilder;
  final bool showDivider;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mutedColor = colors.onSurface.withValues(alpha: _kMutedAlpha);

    final metaSegments = metaBuilder(context, mutedColor);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: showDivider
              // Project exposes a semantic divider hairline via
              // AppColorsExt (gray250 light / darkGray700 dark) —
              // that's the direct analogue of demo's `ext.divider`.
              // `ColorScheme.outlineVariant` is NOT the same role
              // here and falls back to a near-black default.
              ? Border(bottom: BorderSide(color: context.appColors.divider))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Fixed 60x90 cover slot (2:3 book aspect). AppCoverArt clips
            // its own corners (Container.clipBehavior), so no outer
            // ClipRRect needed.
            SizedBox(width: 60, height: 90, child: cover),
            // Demo uses 14dp cover-to-text gap — sits between our
            // md(12) and lg(16) tokens. `md + xxs` = 14 exactly and
            // composes from real tokens, so we don't add a new one.
            const SizedBox(width: AppSpacing.md + AppSpacing.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                      height: 1.25,
                    ),
                  ),
                  // Demo uses 6dp title-to-meta gap (between xs=4 and
                  // sm=8). Composed from xs + xxs to stay token-based.
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasSubtitle) ...[
                        Flexible(
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _metaStyle(mutedColor),
                          ),
                        ),
                        _MetaDot(mutedColor: mutedColor),
                      ],
                      ...metaSegments,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin ` · ` glyph used to separate segments in the meta strip. Extracted
/// so individual call sites don't repeat the fontSize/color wiring.
class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.mutedColor});

  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Text(' · ', style: _metaStyle(mutedColor));
  }
}

TextStyle _metaStyle(Color color) => TextStyle(fontSize: 11, color: color);

/// Builds the green ` ✓ Done` kicker that replaces the progress segment
/// when an item is fully read. Colour comes from the semantic
/// `successForeground` token so it stays legible in both themes.
List<Widget> _doneBadge(BuildContext context) {
  final success = context.appColors.successForeground;
  return [
    Icon(AppIcons.check, size: 10, color: success),
    const SizedBox(width: 2),
    Text(
      'Done',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: success,
      ),
    ),
  ];
}
