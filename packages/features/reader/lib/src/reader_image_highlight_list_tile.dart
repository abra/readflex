import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_highlight_color.dart';

/// Image areas are visual bookmarks, not quotes with clipboard actions.
class ReaderImageHighlightListTile extends StatelessWidget {
  const ReaderImageHighlightListTile({
    required this.highlight,
    required this.readerTheme,
    required this.expanded,
    required this.onExpanded,
    required this.onNavigate,
    this.preview,
    super.key,
  });

  final Highlight highlight;
  final ReaderThemeData readerTheme;
  final bool expanded;
  final VoidCallback onExpanded;
  final VoidCallback onNavigate;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final area = highlight.imageArea;
    final page = area != null && area.pageIndex >= 0
        ? context.l10n.readerPageNumber(area.pageIndex + 1)
        : context.l10n.readerLocationUnavailable;
    final title = highlight.chapterTitle?.trim();
    final hasTitle = title != null && title.isNotEmpty && title != page;
    final note = highlight.note?.trim();
    final canNavigate = area != null && area.pageIndex >= 0;
    final titleDirection = hasTitle && Bidi.detectRtlDirectionality(title)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final noteDirection = note != null && Bidi.detectRtlDirectionality(note)
        ? TextDirection.rtl
        : TextDirection.ltr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: canNavigate,
          hint: canNavigate ? context.l10n.readerGoToPassage : null,
          child: InkWell(
            onTap: canNavigate ? onNavigate : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                                  color: context.colors.onSurfaceVariant,
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
                              hasTitle ? title : page,
                              textDirection: hasTitle ? titleDirection : null,
                              style: context.text.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasTitle) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                page,
                                style: context.text.bodySmall.copyWith(
                                  color: context.colors.onSurfaceVariant,
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
                        final style = context.text.bodyMedium;
                        final painter = TextPainter(
                          text: TextSpan(text: note, style: style),
                          textDirection: noteDirection,
                          textScaler: MediaQuery.textScalerOf(context),
                          locale: Localizations.localeOf(context),
                          maxLines: 3,
                        )..layout(maxWidth: constraints.maxWidth);
                        final canExpand = painter.didExceedMaxLines;
                        painter.dispose();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note,
                              style: style,
                              textDirection: noteDirection,
                              maxLines: expanded ? null : 3,
                              overflow: expanded ? null : TextOverflow.ellipsis,
                            ),
                            if (canExpand)
                              TextButton(
                                onPressed: onExpanded,
                                child: Text(
                                  expanded
                                      ? context.l10n.readerCollapseHighlight
                                      : context.l10n.readerExpandHighlight,
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
