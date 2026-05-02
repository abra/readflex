import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Confirmation bottom sheet shown before any book deletion.
///
/// The sheet returns one of:
///   * `null` — user cancelled (close button, scrim tap, system back).
///   * [BookDeletionScope.keepLearningData] — checkbox unchecked.
///   * [BookDeletionScope.deleteEverything] — checkbox checked.
///
/// Wording is count-aware: `count == 1` shows the singular phrasing
/// ("Delete this book?"), `count > 1` shows the plural with the actual
/// number ("Delete 3 books?").
Future<BookDeletionScope?> showConfirmBookDeletionSheet(
  BuildContext context, {
  required int count,
}) {
  return showAppBottomSheet<BookDeletionScope>(
    context,
    builder: (_) => _ConfirmBookDeletionSheet(count: count),
  );
}

class _ConfirmBookDeletionSheet extends StatefulWidget {
  const _ConfirmBookDeletionSheet({required this.count});

  final int count;

  @override
  State<_ConfirmBookDeletionSheet> createState() =>
      _ConfirmBookDeletionSheetState();
}

class _ConfirmBookDeletionSheetState extends State<_ConfirmBookDeletionSheet> {
  bool _alsoDeleteLearningData = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSingle = widget.count == 1;
    final title = isSingle
        ? 'Delete this book?'
        : 'Delete ${widget.count} books?';
    final body = isSingle
        ? 'This removes the book file and your highlights. '
              'Saved words and flashcards stay in your library.'
        : 'This removes the book files and your highlights. '
              'Saved words and flashcards stay in your library.';

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
          const SizedBox(height: AppSpacing.md),
          // Opt-in to the destructive cascade. Default = keep learning
          // data, since "I deleted my last book and lost my whole
          // vocabulary" is a worse failure mode than leftover orphan rows.
          InkWell(
            onTap: () => setState(
              () => _alsoDeleteLearningData = !_alsoDeleteLearningData,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Checkbox(
                    value: _alsoDeleteLearningData,
                    onChanged: (v) => setState(
                      () => _alsoDeleteLearningData = v ?? false,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Also delete saved words and flashcards',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  onPressed: () => Navigator.of(context).pop(
                    _alsoDeleteLearningData
                        ? BookDeletionScope.deleteEverything
                        : BookDeletionScope.keepLearningData,
                  ),
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
