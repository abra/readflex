import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// The Library's primary action: the filled "+" circle at the outer end of
/// the bottom capsule, in the corner where the thumb rests.
///
/// Colours are explicit because the app's `iconButtonTheme` styles secondary
/// square buttons; disabled colours follow Material's filled icon button.
class LibraryAddButton extends StatelessWidget {
  const LibraryAddButton({required this.onPressed, super.key});

  /// Opens the import menu; `null` while an import flow is already open.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      key: const ValueKey('libraryAddButton'),
      onPressed: onPressed,
      tooltip: context.l10n.importAddToLibraryTitle,
      style: IconButton.styleFrom(
        foregroundColor: colors.onPrimary,
        backgroundColor: colors.primary,
        disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
        disabledBackgroundColor: colors.onSurface.withValues(alpha: .12),
        fixedSize: const Size.square(AppSizes.buttonHeight),
        minimumSize: const Size.square(AppSizes.buttonHeight),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(AppIcons.add, size: AppIconSize.md),
    );
  }
}
