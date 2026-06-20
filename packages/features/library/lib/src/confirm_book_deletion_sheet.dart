import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

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
    final isSingle = count == 1;
    final title = isSingle ? 'Delete this item?' : 'Delete $count items?';
    final itemLabel = isSingle ? 'item' : 'items';
    final body =
        'This removes the library $itemLabel and your highlights. '
        'Archived learning data is kept.';

    return ActionBottomSheetLayout(
      title: title,
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
          Text(body, style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
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
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
