import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_import_entry.dart';

/// First-run Library: what to add and the two ways to add it, in the shared
/// first-run frame that Practice uses too.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.onImportPressed, super.key});

  /// Opens import at the given step; `null` disables both commands while an
  /// import flow is already open.
  final ValueChanged<LibraryImportEntry>? onImportPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onImportPressed = this.onImportPressed;
    return AppFirstRunState(
      iconFrameKey: const ValueKey('libraryEmptyIconFrame'),
      icon: AppIcons.book,
      title: l10n.libraryEmptyTitle,
      subtitle: l10n.libraryEmptySubtitle,
      actions: [
        FilledButton.icon(
          key: const ValueKey('libraryEmptyUploadFile'),
          onPressed: onImportPressed == null
              ? null
              : () => onImportPressed(LibraryImportEntry.file),
          icon: const Icon(AppIcons.uploadFile, size: AppIconSize.sm),
          label: AppButtonLabel(l10n.libraryUploadFile),
        ),
        OutlinedButton.icon(
          key: const ValueKey('libraryEmptySaveArticle'),
          onPressed: onImportPressed == null
              ? null
              : () => onImportPressed(LibraryImportEntry.article),
          icon: const Icon(AppIcons.link, size: AppIconSize.sm),
          label: AppButtonLabel(l10n.librarySaveArticleAction),
        ),
      ],
      caption: l10n.importFileKinds,
    );
  }
}
