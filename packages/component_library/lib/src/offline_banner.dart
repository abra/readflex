import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/extensions/app_colors_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Thin strip shown while the device has no network.
///
/// Pure presentation — the owner decides when and where to render it (typically
/// driven by `ConnectivityScope.of(context)` from `connectivity_service`). Uses
/// the `warning` semantic colors from [AppColorsExt] so it reads the same way
/// in light and dark themes.
///
/// Designed to sit flush against a neighbour (e.g. right above the bottom
/// navigation bar) — the strip has no [SafeArea] of its own; callers embed it
/// where the surrounding layout already handles insets.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.message = 'Offline', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExt>()!;

    return Material(
      color: colors.warning,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.offline, size: 14, color: colors.warningForeground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              message,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.warningForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
