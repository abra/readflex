import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'reader_external_link_choice.dart';
import 'reader_external_link_destination.dart';
import 'reader_external_link_sheet.dart';

/// Gives [builder] the callback for links the page reports leaving the
/// reader. Each one first opens the link sheet: Open hands the link to
/// [onOpen], Copy puts it on the clipboard, dismissing does nothing.
///
/// One sheet at a time: a link reported while it is open (a double tap, or a
/// navigation the page starts itself) is dropped. Without [onOpen] nothing
/// can open a link, so links are ignored, as are schemes the reader does not
/// offer (see [ReaderExternalLinkDestination.tryParse]).
class ReaderExternalLinkPrompt extends StatefulWidget {
  const ReaderExternalLinkPrompt({
    required this.onOpen,
    required this.builder,
    super.key,
  });

  final ValueChanged<String>? onOpen;
  final Widget Function(
    BuildContext context,
    ValueChanged<String>? onExternalLink,
  )
  builder;

  @override
  State<ReaderExternalLinkPrompt> createState() =>
      _ReaderExternalLinkPromptState();
}

class _ReaderExternalLinkPromptState extends State<ReaderExternalLinkPrompt> {
  var _asking = false;

  Future<void> _ask(String url) async {
    final destination = ReaderExternalLinkDestination.tryParse(url);
    if (_asking || destination == null) return;
    _asking = true;
    try {
      final choice = await showReaderExternalLinkSheet(
        context,
        destination: destination,
      );
      if (!mounted) return;
      switch (choice) {
        case ReaderExternalLinkChoice.open:
          widget.onOpen?.call(destination.url);
        case ReaderExternalLinkChoice.copy:
          await _copy(destination.url);
        case null:
          break;
      }
    } finally {
      _asking = false;
    }
  }

  Future<void> _copy(String url) async {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } on PlatformException {
      copied = false;
    }
    if (!mounted) return;
    showToast(
      context,
      type: copied ? NotificationType.success : NotificationType.error,
      message: copied
          ? context.l10n.commonCopied
          : context.l10n.commonCopyFailed,
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.onOpen == null ? null : _ask);
}
