import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_import_entry.dart';

const double _iconFrameSize = 72;
const double _iconFrameAlpha = 0.12;
const double _buttonGap = AppSpacing.sm + AppSpacing.xxs;

/// First-run Library: what to add and the two ways to add it.
///
/// Applies the 16dp screen gutter once, like `EmptyState`.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.onImportPressed, super.key});

  /// Opens import at the given step; `null` disables both commands while an
  /// import flow is already open.
  final ValueChanged<LibraryImportEntry>? onImportPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;
    final onImportPressed = this.onImportPressed;
    final mutedStyle = text.bodySmall.copyWith(color: colors.onSurfaceVariant);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                key: const ValueKey('libraryEmptyIconFrame'),
                width: _iconFrameSize,
                height: _iconFrameSize,
                decoration: BoxDecoration(
                  color: context.actionForeground.withValues(
                    alpha: _iconFrameAlpha,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.book,
                  size: AppIconSize.lg,
                  color: context.actionForeground,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.libraryEmptyTitle,
              textAlign: TextAlign.center,
              style: text.headlineSmall.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.libraryEmptySubtitle,
              textAlign: TextAlign.center,
              style: mutedStyle,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              key: const ValueKey('libraryEmptyUploadFile'),
              onPressed: onImportPressed == null
                  ? null
                  : () => onImportPressed(LibraryImportEntry.file),
              icon: const Icon(AppIcons.uploadFile, size: AppIconSize.sm),
              label: AppButtonLabel(l10n.libraryUploadFile),
            ),
            const SizedBox(height: _buttonGap),
            OutlinedButton.icon(
              key: const ValueKey('libraryEmptySaveArticle'),
              onPressed: onImportPressed == null
                  ? null
                  : () => onImportPressed(LibraryImportEntry.article),
              icon: const Icon(AppIcons.link, size: AppIconSize.sm),
              label: AppButtonLabel(l10n.librarySaveArticleAction),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.importFileKinds,
              textAlign: TextAlign.center,
              style: mutedStyle,
            ),
          ],
        ),
      ),
    );
  }
}
