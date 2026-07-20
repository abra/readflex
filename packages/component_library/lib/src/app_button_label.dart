import 'package:flutter/material.dart';

/// Localized text label for app buttons.
///
/// Button labels live in tight surfaces and translations can be longer than
/// English. Keep them centered, allow a second line where the parent can grow,
/// and fall back to ellipsis only when the available width is still too small.
class AppButtonLabel extends StatelessWidget {
  const AppButtonLabel(
    this.text, {
    this.maxLines = 2,
    super.key,
  });

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
    );
  }
}
