import 'package:flutter/material.dart';

import 'theme/spacing.dart';

/// Standard end-to-start dismiss background for destructive actions.
class DestructiveDismissBackground extends StatelessWidget {
  const DestructiveDismissBackground({
    this.icon = Icons.delete,
    super.key,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Spacing.large),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onError,
      ),
    );
  }
}
