import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_drawer_layout.dart';
import 'reader_highlight_color.dart';

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
    final colors = context.colors;
    final area = highlight.imageArea;
    final page = area != null && area.pageIndex >= 0
        ? l10n.readerPageNumber(area.pageIndex + 1)
        : l10n.readerLocationUnavailable;
    final note = highlight.note?.trim();
    final canNavigate = !removed && area != null && area.pageIndex >= 0;
    final noteDirection = note != null && Bidi.detectRtlDirectionality(note)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final mutedColor = colors.onSurfaceVariant;
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
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.lg,
                removed ? readerDrawerActionEndPadding : AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            DecoratedBox(
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
                                  start: AppSpacing.sm,
                                ),
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child:
                                      preview ??
                                      Icon(
                                        AppIcons.book,
                                        size: AppIconSize.md,
                                        color: mutedColor,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    page,
                                    style: context.text.bodyMedium.copyWith(
                                      color: removed ? mutedColor : null,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
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
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final style = context.text.bodyMedium.copyWith(
                                color: removed ? mutedColor : null,
                              );
                              final painter = TextPainter(
                                text: TextSpan(text: note, style: style),
                                textDirection: noteDirection,
                                textScaler: MediaQuery.textScalerOf(context),
                                locale: Localizations.localeOf(context),
                                maxLines: 3,
                              )..layout(maxWidth: constraints.maxWidth);
                              final canExpand =
                                  !removed && painter.didExceedMaxLines;
                              painter.dispose();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note,
                                    style: style,
                                    textDirection: noteDirection,
                                    maxLines: expanded ? null : 3,
                                    overflow: expanded
                                        ? null
                                        : TextOverflow.ellipsis,
                                  ),
                                  if (canExpand)
                                    TextButton(
                                      onPressed: onExpanded,
                                      child: Text(
                                        expanded
                                            ? l10n.readerCollapseHighlight
                                            : l10n.readerExpandHighlight,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
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
