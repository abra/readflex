import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_drawer_layout.dart';
import 'reader_highlight_footer.dart';
import 'reader_highlight_note_row.dart';
import 'reader_highlight_quote_text.dart';

const _previewSize = 96.0;
const _noteMaxLines = 3;

/// Image areas are visual bookmarks, not quotes with clipboard actions.
///
/// The stored chapter title of an image page is an archive file name, so the
/// localized page label is always the primary line. A [removed] row is inert
/// apart from its Undo action.
class ReaderImageHighlightListTile extends StatelessWidget {
  const ReaderImageHighlightListTile({
    required this.highlight,
    required this.readerTheme,
    required this.expanded,
    required this.onExpanded,
    required this.onNavigate,
    this.preview,
    this.removed = false,
    this.failed = false,
    this.onUndo,
    super.key,
  });

  final Highlight highlight;
  final ReaderThemeData readerTheme;
  final bool expanded;
  final VoidCallback onExpanded;
  final VoidCallback onNavigate;
  final Widget? preview;
  final bool removed;
  final bool failed;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final area = highlight.imageArea;
    final page = area != null && area.pageIndex >= 0
        ? l10n.readerPageNumber(area.pageIndex + 1)
        : l10n.readerLocationUnavailable;
    final note = highlight.note?.trim();
    final canNavigate = !removed && area != null && area.pageIndex >= 0;
    final noteDirection = note != null && Bidi.detectRtlDirectionality(note)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final status = removed
        ? [
            l10n.readerHighlightRemoved,
            if (failed) l10n.readerHighlightSaveFailed,
          ].join(' · ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: canNavigate,
          hint: canNavigate ? l10n.readerGoToPassage : null,
          child: InkWell(
            onTap: canNavigate ? onNavigate : null,
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
                    child: _ReaderImageHighlightTileBody(
                      page: page,
                      status: status,
                      note: note != null && note.isNotEmpty ? note : null,
                      noteDirection: noteDirection,
                      color: highlight.color,
                      readerTheme: readerTheme,
                      preview: preview,
                      removed: removed,
                      expanded: expanded,
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

/// Preview beside the highlighted page label, then the note and, when the
/// note is clipped, Read more at the end of its own row.
class _ReaderImageHighlightTileBody extends StatelessWidget {
  const _ReaderImageHighlightTileBody({
    required this.page,
    required this.status,
    required this.note,
    required this.noteDirection,
    required this.color,
    required this.readerTheme,
    required this.preview,
    required this.removed,
    required this.expanded,
    required this.onExpanded,
  });

  final String page;
  final String? status;
  final String? note;
  final TextDirection noteDirection;
  final HighlightColor color;
  final ReaderThemeData readerTheme;
  final Widget? preview;
  final bool removed;
  final bool expanded;
  final VoidCallback onExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mutedColor = colors.onSurfaceVariant;
    final note = this.note;
    final status = this.status;
    // A removed row ends at its Undo target, which supplies the spacing.
    final endGutter = removed ? 0.0 : AppSpacing.lg;
    final gutters = EdgeInsetsDirectional.only(
      start: AppSpacing.lg,
      end: endGutter,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var canExpand = false;
        if (note != null && !removed) {
          final painter =
              TextPainter(
                text: TextSpan(text: note, style: context.text.bodySmall),
                textDirection: noteDirection,
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.localeOf(context),
                maxLines: _noteMaxLines,
              )..layout(
                maxWidth:
                    (constraints.maxWidth -
                            AppSpacing.lg -
                            endGutter -
                            readerHighlightNoteIndent)
                        .clamp(0.0, double.infinity),
              );
          canExpand = painter.didExceedMaxLines;
          painter.dispose();
        }
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
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: _previewSize,
                      child:
                          preview ??
                          Icon(
                            AppIcons.book,
                            size: AppIconSize.md,
                            color: mutedColor,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReaderHighlightQuoteText(
                            page,
                            color: color,
                            readerTheme: readerTheme,
                            style: context.text.bodyMedium.copyWith(
                              color: removed ? mutedColor : null,
                            ),
                            maxLines: 3,
                          ),
                          if (status != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              status,
                              style: context.text.bodySmall.copyWith(
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (note != null)
                Padding(
                  padding: gutters.add(
                    const EdgeInsets.only(top: AppSpacing.md),
                  ),
                  child: ReaderHighlightNoteRow(
                    note: note,
                    textDirection: noteDirection,
                    maxLines: expanded ? null : _noteMaxLines,
                    muted: removed,
                  ),
                ),
              if (canExpand)
                ReaderHighlightFooter(
                  location: null,
                  canExpand: true,
                  expanded: expanded,
                  onExpanded: onExpanded,
                ),
            ],
          ),
        );
      },
    );
  }
}
