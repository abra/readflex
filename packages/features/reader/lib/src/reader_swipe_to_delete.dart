import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

/// End-to-start swipe that deletes one drawer row, like the Library list.
///
/// A swipe cannot be performed with a screen reader, so the same delete is
/// also a custom semantics action named [label]. A null [onDelete] (the row's
/// own write is in flight) springs a swipe back and drops the action.
///
/// With [collapse] the row shrinks away before [onDelete] runs, for lists that
/// drop it. Otherwise the owner replaces the row in place once its write lands
/// (bookmark Undo), so the swipe calls [onDelete] and springs back rather than
/// waiting aside: a failed or queued write then leaves an ordinary row.
class ReaderSwipeToDelete extends StatelessWidget {
  const ReaderSwipeToDelete({
    required this.id,
    required this.label,
    required this.onDelete,
    required this.child,
    this.collapse = false,
    super.key,
  });

  final Object id;
  final String label;
  final VoidCallback? onDelete;
  final bool collapse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onDelete = this.onDelete;
    return Semantics(
      customSemanticsActions: onDelete == null
          ? null
          : {CustomSemanticsAction(label: label): onDelete},
      child: Dismissible(
        key: ValueKey(id),
        direction: DismissDirection.endToStart,
        movementDuration: context.motion(AppMotion.short),
        // A zero resize would finish before Dismissible starts listening;
        // reduced motion removes the row without resizing instead.
        resizeDuration: collapse && !context.reduceMotion
            ? AppMotion.short
            : null,
        background: _ReaderSwipeDeleteBackground(label: label),
        confirmDismiss: (_) async {
          final onDelete = this.onDelete;
          if (onDelete == null) return false;
          if (collapse) return true;
          onDelete();
          return false;
        },
        onDismissed: collapse ? (_) => this.onDelete?.call() : null,
        child: child,
      ),
    );
  }
}

/// Full-bleed error fill revealed under the swiped row, with the delete
/// glyph on the trailing 16dp gutter and its label before it.
class _ReaderSwipeDeleteBackground extends StatelessWidget {
  const _ReaderSwipeDeleteBackground({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: ColoredBox(
        color: colors.error,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge.copyWith(
                    color: colors.onError,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.delete,
                size: AppIconSize.sm,
                color: colors.onError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
