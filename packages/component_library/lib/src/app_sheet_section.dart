import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// One section of a sheet body, outlined so that sections read as separate
/// blocks: a hairline in the divider color, no fill.
///
/// The outline is drawn behind full-width content rather than around it.
/// [child] keeps the sheet's geometry: text stays on the 24dp gutter, under
/// the sheet title, and an `AppSheetActionRow` glyph stays on the same edge.
/// The outline sits [outlineInset] from either side of the sheet, so a 48dp
/// utility target reaches exactly to it.
///
/// [title] heads the section in the interface language. When the section's
/// content is an `AppSheetActionRow`, pass the title as the row's lead
/// instead ([AppSheetSectionTitle]) so its action is centered on the text,
/// and use [EdgeInsets.zero] [padding] with the row's `minTextRoom` keeping
/// the same room inside the outline.
class AppSheetSection extends StatelessWidget {
  const AppSheetSection({
    required this.child,
    this.title,
    this.padding = defaultPadding,
    super.key,
  });

  /// Room between the outline and the content above and below it.
  static const EdgeInsets defaultPadding = EdgeInsets.symmetric(
    vertical: AppSpacing.md,
  );

  /// Distance of the outline from either side of the sheet: the 24dp gutter
  /// less the part of a 48dp icon target beyond its glyph.
  static const double outlineInset = AppSpacing.xl - AppSizes.iconActionOutset;

  final Widget child;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Stack(
      children: [
        Positioned.fill(
          left: outlineInset,
          right: outlineInset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: AppSheetSectionTitle(title),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// The heading of an [AppSheetSection], announced as a header. Used by the
/// section itself, or as the lead of an `AppSheetActionRow` inside it.
class AppSheetSectionTitle extends StatelessWidget {
  const AppSheetSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: context.text.labelLarge),
    );
  }
}
