import 'package:flutter/widgets.dart';
import 'package:toastification/toastification.dart';

/// Dismisses visible toasts when a popup route (a bottom sheet or a dialog)
/// opens. A toast sits at the bottom, where a sheet keeps its commands, and
/// it describes the screen the user has just moved on from; a lingering error
/// would otherwise cover a confirmation's Delete or Keep. Page routes leave
/// toasts alone.
///
/// Register it on the navigator that presents sheets and dialogs (the root
/// one).
class ToastNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      toastification.dismissAll(delayForAnimation: false);
    }
  }
}
