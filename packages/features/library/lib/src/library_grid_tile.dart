import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_selection_tint.dart';
import 'library_source_semantics.dart';

const double _kNewBadgeHeight = 20.0;
const double _kProgressOverlayReserve = 16.0;
const double _kProgressOverlayInset = AppSpacing.xxs;
const _kProgressFillAnimationCurve = Curves.easeOutCubic;

/// Grid-mode tile for a library source.
///
/// Cover-only: 2:3 aspect ratio with optional New/finished badges and a
/// slim progress bar overlay. Tap target spans the whole cover. Width is
/// decided by the enclosing grid delegate. The file format stays in list
/// rows and semantics, not on the artwork.
class BookLibraryGridTile extends StatelessWidget {
  const BookLibraryGridTile({
    required this.source,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
    super.key,
  });

  final LibrarySource source;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final coverImage = appSourceCoverImageFromPath(source.coverImagePath);
    final isArticle = source.sourceType == SourceType.article;
    final hasReadingActivity =
        source.lastOpenedAt != null || source.readingProgress > 0;
    final showsProgressOverlay = hasReadingActivity && !source.isFinished;
    // Same predicate as the New filter.
    final showsNewBadge = source.isNew;
    final coverTextDirection = _sourceTextDirection(source);
    // Badges are chrome: they follow the layout, not the cover's text.
    final layoutDirection = Directionality.of(context);
    final l10n = context.l10n;
    // Generated cover text keeps clear of the New pill, which grows with the
    // text scale beyond its 20dp minimum.
    final newBadgeReserve = showsNewBadge
        ? AppSpacing.xs * 2 +
              _newBadgeHeight(
                MediaQuery.textScalerOf(context),
                context.text.labelSmall,
              )
        : 0.0;

