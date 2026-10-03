import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// A settings group, independent of the feature that owns its values.
class AppSettingsSection extends StatelessWidget {
  const AppSettingsSection({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: context.text.labelMedium.copyWith(
            color: context.colors.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
}
