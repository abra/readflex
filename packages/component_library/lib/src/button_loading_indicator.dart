import 'package:flutter/material.dart';

/// Compact loading indicator sized for use inside buttons.
///
/// Buttons expose their resolved foreground through [IconTheme], so the
/// spinner follows `onPrimary` inside a filled button and the label colour
/// inside text/outlined/icon buttons. The themed progress colour applies only
/// when no button sets an icon colour, which keeps standalone use unchanged.
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
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: IconTheme.of(context).color,
      ),
    );
  }
}
