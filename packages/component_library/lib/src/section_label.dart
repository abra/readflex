import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';

/// Uppercase section heading used in settings and grouped lists.
class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Text(
      label,
      style: context.text.labelSmall.copyWith(
        color: cs.onSurface.withValues(alpha: 0.55),
        letterSpacing: 1,
      ),
    );
  }
}
