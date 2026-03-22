import 'package:flutter/material.dart';

import 'theme/spacing.dart';

class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    required this.title,
    required this.onClose,
    super.key,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Transform.translate(
          offset: const Offset(Spacing.small, 0),
          child: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ),
      ],
    );
  }
}
