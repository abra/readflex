import 'package:flutter/material.dart';

import 'app_button_label.dart';
import 'button_loading_indicator.dart';

/// Button content that swaps its label for a spinner without changing the
/// button's size, so a sheet footer never reflows while a write is in flight.
///
/// The hidden label keeps its layout; the spinner announces the same label as
/// a live region so assistive technology learns the command is busy.
class AppBusyButtonLabel extends StatelessWidget {
  const AppBusyButtonLabel(this.label, {required this.busy, super.key});

  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: !busy,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: AppButtonLabel(label),
        ),
        if (busy)
          Semantics(
            label: label,
            liveRegion: true,
            child: const ButtonLoadingIndicator(),
          ),
      ],
    );
  }
}
