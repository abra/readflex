import 'package:flutter/material.dart';

import 'theme/spacing.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: Spacing.medium),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
