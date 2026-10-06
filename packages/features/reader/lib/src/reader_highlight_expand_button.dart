import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Read more / Show less for a highlight row.
///
/// The themed 16dp button padding doubles as the row's content gutter: the
/// owning column leaves this button unpadded so the label starts on the
/// gutter while the ink bleeds into it.
class ReaderHighlightExpandButton extends StatelessWidget {
  const ReaderHighlightExpandButton({
    required this.expanded,
    required this.onPressed,
    super.key,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextButton(
      onPressed: onPressed,
      child: AppButtonLabel(
        expanded ? l10n.readerCollapseHighlight : l10n.readerExpandHighlight,
      ),
    );
  }
}
