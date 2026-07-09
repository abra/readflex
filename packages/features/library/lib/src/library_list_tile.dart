import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_source_semantics.dart';

/// Alpha applied to muted metadata (secondary text, icons) in list rows.
const double _kMutedAlpha = 0.55;
const double _kArticleIconAlpha = 0.4;
const double _kListCoverWidth = 60;
const double _kListCoverHeight = 90;
const double _kCoverToTextGap = AppSpacing.md + AppSpacing.xxs;
const double _kListRowHorizontalPadding = AppSpacing.xs;
const double _kListRowVerticalPadding = AppSpacing.md;
const double _kListSelectionCheckInset = AppSpacing.xs;
const double _kListSelectionBackgroundInset = _kListRowHorizontalPadding;

/// List-mode row for a library source.
///
/// Layout: 60×90 cover on the left, title/metadata column on the right,
/// and a top hairline except on the first row (see [showTopDivider]).
class BookLibraryListTile extends StatelessWidget {
  const BookLibraryListTile({
    required this.source,
    required this.showTopDivider,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
    super.key,
  });

  final LibrarySource source;
  final bool showTopDivider;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final progress = (source.readingProgress * 100).round();
    final coverImage = appSourceCoverImageFromPath(source.coverImagePath);
    final isArticle = source.sourceType == SourceType.article;
    final subtitle = _subtitleFor(source);
    final coverTextDirection = _sourceTextDirection(source);
    final articleIconColor = Colors.white.withValues(alpha: _kArticleIconAlpha);
    final l10n = context.l10n;
    final sourceCover = AppSourceCover(
      title: source.title,
      author: source.author,
      source: source.sourceName,
      seed: source.id,
      isArticle: isArticle,
      coverImage: coverImage,
      textDirection: coverTextDirection,
      progress: source.readingProgress > 0 ? source.readingProgress : null,
      showAuthor: false,
      showTitle: false,
      showProgress: false,
      showMatte: false,
    );

