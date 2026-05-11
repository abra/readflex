import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Confirmation bottom sheet shown before swipe / multi-select delete.
///
/// Returns:
///   * `true`  — user pressed Delete.
///   * `null`  — user cancelled (Cancel button, scrim tap, system back).
///
/// Wording is count-aware: `count == 1` shows the singular phrasing,
/// `count > 1` shows the plural with the actual number.
Future<bool?> showConfirmDictionaryDeletionSheet(
  BuildContext context, {
  required int count,
}) {
  return showAppBottomSheet<bool>(
    context,
    builder: (_) => _ConfirmDictionaryDeletionSheet(count: count),
  );
}

class _ConfirmDictionaryDeletionSheet extends StatelessWidget {
  const _ConfirmDictionaryDeletionSheet({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSingle = count == 1;
    final title = isSingle ? 'Delete this word?' : 'Delete $count words?';
    final body = isSingle
        ? 'The saved entry and its review progress will be removed. '
              'This cannot be undone.'
        : 'The saved entries and their review progress will be removed. '
              'This cannot be undone.';

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
                  onPressed: () => Navigator.of(context).pop(true),
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
