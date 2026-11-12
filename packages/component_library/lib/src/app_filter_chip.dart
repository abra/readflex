import 'package:material_ui/material_ui.dart';

import 'app_window_size.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Pill-shaped filter chip used by compact filter rows.
///
/// One body, two-tone selected/unselected. Optional [count] is rendered
/// next to the [label] in a slightly muted shade so the eye reads the
/// label first. The visible body starts at [AppSizes.chipHeight] (32),
/// inside a target of at least 48×48dp. Large text can grow the body and
/// target when the parent permits it.
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
    final labelStyle = AppWindowSize.isMedium(context)
        ? text.labelLarge
        : text.labelSmall;
    final foreground = selected ? cs.surface : cs.onSurfaceVariant;
    final background = selected
        ? cs.onSurface
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);

    // The outer detector catches the padding; the inner InkWell handles
    // the body once and keeps its ripple inside the visible shape.
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.chipTapTarget,
            minHeight: AppSizes.chipTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
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
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            label,
                            style: labelStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: foreground,
                            ),
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            '$count',
                            style: labelStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: foreground,
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