    return _ListRowShell(
      cover: AppSourceCoverFrame(
        cover: isArticle
            ? Stack(
                alignment: Alignment.center,
                children: [
                  sourceCover,
                  Icon(
                    AppIcons.language,
                    size: AppIconSize.md,
                    color: articleIconColor,
                  ),
                ],
              )
            : sourceCover,
      ),
      title: source.title,
      subtitle: subtitle,
      textDirection: coverTextDirection,
      showTopDivider: showTopDivider,
      isSelected: isSelected,
      semanticsLabel: librarySourceSemanticsLabel(source, l10n),
      semanticsValue: librarySourceSemanticsValue(source, l10n),
      reportsSelectedState: isSelectionMode,
      tapHint: librarySourceTapHint(
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        l10n: l10n,
      ),
      longPressHint: librarySourceLongPressHint(
        isSelectionMode: isSelectionMode,
        l10n: l10n,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      metaBuilder: (context, mutedColor) {
        final sourceName = _secondarySourceName(source, subtitle);

        return [
          // No sub-sm icon token exists, so we bypass AppIconSize and use
          // the exact row-tuned literal (10).
          Icon(_sourceIcon(source), size: 10, color: mutedColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            librarySourceKindLabel(source, l10n),
            style: _metaStyle(context, mutedColor),
          ),
          if (sourceName != null) ...[
            _MetaDot(mutedColor: mutedColor),
            Flexible(
              child: Text(
                sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _metaStyle(context, mutedColor),
              ),
            ),
          ],
          if (!isArticle) ...[
            _MetaDot(mutedColor: mutedColor),
            Text(
              source.typeLabel,
              style: _metaStyle(context, mutedColor),
            ),
          ],
          _MetaDot(mutedColor: mutedColor),
          if (source.isFinished)
            ..._doneBadge(context)
          else if (source.lastOpenedAt == null)
            Text(l10n.librarySourceNew, style: _metaStyle(context, mutedColor))
          else
            // Once the user has opened the source, show the progress %
            // even if it's 0 — they may have navigated back to the
            // cover. Showing "New" again would lie about it never
            // having been read.
            Text(
              '$progress%',
              style: _metaStyle(context, context.colors.onSurface).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
        ];
      },
    );
  }
}

/// Layout scaffold for the source list tile. Owns the row geometry
/// (60×90 cover, 14dp gap, title/meta column).
///
/// Layout: up-to-4-line title on top, single combined meta strip
/// underneath (subtitle prepended in front of the type-specific
/// segments). Top hairline drawn for all rows except the first.
TextDirection _sourceTextDirection(LibrarySource source) {
  return switch (source.inferredTextDirection) {
    ArticleTextDirection.rtl => TextDirection.rtl,
    ArticleTextDirection.ltr || null => TextDirection.ltr,
  };
}

class _ListRowShell extends StatelessWidget {
  const _ListRowShell({
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.textDirection,
    required this.metaBuilder,
    required this.showTopDivider,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.reportsSelectedState,
    required this.tapHint,
    required this.longPressHint,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  final Widget cover;
  final String title;
  final String? subtitle;
  final TextDirection textDirection;
  final List<Widget> Function(BuildContext context, Color mutedColor)
  metaBuilder;
  final bool showTopDivider;
  final bool isSelected;
  final String semanticsLabel;
  final String semanticsValue;
  final bool reportsSelectedState;
  final String tapHint;
  final String? longPressHint;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectionColor = colors.error;
    final mutedColor = colors.onSurface.withValues(alpha: _kMutedAlpha);

    final metaSegments = metaBuilder(context, mutedColor);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final isRtl = textDirection == TextDirection.rtl;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: reportsSelectedState ? isSelected : null,
      label: semanticsLabel,
      value: semanticsValue,
      onTapHint: tapHint,
      onLongPressHint: longPressHint,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    _kListRowVerticalPadding - _kListSelectionBackgroundInset,
                height:
                    _kListCoverHeight + (_kListSelectionBackgroundInset * 2),
                child: DecoratedBox(
                  key: const ValueKey('libraryListSelectionBackground'),
                  decoration: BoxDecoration(
                    color: selectionColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: _kListRowVerticalPadding,
                horizontal: _kListRowHorizontalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Fixed 60x90 cover slot (2:3 book aspect). AppCoverArt clips
                  // its own corners (Container.clipBehavior), so no outer
                  // ClipRRect needed.
                  SizedBox(
                    key: const ValueKey('libraryListCoverSlot'),
                    width: _kListCoverWidth,
                    height: _kListCoverHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(child: cover),
                        if (isSelected) ...[
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                                border: Border.all(
                                  color: selectionColor,
                                  width: 2,
                                ),
                                color: selectionColor.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          Positioned(
                            top: _kListSelectionCheckInset,
                            right: _kListSelectionCheckInset,
                            child: _SelectionCheck(color: selectionColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Demo uses 14dp cover-to-text gap — sits between our
                  // md(12) and lg(16) tokens. `md + xxs` = 14 exactly and
                  // composes from real tokens, so we don't add a new one.
                  const SizedBox(width: _kCoverToTextGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: isRtl
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.start,
                          textDirection: textDirection,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.sourceListTitle.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        // Demo uses 6dp title-to-meta gap (between xs=4 and
                        // sm=8). Composed from xs + xxs to stay token-based.
                        const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                        Directionality(
                          textDirection: textDirection,
                          child: Row(
                            key: const ValueKey('libraryListRowMeta'),
                            textDirection: textDirection,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasSubtitle) ...[
                                Flexible(
                                  child: Text(
                                    subtitle!,
                                    textAlign: TextAlign.start,
                                    textDirection: textDirection,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _metaStyle(context, mutedColor),
                                  ),
                                ),
                                _MetaDot(mutedColor: mutedColor),
                              ],
                              ...metaSegments,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showTopDivider)
              // Paint the separator above this row's cover shadow. A bottom
              // divider on the previous row can be covered by the next row's
              // shadow because list children paint in order.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  key: const ValueKey('libraryListRowTopDivider'),
                  height: 1,
                  color: _listDividerColor(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filled semantic delete-colored circle with a white check icon, sitting in the
/// top-right corner of the cover when the row is selected. Same visual
/// vocabulary as the grid tile's selection check so list/grid selection
/// reads identically.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('libraryListSelectionCheck'),
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const Icon(AppIcons.check, size: 10, color: Colors.white),
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
    return Text(' · ', style: _metaStyle(context, mutedColor));
  }
}

TextStyle _metaStyle(BuildContext context, Color color) =>
    context.text.sourceMetadata.copyWith(color: color);

Color _listDividerColor(BuildContext context) =>
    Color.lerp(context.appColors.divider, context.colors.onSurface, 0.12)!;

String? _subtitleFor(LibrarySource source) {
  final author = source.author?.trim();
  if (author != null && author.isNotEmpty) return author;
  if (source.sourceType == SourceType.article) {
    final sourceName = source.sourceName?.trim();
    if (sourceName != null && sourceName.isNotEmpty) return sourceName;
  }
  return null;
}

String? _secondarySourceName(LibrarySource source, String? subtitle) {
  if (source.sourceType != SourceType.article) return null;
  final sourceName = source.sourceName?.trim();
  if (sourceName == null || sourceName.isEmpty) return null;
  if (subtitle != null &&
      sourceName.toLowerCase() == subtitle.trim().toLowerCase()) {
    return null;
  }
  return sourceName;
}

IconData _sourceIcon(LibrarySource source) =>
    source.sourceType == SourceType.article ? AppIcons.article : AppIcons.book;

/// Builds the green ` ✓ Done` kicker that replaces the progress segment
/// when an item is fully read. Colour comes from the semantic
/// `successForeground` token so it stays legible in both themes.
List<Widget> _doneBadge(BuildContext context) {
  final success = context.appColors.successForeground;
  return [
    Icon(AppIcons.check, size: 10, color: success),
    const SizedBox(width: 2),
    Text(
      context.l10n.librarySourceDone,
      style: context.text.sourceMetadata.copyWith(
        fontWeight: FontWeight.w500,
        color: success,
      ),
    ),
  ];
}
