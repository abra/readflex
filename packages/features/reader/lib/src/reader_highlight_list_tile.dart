import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_directional_layout.dart';
import 'reader_drawer_layout.dart';
import 'reader_highlight_footer.dart';
import 'reader_highlight_location_label.dart';
import 'reader_highlight_note_row.dart';
import 'reader_highlight_quote_text.dart';
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
      color: removed ? context.colors.onSurfaceVariant : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: hasLocation,
          hint: hasLocation ? l10n.readerGoToPassage : null,
          child: InkWell(
            onTap: hasLocation ? onNavigate : null,
            // The body owns both gutters so Read more can bleed its ink into
            // the trailing one; a removed row ends on its Undo target instead.
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                top: AppSpacing.lg,
                end: removed ? readerDrawerActionEndPadding : 0,
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
                      color: highlight.color,
                      readerTheme: readerTheme,
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
    required this.readerTheme,
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
  final HighlightColor color;
  final ReaderThemeData readerTheme;
  final VoidCallback onExpanded;

  static const _quoteMaxLines = 3;
  static const _noteMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = this.note;
    // A removed row ends at its Undo target, which supplies the spacing.
    final endGutter = removed ? 0.0 : AppSpacing.lg;
    final gutters = EdgeInsetsDirectional.only(
      start: AppSpacing.lg,
      end: endGutter,
    );
    final locationText = location != null || !hasLocation
        ? [
            ?location,
            if (!hasLocation && !removed) l10n.readerLocationUnavailable,
          ].join(' · ')
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Removed rows are inert apart from Undo, so they skip measuring.
        // Otherwise only materialized rows are measured, with the actual
        // width, font and scaler rather than a character-count estimate.
        var canExpand = false;
        if (!removed) {
          final quoteWidth = (constraints.maxWidth - AppSpacing.lg - endGutter)
              .clamp(0.0, double.infinity);
          final painter = TextPainter(
            text: TextSpan(text: quote, style: style),
            textDirection: direction,
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.localeOf(context),
            maxLines: _quoteMaxLines,
          )..layout(maxWidth: quoteWidth);
          canExpand = painter.didExceedMaxLines;
          painter.dispose();
          if (note != null) {
            final notePainter =
                TextPainter(
                  text: TextSpan(text: note, style: context.text.bodySmall),
                  textDirection: noteDirection,
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.localeOf(context),
                  maxLines: _noteMaxLines,
                )..layout(
                  maxWidth: (quoteWidth - readerHighlightNoteIndent).clamp(
                    0.0,
                    double.infinity,
                  ),
                );
            canExpand |= notePainter.didExceedMaxLines;
            notePainter.dispose();
          }
        }
        final hasFooter = locationText != null || canExpand;
        return Padding(
          // The 48dp button carries its own space below the label.
          padding: EdgeInsets.only(
            bottom: canExpand ? AppSpacing.xs : AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: gutters,
                child: ReaderHighlightQuoteText(
                  quote,
                  color: color,
                  readerTheme: readerTheme,
                  style: style,
                  textDirection: direction,
                  textAlign: align,
                  maxLines: expanded ? null : _quoteMaxLines,
                ),
              ),
              if (note != null)
                Padding(
                  padding: gutters.add(
                    const EdgeInsets.only(top: AppSpacing.sm),
                  ),
                  child: ReaderHighlightNoteRow(
                    note: note,
                    textDirection: noteDirection,
                    maxLines: expanded ? null : _noteMaxLines,
                    muted: removed,
                  ),
                ),
              if (hasFooter)
                Padding(
                  padding: EdgeInsets.only(
                    top: canExpand ? 0 : AppSpacing.sm,
                  ),
                  child: ReaderHighlightFooter(
                    location: locationText,
                    locationDirection: removed ? null : direction,
                    canExpand: canExpand,
                    expanded: expanded,
                    onExpanded: onExpanded,
                    endGutter: endGutter,
                    maxButtonWidth: constraints.maxWidth / 2,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
