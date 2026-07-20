import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Confirmation bottom sheet shown before deleting a library item.
///
/// The sheet returns one of:
///   * `null` — user cancelled (Cancel button, scrim tap, system back).
///   * [BookDeletionScope.keepLearningData] — user confirmed deletion.
///
/// Wording is count-aware: `count == 1` shows the singular phrasing,
/// `count > 1` shows the plural with the actual number.
Future<BookDeletionScope?> showConfirmBookDeletionSheet(
  BuildContext context, {
  required int count,
}) {
  return showAppBottomSheet<BookDeletionScope>(
    context,
    builder: (_) => _ConfirmBookDeletionSheet(count: count),
  );
}

class _ConfirmBookDeletionSheet extends StatelessWidget {
  const _ConfirmBookDeletionSheet({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return ActionBottomSheetLayout(
      title: l10n.libraryDeleteItemsTitle(count),
      bodyPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.libraryDeleteItemsBody(count),
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: AppButtonLabel(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(BookDeletionScope.keepLearningData),
                  child: AppButtonLabel(l10n.commonDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
