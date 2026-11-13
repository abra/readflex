import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:readflex_localizations/readflex_localizations.dart';

/// Native confirmation before deleting one or more library items.
///
/// The dialog returns one of:
///   * `null` — user kept the items or dismissed the dialog.
///   * [BookDeletionScope.keepLearningData] — user confirmed deletion.
///
/// Wording is count-aware: `count == 1` shows the singular phrasing,
/// `count > 1` shows the plural with the actual number.
Future<BookDeletionScope?> showConfirmBookDeletionDialog(
  BuildContext context, {
  required int count,
}) async {
  final l10n = context.l10n;
  final confirmed = await showAppConfirmationDialog(
    context,
    title: l10n.libraryDeleteItemsTitle(count),
    message: l10n.libraryDeleteItemsBody(count),
    confirmLabel: l10n.commonDelete,
    cancelLabel: l10n.commonKeep,
    destructive: true,
  );
  return confirmed == true ? BookDeletionScope.keepLearningData : null;
}
