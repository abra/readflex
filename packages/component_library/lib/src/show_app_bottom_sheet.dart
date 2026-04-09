import 'package:flutter/material.dart';

/// Shows a modal bottom sheet using the app's standard configuration.
///
/// All sheets are shown via the root navigator (above tab bar),
/// scroll-controlled (height fits content), and respect safe area.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: builder,
  );
}
