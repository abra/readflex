import 'package:flutter/material.dart';

/// Compact loading indicator sized for use inside buttons.
class ButtonLoadingIndicator extends StatelessWidget {
  const ButtonLoadingIndicator({
    this.size = 20,
    this.strokeWidth = 2,
    super.key,
  });

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth),
    );
  }
}
