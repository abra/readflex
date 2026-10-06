import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader_webview/reader_webview.dart';

import 'reader_directional_layout.dart';

class ReaderSearchResultTile extends StatelessWidget {
  const ReaderSearchResultTile({
    required this.result,
    required this.pageProgressionRtl,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final ReaderSearchResult result;
  final bool pageProgressionRtl;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chapterTitle = result.chapterTitle;

    return ListTile(
      selected: selected,
      selectedTileColor: colors.selectedControlBackground,
      // Full-bleed active row, like the Chapters tab; no themed tile radius.
      shape: const RoundedRectangleBorder(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      title: Text(
        chapterTitle == null || chapterTitle.isEmpty
            ? context.l10n.readerSearchResult
            : chapterTitle,
        textAlign: readerDirectionalTextAlign(
          pageProgressionRtl: pageProgressionRtl,
        ),
        textDirection: readerDirectionalTextDirection(
          pageProgressionRtl: pageProgressionRtl,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall.copyWith(
          color: selected
              ? colors.selectedControlForeground
              : colors.onSurfaceVariant,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: RichText(
          textScaler: MediaQuery.textScalerOf(context),
          textAlign: readerDirectionalTextAlign(
            pageProgressionRtl: pageProgressionRtl,
          ),
          textDirection: readerDirectionalTextDirection(
            pageProgressionRtl: pageProgressionRtl,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: context.text.bodyMedium.copyWith(
              color: selected
                  ? colors.selectedControlForeground
                  : colors.onSurface,
            ),
            children: [
              TextSpan(text: result.excerpt.pre),
              TextSpan(
                text: result.excerpt.match,
                style: context.text.bodyMedium.copyWith(
                  color: selected
                      ? colors.selectedControlForeground
                      : context.actionForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: result.excerpt.post),
            ],
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
