import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';

/// Save / Saved toggle for a sheet row; the caller owns the persistence.
///
/// Reads as a bookmark: an outlined bookmark to save, a checked one once
/// [saved]. The tooltip names the action the next tap takes, so a screen
/// reader hears "Remove from Vocabulary" on a saved word. A change of state is
/// announced through a live region, like [AppCopyButton].
class AppSaveToggleButton extends StatefulWidget {
  const AppSaveToggleButton({
    required this.saved,
    required this.onPressed,
    required this.saveLabel,
    required this.savedLabel,
    required this.unsaveLabel,
    this.failed = false,
    this.failureLabel,
    this.busy = false,
    super.key,
  });

  final bool saved;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final String saveLabel;

  /// Announced once the word is saved.
  final String savedLabel;
  final String unsaveLabel;

  /// The last attempt failed: the error glyph and [failureLabel] show until
  /// the next tap.
  final bool failed;
  final String? failureLabel;
  final bool busy;

  @override
  State<AppSaveToggleButton> createState() => _AppSaveToggleButtonState();
}

class _AppSaveToggleButtonState extends State<AppSaveToggleButton> {
  bool _announce = false;

  @override
  void didUpdateWidget(AppSaveToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _announce =
        oldWidget.saved != widget.saved || oldWidget.failed != widget.failed;
  }

  @override
  Widget build(BuildContext context) {
    final failureLabel = widget.failureLabel;
    final (icon, tooltip) = switch ((widget.failed, widget.saved)) {
      (true, _) when failureLabel != null => (AppIcons.error, failureLabel),
      (_, true) => (AppIcons.bookmarkSaved, widget.unsaveLabel),
      (_, false) => (AppIcons.bookmarkAdd, widget.saveLabel),
    };
    return Semantics(
      liveRegion: _announce,
      value: widget.saved ? widget.savedLabel : null,
      child: AppPlainIconButton(
        tooltip: tooltip,
        onPressed: widget.busy ? null : widget.onPressed,
        icon: icon,
        color: widget.saved ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