    return _GridTileShell(
      sourceId: source.id,
      cover: AppSourceCover(
        title: source.title,
        author: source.author,
        source: source.sourceName,
        seed: source.id,
        isArticle: isArticle,
        coverImage: coverImage,
        textDirection: coverTextDirection,
        progress: source.readingProgress > 0 ? source.readingProgress : null,
        // Show the title on the fallback cover art so any format
        // that doesn't ship an embedded cover (a CBZ without a
        // cover image, an EPUB stripped to text-only, etc.) stays
        // identifiable by name. AppSourceCover only honours this on
        // the fallback path — when a real cover image is present,
        // the image takes over and the title stays off.
        showTitle: true,
        showAuthor: !isArticle,
        showProgress: false,
        // The shared frame owns cover edges; AppCoverArt's matte would add
        // a white inner border around generated article covers.
        showMatte: false,
        centerText: isArticle,
        topAlignText: !isArticle && showsProgressOverlay,
        topReserve: newBadgeReserve,
        bottomReserve: showsProgressOverlay ? _kProgressOverlayReserve : 0,
        // The article icon keeps the top-end corner; New owns top-start.
        articleBadgeAlignment: AlignmentDirectional.topEnd.resolve(
          layoutDirection,
        ),
      ),
      isFinished: source.isFinished,
      progress: source.readingProgress,
      showProgress: showsProgressOverlay,
      newLabel: showsNewBadge ? l10n.librarySourceNew : null,
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
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

double _newBadgeHeight(TextScaler textScaler, TextStyle style) {
  final lineHeight = textScaler.scale(style.fontSize!) * (style.height ?? 1);
  return lineHeight > _kNewBadgeHeight ? lineHeight : _kNewBadgeHeight;
}

TextDirection _sourceTextDirection(LibrarySource source) {
  return switch (source.inferredTextDirection) {
    ArticleTextDirection.rtl => TextDirection.rtl,
    ArticleTextDirection.ltr || null => TextDirection.ltr,
  };
}

/// Layout scaffold for the grid-mode tile. Owns the geometry —
/// cover aspect ratio, badge placement, progress overlay.
class _GridTileShell extends StatelessWidget {
  const _GridTileShell({
    required this.sourceId,
    required this.cover,
    required this.isFinished,
    required this.progress,
    required this.showProgress,
    required this.isSelected,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.reportsSelectedState,
    required this.tapHint,
    required this.longPressHint,
    required this.onTap,
    this.onLongPress,
    this.newLabel,
  });

  final String sourceId;
  final Widget cover;
  final bool isFinished;
  final double progress;
  final bool showProgress;
  final bool isSelected;
  final String semanticsLabel;
  final String semanticsValue;
  final bool reportsSelectedState;
  final String tapHint;
  final String? longPressHint;
  final String? newLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectionColor = colors.selectionMarkerBackground;
    final selectionTint = selectionColor.withValues(
      alpha: kLibraryCoverSelectionTintAlpha,
    );

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
        child: AnimatedScale(
          // Subtle press-in cue when selected — same idea as iOS Photos
          // multi-select: tile shrinks slightly so the unselected siblings
          // visually "stay in place" when a checkmark appears.
          scale: isSelected ? 0.92 : 1.0,
          duration: context.motion(AppMotion.quick),
          curve: Curves.easeOut,
          child: AppSourceCoverFrame(
            cover: cover,
            overlays: [
              if (newLabel != null)
                PositionedDirectional(
                  top: AppSpacing.xs,
                  start: AppSpacing.xs,
                  child: _NewBadge(label: newLabel!),
                ),
              if (isFinished)
                const PositionedDirectional(
                  top: AppSpacing.xs,
                  end: AppSpacing.xs,
                  child: _FinishedBadge(),
                ),
              if (isSelected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        appSourceCoverRadius,
                      ),
                      border: Border.all(color: selectionColor, width: 3),
                      color: selectionTint,
                    ),
                  ),
                ),
              if (isSelected)
                PositionedDirectional(
                  top: AppSpacing.xs,
                  end: AppSpacing.xs,
                  child: _SelectionCheck(color: selectionColor),
                ),
              if (showProgress && !isFinished) ...[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(
                          appSourceCoverRadius - 2,
                        ),
                        bottomRight: Radius.circular(
                          appSourceCoverRadius - 2,
                        ),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.0, 0.20],
                        colors: [
                          appSourceCoverScrimColor,
                          appSourceCoverScrimColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _kProgressOverlayInset,
                  right: _kProgressOverlayInset,
                  bottom: _kProgressOverlayInset,
                  child: LayoutBuilder(
                    builder: (_, constraints) => ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: SizedBox(
                        key: const Key('libraryGridProgressBar'),
                        height: 3,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.50),
                              ),
                            ),
                            AnimatedContainer(
                              key: const Key('libraryGridProgressFill'),
                              duration: context.motion(AppMotion.short),
                              curve: _kProgressFillAnimationCurve,
                              width:
                                  constraints.maxWidth *
                                  progress.clamp(0.0, 1.0).toDouble(),
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Surface pill in the cover's top-start corner for never-opened sources.
class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('libraryGridNewBadge'),
      constraints: const BoxConstraints(minHeight: _kNewBadgeHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.text.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: context.actionForeground,
        ),
      ),
    );
  }
}

/// Filled circle with a checkmark, sitting in the top-end corner of a
/// selected grid tile. Same 20×20 footprint as [_FinishedBadge] so a
/// selection state replaces the finished badge in the same slot.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(
        AppIcons.check,
        size: 11,
        color: context.colors.selectionMarkerForeground,
      ),
    );
  }
}

/// Small green check badge in the cover corner indicating the item has
/// been read through to the end.
class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    // 20x20 disc with an 11px check; the filled success pair matches toasts.
    final appColors = context.appColors;
    return Container(
      key: const ValueKey('libraryGridFinishedBadge'),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: appColors.successContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIcons.check,
        size: 11,
        color: appColors.onSuccessContainer,
      ),
    );
  }
}
