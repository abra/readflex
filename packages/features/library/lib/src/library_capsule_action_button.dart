import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// The capsule's persistent filled action: Add fades into Close search.
/// The caller owns timing; the native button survives both modes.
class LibraryCapsuleActionButton extends StatelessWidget {
  const LibraryCapsuleActionButton({
    required this.progress,
    required this.searchActive,
    required this.onAddPressed,
    required this.onSearchClosed,
    super.key,
  });

  final Animation<double> progress;
  final bool searchActive;
  final VoidCallback? onAddPressed;
  final VoidCallback? onSearchClosed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppIconButton(
      key: const ValueKey('libraryCapsuleActionButton'),
      onPressed: searchActive ? onSearchClosed : onAddPressed,
      tooltip: searchActive
          ? context.l10n.commonBack
          : context.l10n.importAddToLibraryTitle,
      foregroundColor: colors.onPrimary,
      backgroundColor: colors.primary,
      disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
      disabledBackgroundColor: colors.onSurface.withValues(alpha: .12),
      fixedSize: const Size.square(AppSizes.buttonHeight),
      minimumSize: const Size.square(AppSizes.buttonHeight),
      padding: EdgeInsets.zero,
      shape: const CircleBorder(),
      icon: _ActionIcon(progress: progress),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: AppIconSize.md,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: ReverseAnimation(progress),
            child: const Icon(AppIcons.add, size: AppIconSize.md),
          ),
          FadeTransition(
            opacity: progress,
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? AppIcons.chevronLeft
                  : AppIcons.chevronRight,
              size: AppIconSize.md,
            ),
          ),
        ],
      ),
    ),
  );
}
