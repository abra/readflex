import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// A result with a null note clears/skips the note; a null result cancels editing.
class ReaderHighlightNoteResult {
  const ReaderHighlightNoteResult(this.note);
  final String? note;
}

Future<ReaderHighlightNoteResult?> showReaderHighlightNoteSheet(
  BuildContext context, {
  String? initialNote,
  bool existingHighlight = false,
}) => showAppBottomSheet<ReaderHighlightNoteResult>(
  context,
  dismissible: false,
  builder: (_) => ReaderHighlightNoteSheet(
    initialNote: initialNote,
    existingHighlight: existingHighlight,
  ),
);

/// UI-only draft. The caller commits the result through the reader bloc.
class ReaderHighlightNoteSheet extends StatefulWidget {
  const ReaderHighlightNoteSheet({
    this.initialNote,
    this.existingHighlight = false,
    super.key,
  });
  final String? initialNote;
  final bool existingHighlight;

  @override
  State<ReaderHighlightNoteSheet> createState() =>
      _ReaderHighlightNoteSheetState();
}

class _ReaderHighlightNoteSheetState extends State<ReaderHighlightNoteSheet> {
  late final _initialNote = _normalize(widget.initialNote);
  late final _controller = TextEditingController(text: _initialNote ?? '')
    ..addListener(_onChanged);
  bool _confirmDiscard = false;
  ReaderHighlightNoteResult? _discardResult;

  String? _normalize(String? text) {
    final value = text?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _onChanged() => setState(() {});

  void _requestExit([ReaderHighlightNoteResult? result]) {
    if (_normalize(_controller.text) == _initialNote) {
      Navigator.of(context).pop(result);
      return;
    }
    if (_confirmDiscard) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _discardResult = result;
      _confirmDiscard = true;
    });
  }

  void _keepEditing() => setState(() => _confirmDiscard = false);

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = _normalize(_controller.text);
    final VoidCallback? onSave = note != _initialNote
        ? () => Navigator.of(context).pop(ReaderHighlightNoteResult(note))
        : null;
    return PopScope<ReaderHighlightNoteResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_confirmDiscard) {
            _keepEditing();
          } else {
            _requestExit();
          }
        }
      },
      child: ActionBottomSheetLayout(
        title: _confirmDiscard
            ? l10n.commonDiscardChangesTitle
            : _initialNote != null
            ? l10n.readerEditNoteTitle
            : l10n.readerHighlightNoteTitle,
        closeLabel: l10n.commonClose,
        onClose: _requestExit,
        backLabel: _confirmDiscard ? l10n.commonBack : null,
        onBack: _confirmDiscard ? _keepEditing : null,
        constrainBody: true,
        // Commands live in the footer slot so the body-to-command gap and the
        // bottom inset follow the shared sheet rhythm.
        footer: _confirmDiscard
            ? AppSheetActions(
                primaryLabel: l10n.commonKeepEditing,
                onPrimary: _keepEditing,
                secondaryLabel: l10n.commonDiscardChanges,
                destructiveSecondary: true,
                onSecondary: () => Navigator.of(context).pop(_discardResult),
              )
            : widget.existingHighlight
            ? FilledButton(
                onPressed: onSave,
                child: AppButtonLabel(l10n.commonSave),
              )
            // Skip keeps the new highlight without a note, unlike Close, which
            // pops null and saves nothing.
            : AppSheetActions(
                primaryLabel: l10n.commonSave,
                onPrimary: onSave,
                secondaryLabel: l10n.readerSkip,
                onSecondary: () =>
                    _requestExit(const ReaderHighlightNoteResult(null)),
              ),
        child: SingleChildScrollView(
          // Retain the draft and the form height while confirming dismissal.
          child: TextField(
            controller: _controller,
            enabled: !_confirmDiscard,
            minLines: 3,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.readerCommentHint,
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }
}
