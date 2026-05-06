import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Pill-shaped filter chip used by Library and Dictionary header rows.
///
/// One body, two-tone selected/unselected. Optional [count] is rendered
/// next to the [label] in a slightly muted shade so the eye reads the
/// label first. Visual height is [AppSizes.chipHeight] (32 — Material
/// chip default), but the InkWell is wrapped in 48dp tap padding so the
/// hit area still meets the Apple HIG / Material accessibility floor.
///
/// `selected` styling is high-contrast (foreground inverted) — easier
/// to scan on a busy header than a subtle outline. `onTap` is required
/// — chips are interactive by definition.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  final String label;

  /// Companion number rendered to the right of [label]. Hidden when null.
  final int? count;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final foreground = selected
        ? cs.surface
        : cs.onSurface.withValues(alpha: 0.6);
    final background = selected
        ? cs.onSurface
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);

    // Visible chip is [AppSizes.chipHeight] (32). Outer GestureDetector
    // catches taps in the surrounding pad up to [AppSizes.chipTapTarget]
    // (48), so the hit area meets the a11y floor without inflating the
    // visual. InkWell still wins for taps inside the visible chip
    // (deepest hit), keeping ripple bounded to the 32 body.
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSizes.chipTapTarget,
          child: Center(
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.chipHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: text.labelSmall.copyWith(
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            '$count',
                            style: text.labelSmall.copyWith(
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: foreground.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
