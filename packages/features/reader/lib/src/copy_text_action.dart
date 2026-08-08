import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:toast_service/toast_service.dart';

/// Copies the exact reader selection without applying lexical normalization.
class CopyTextAction extends TextAction {
  CopyTextAction();

  @override
  String get label => 'Copy';

  @override
  String labelFor(BuildContext context) => context.l10n.commonCopy;

  @override
  IconData get icon => AppIcons.copy;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {
    if (selection.selectedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: selection.selectedText));
    if (!context.mounted) return;
    showToast(
      context,
      type: NotificationType.success,
      message: context.l10n.readerSelectionCopied,
    );
  }
}
