import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';

/// Title row for a bottom sheet — just the heading. Closing is owned
/// entirely by [showAppBottomSheet] (drag handle, drag-down, scrim
/// tap), so this widget no longer renders a close button.
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.text.titleLarge,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
