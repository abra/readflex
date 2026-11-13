import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';

/// The purpose of a surface, independent of its platform presentation.
enum AppSurfaceRole {
  contentCard,
  reviewCard,
  floatingToolbar,
  menu,
  modal,
  field,
  sidePanel,
}

/// Shared surface policy, resolved against the existing app theme.
///
/// Material uses painted elevation; Cupertino uses continuous corners and
/// restrained shadows only for floating controls and menus. Reader page
/// colors remain independent from these application chrome roles.
@immutable
class AppSurfaceAppearance {
  const AppSurfaceAppearance({
    required this.color,
    required this.shape,
    required this.borderRadius,
    this.elevation = 0,
    this.shadows = const [],
    this.blurSigma = 0,
  });

  /// Opacity retained by a translucent Cupertino toolbar's neutral fill.
  static const double floatingToolbarOpacity = .92;

  final Color color;
  final OutlinedBorder shape;
  final BorderRadius borderRadius;
  final double elevation;
  final List<BoxShadow> shadows;
  final double blurSigma;

  static AppSurfaceAppearance resolve(
    BuildContext context,
    AppSurfaceRole role,
  ) {
    final colors = context.colors;
    final cupertino = context.isCupertino;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(switch (role) {
      AppSurfaceRole.contentCard ||
      AppSurfaceRole.reviewCard => cupertino ? 18 : AppRadius.lg,
      AppSurfaceRole.floatingToolbar => AppRadius.full,
      AppSurfaceRole.menu => cupertino ? AppRadius.lg : AppRadius.md,
      AppSurfaceRole.modal => AppRadius.xl,
      AppSurfaceRole.field => AppRadius.md,
      AppSurfaceRole.sidePanel => 0,
    });
    final BorderSide side;
    if (role == AppSurfaceRole.floatingToolbar ||
        role == AppSurfaceRole.sidePanel) {
      side = BorderSide(
        color: colors.outlineVariant,
        width: 1 / MediaQuery.devicePixelRatioOf(context),
      );
    } else if (!cupertino &&
        (role == AppSurfaceRole.contentCard ||
            role == AppSurfaceRole.reviewCard ||
            role == AppSurfaceRole.field)) {
      side = BorderSide(color: colors.outlineVariant);
    } else {
      side = BorderSide.none;
    }
    final OutlinedBorder shape = role == AppSurfaceRole.floatingToolbar
        ? StadiumBorder(side: side)
        : cupertino
        ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
        : RoundedRectangleBorder(borderRadius: radius, side: side);

    if (!cupertino) {
      return AppSurfaceAppearance(
        color: switch (role) {
          AppSurfaceRole.contentCard ||
          AppSurfaceRole.reviewCard => colors.surface,
          AppSurfaceRole.floatingToolbar ||
          AppSurfaceRole.menu => colors.surfaceContainerLow,
          AppSurfaceRole.field => colors.surfaceContainerLowest,
          AppSurfaceRole.modal ||
          AppSurfaceRole.sidePanel => context.appTheme.sheetColor,
        },
        shape: shape,
        borderRadius: radius,
        elevation: switch (role) {
          AppSurfaceRole.floatingToolbar => 2,
          AppSurfaceRole.menu => 3,
          _ => 0,
        },
      );
    }

    // Flutter 3.50 has no Reduce Transparency signal. Honor the available
    // high-contrast and accessible-navigation preferences conservatively.
    final opaqueToolbar =
        highContrast || MediaQuery.accessibleNavigationOf(context);
    return AppSurfaceAppearance(
      color: switch (role) {
        AppSurfaceRole.floatingToolbar =>
          context.appTheme.sheetColor.withValues(
            alpha: opaqueToolbar ? 1 : floatingToolbarOpacity,
          ),
        AppSurfaceRole.field => Color.alphaBlend(
          CupertinoDynamicColor.resolve(
            CupertinoColors.tertiarySystemFill,
            context,
          ),
          context.appTheme.sheetColor,
        ),
        _ => context.appTheme.sheetColor,
      },
      shape: highContrast
          ? shape.copyWith(side: BorderSide(color: colors.outline))
          : shape,
      borderRadius: radius,
      shadows: switch (role) {
        AppSurfaceRole.floatingToolbar => const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .09),
            offset: Offset(0, 2),
            blurRadius: 7,
          ),
        ],
        AppSurfaceRole.menu => const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .12),
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
        _ => const [],
      },
      blurSigma: role == AppSurfaceRole.floatingToolbar && !opaqueToolbar
          ? 18
          : 0,
    );
  }
}
