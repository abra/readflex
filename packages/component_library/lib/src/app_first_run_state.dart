import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

const double _iconFrameSize = 72;
const double _iconFrameAlpha = 0.12;
const double _actionGap = AppSpacing.sm + AppSpacing.xxs;

/// A screen's first-run state: nothing saved yet, and the way to start.
///
/// The glyph sits in a 72dp circle tinted with the accent, over a serif
/// `headlineSmall` title and a muted hint. Any [actions] stretch to a column
/// of at most [AppSizes.centeredColumnMaxWidth], so on tablets and landscape
/// phones they keep a button's proportions; the first is the filled primary
/// command. An optional [caption] ends the column. The empty Library and the
/// empty Practice section draw it, so the app's first screens read as one;
/// list and panel placeholders stay with `EmptyState`.
class AppFirstRunState extends StatelessWidget {
  const AppFirstRunState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.caption,
    this.iconFrameKey,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Stretched commands, top to bottom; the first is the primary one. A
  /// screen reached from where the content is saved passes none.
  final List<Widget> actions;

  /// Muted line under the commands, such as the accepted file kinds.
  final String? caption;

  /// Key of the tinted circle, for tests that measure it.
  final Key? iconFrameKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final accent = context.actionForeground;
    final mutedStyle = text.bodySmall.copyWith(color: colors.onSurfaceVariant);
    final caption = this.caption;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.centeredColumnMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  key: iconFrameKey,
                  width: _iconFrameSize,
                  height: _iconFrameSize,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: _iconFrameAlpha),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: AppIconSize.lg, color: accent),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, textAlign: TextAlign.center, style: mutedStyle),
              if (actions.isNotEmpty) const SizedBox(height: AppSpacing.xl),
              for (final (index, action) in actions.indexed) ...[
                if (index > 0) const SizedBox(height: _actionGap),
                action,
              ],
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(caption, textAlign: TextAlign.center, style: mutedStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
