import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_system_ui_mode.dart';

/// Reader uses the full screen for content. On Android devices configured with
/// three-button navigation, hiding only the bottom system overlay keeps those
/// buttons from covering the reading area while leaving the app status bar
/// policy unchanged. Other platforms keep their system UI.
class ReaderSystemNavigationBarMode extends StatelessWidget {
  const ReaderSystemNavigationBarMode({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return child;
    return AppBottomSystemOverlayVisibility(visible: false, child: child);
  }
}
