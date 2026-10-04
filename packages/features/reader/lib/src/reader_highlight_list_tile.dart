import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_directional_layout.dart';
import 'reader_highlight_color.dart';
import 'reader_highlight_location_label.dart';
import 'reader_image_highlight_list_tile.dart';

/// A saved passage opens on row tap; expansion never changes reading position.
class ReaderHighlightListTile extends StatelessWidget {
  const ReaderHighlightListTile({
    required this.highlight,
    required this.readerTheme,
    required this.pageProgressionRtl,
    required this.expanded,
    required this.onExpanded,
    required this.onNavigate,
    this.imagePreview,
    super.key,
  });

  final Highlight highlight;
  final ReaderThemeData readerTheme;
  final bool pageProgressionRtl;
  final bool expanded;
  final VoidCallback onExpanded;
  final VoidCallback onNavigate;
  final Widget? imagePreview;

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
      );
    }
    final l10n = context.l10n;
    final note = highlight.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final text = highlight.text.trim();
    final quote = text.isEmpty ? l10n.readerHighlightedText : text;
    final hasLocation = readerHighlightHasNavigableLocation(highlight);
    final location = readerHighlightLocationLabel(
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
    final style = context.text.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: hasLocation,
          hint: hasLocation ? l10n.readerGoToPassage : null,
          child: InkWell(
            onTap: hasLocation ? onNavigate : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Only materialized list rows are measured. Use the actual width,
                      // font and scaler, not a character-count approximation of truncation.
                      final painter =
                          TextPainter(
                            text: TextSpan(text: quote, style: style),
                            textDirection: direction,
                            textScaler: MediaQuery.textScalerOf(context),
                            locale: Localizations.localeOf(context),
                            maxLines: 3,
                          )..layout(
                            maxWidth: (constraints.maxWidth - AppSpacing.md - 3)
                                .clamp(
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
                        )..layout(maxWidth: constraints.maxWidth);
                        canExpand |= notePainter.didExceedMaxLines;
                        notePainter.dispose();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Directionality(
                            textDirection: direction,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: BorderDirectional(
                                  start: BorderSide(
                                    width: 3,
                                    color: readerHighlightColor(
                                      highlight.color,
                                      readerTheme,
                                    ),
                                  ),
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
                                  overflow: expanded
                                      ? null
                                      : TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          if (hasNote)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                note,
                                style: context.text.bodySmall,
                                textDirection: noteDirection,
                                textAlign: TextAlign.start,
                                maxLines: expanded ? null : 2,
                                overflow: expanded
                                    ? null
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                          if (canExpand)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: onExpanded,
                                child: Text(
                                  expanded
                                      ? l10n.readerCollapseHighlight
                                      : l10n.readerExpandHighlight,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (location != null || !hasLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        [
                          ?location,
                          if (!hasLocation) l10n.readerLocationUnavailable,
                        ].join(' · '),
                        style: context.text.bodySmall.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textDirection: direction,
                        textAlign: align,
                      ),
                    ),
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
