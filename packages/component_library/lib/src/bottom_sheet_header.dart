import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';
import 'theme/extensions/build_context_ext.dart';

/// Sheet title with an optional explicit close action.
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    required this.title,
    this.onClose,
    this.closeLabel,
    super.key,
  }) : assert(onClose == null || closeLabel != null);

  final String title;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: closeLabel == null
          ? context.text.titleLarge
          : context.text.titleMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (closeLabel == null) return heading;
    return Row(
      children: [
        Expanded(child: heading),
        AppPlainIconButton(
          icon: AppIcons.close,
          tooltip: closeLabel!,
          onPressed: onClose,
        ),
      ],
    );
  }
}
