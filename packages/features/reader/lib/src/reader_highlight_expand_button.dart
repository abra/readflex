import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Read more / Show less for a highlight row.
///
/// The platform button padding supplies the ink bleed. The owning footer adds
/// only the extra inset needed by a native bottom panel's wider gutter.
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
    return AppButton.text(
      onPressed: onPressed,
      child: AppButtonLabel(
        expanded ? l10n.readerCollapseHighlight : l10n.readerExpandHighlight,
      ),
    );
  }
}
