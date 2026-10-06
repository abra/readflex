import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// A settings group, independent of the feature that owns its values.
///
/// [titlePadding] insets only the title: a child whose ink bleeds into the
/// gutter (a swatch grid) sits in the reduced gutter while the title keeps
/// the content edge.
class AppSettingsSection extends StatelessWidget {
  const AppSettingsSection({
    required this.title,
    required this.child,
    this.titlePadding = EdgeInsets.zero,
    super.key,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry titlePadding;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: titlePadding,
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: context.text.labelMedium.copyWith(
              color: context.colors.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
}
