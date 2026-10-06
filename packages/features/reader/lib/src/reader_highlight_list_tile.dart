import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_directional_layout.dart';
import 'reader_drawer_layout.dart';
import 'reader_highlight_color.dart';
import 'reader_highlight_expand_button.dart';
import 'reader_highlight_location_label.dart';
import 'reader_image_highlight_list_tile.dart';

/// A saved passage opens on row tap; expansion never changes reading position.
///
/// A [removed] row keeps its place with a "Highlight removed" status and an
/// icon-only Undo until Contents closes; it neither navigates nor expands.
class ReaderHighlightListTile extends StatelessWidget {
  const ReaderHighlightListTile({
    required this.highlight,
    required this.readerTheme,
    required this.pageProgressionRtl,
    required this.expanded,
    required this.onExpanded,
    required this.onNavigate,
    this.imagePreview,
    this.removed = false,
    this.failed = false,
    this.onUndo,
    super.key,
  });

  final Highlight highlight;
  final ReaderThemeData readerTheme;
  final bool pageProgressionRtl;
  final bool expanded;
  final VoidCallback onExpanded;
  final VoidCallback onNavigate;
  final Widget? imagePreview;
  final bool removed;
  final bool failed;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    if (highlight.kind == HighlightKind.imageArea) {
      return ReaderImageHighlightListTile(
        highlight: highlight,
        readerTheme: readerTheme,
        expanded: expanded,
        onExpanded: onExpanded,
        onNavigate: onNavigate,
        preview: imagePreview,
        removed: removed,
        failed: failed,
        onUndo: onUndo,
      );
    }
    final l10n = context.l10n;
    final mutedColor = context.colors.onSurfaceVariant;
    final note = highlight.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final text = highlight.text.trim();
    final quote = text.isEmpty ? l10n.readerHighlightedText : text;
    final hasLocation =
        !removed && readerHighlightHasNavigableLocation(highlight);
    final location = removed
        ? [
            l10n.readerHighlightRemoved,
            if (failed) l10n.readerHighlightSaveFailed,
          ].join(' · ')
        : readerHighlightLocationLabel(
            highlight,
            formatPage: l10n.readerPageNumber,
          );
    final noteDirection = hasNote && Bidi.detectRtlDirectionality(note)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final direction = readerDirectionalTextDirection(
      pageProgressionRtl: pageProgressionRtl,
    );
    final align = readerDirectionalTextAlign(
      pageProgressionRtl: pageProgressionRtl,
    );
    final style = context.text.bodyMedium.copyWith(
      color: removed ? mutedColor : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: hasLocation,
          hint: hasLocation ? l10n.readerGoToPassage : null,
          child: InkWell(
            onTap: hasLocation ? onNavigate : null,
            // The body owns the leading gutter so Read more can bleed its
            // ink into it.
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                0,
                AppSpacing.lg,
                removed ? readerDrawerActionEndPadding : AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ReaderHighlightTileBody(
                      quote: quote,
                      note: hasNote ? note : null,
                      location: location,
                      hasLocation: hasLocation,
                      removed: removed,
                      expanded: expanded,
                      style: style,
                      direction: direction,
                      align: align,
                      noteDirection: noteDirection,
                      color: readerHighlightColor(
                        highlight.color,
                        readerTheme,
                      ),
                      mutedColor: mutedColor,
                      onExpanded: onExpanded,
                    ),
                  ),
                  if (removed) ...[
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox.square(
                      dimension: AppSizes.buttonHeight,
                      child: AppPlainIconButton(
                        tooltip: l10n.commonUndo,
                        icon: AppIcons.undo,
                        color: context.actionForeground,
                        onPressed: onUndo,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Divider(height: 1),
        ),
      ],
    );
  }
}

class _ReaderHighlightTileBody extends StatelessWidget {
  const _ReaderHighlightTileBody({
    required this.quote,
    required this.note,
    required this.location,
    required this.hasLocation,
    required this.removed,
    required this.expanded,
    required this.style,
    required this.direction,
    required this.align,
    required this.noteDirection,
    required this.color,
    required this.mutedColor,
    required this.onExpanded,
  });

  final String quote;
  final String? note;
  final String? location;
  final bool hasLocation;
  final bool removed;
  final bool expanded;
  final TextStyle style;
  final TextDirection direction;
  final TextAlign align;
  final TextDirection noteDirection;
  final Color color;
  final Color mutedColor;
  final VoidCallback onExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = this.note;
    final hasNote = note != null;
    const gutter = EdgeInsetsDirectional.only(start: AppSpacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Only materialized list rows are measured. Use the actual width,
            // font and scaler, not a character-count approximation of truncation.
            final textWidth = (constraints.maxWidth - AppSpacing.lg).clamp(
              0.0,
              double.infinity,
            );
            final painter =
                TextPainter(
                  text: TextSpan(text: quote, style: style),
                  textDirection: direction,
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.localeOf(context),
                  maxLines: 3,
                )..layout(
                  maxWidth: (textWidth - AppSpacing.md - 3).clamp(
                    0,
                    double.infinity,
                  ),
                );
            var canExpand = painter.didExceedMaxLines;
            painter.dispose();
            if (hasNote) {
              final notePainter = TextPainter(
                text: TextSpan(
                  text: note,
                  style: context.text.bodySmall,
                ),
                textDirection: noteDirection,
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.localeOf(context),
                maxLines: 2,
              )..layout(maxWidth: textWidth);
              canExpand |= notePainter.didExceedMaxLines;
              notePainter.dispose();
            }
            // Removed rows are inert apart from Undo.
            canExpand &= !removed;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: gutter,
                  child: Directionality(
                    textDirection: direction,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(width: 3, color: color),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.md,
                        ),
                        child: Text(
                          quote,
                          style: style,
                          textDirection: direction,
                          textAlign: align,
                          maxLines: expanded ? null : 3,
                          overflow: expanded ? null : TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasNote)
                  Padding(
                    padding: gutter.add(
                      const EdgeInsets.only(top: AppSpacing.sm),
                    ),
                    child: Text(
                      note,
                      style: context.text.bodySmall.copyWith(
                        color: removed ? mutedColor : null,
                      ),
                      textDirection: noteDirection,
                      textAlign: TextAlign.start,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                if (canExpand)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ReaderHighlightExpandButton(
                      expanded: expanded,
                      onPressed: onExpanded,
                    ),
                  ),
              ],
            );
          },
        ),
        if (location != null || !hasLocation)
          Padding(
            padding: gutter.add(const EdgeInsets.only(top: AppSpacing.sm)),
            child: Text(
              [
                ?location,
                if (!hasLocation && !removed) l10n.readerLocationUnavailable,
              ].join(' · '),
              style: context.text.bodySmall.copyWith(
                color: mutedColor,
              ),
              textDirection: direction,
              textAlign: align,
            ),
          ),
      ],
    );
  }
}
