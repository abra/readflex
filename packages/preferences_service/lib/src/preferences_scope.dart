import 'package:flutter/widgets.dart';

import 'preferences.dart';
import 'preferences_service.dart';

/// Listens to [PreferencesService] and provides [Preferences] to the subtree.
class PreferencesScope extends StatelessWidget {
  const PreferencesScope({
    required this.service,
    required this.child,
    super.key,
  });

  final PreferencesService service;
  final Widget child;

  /// Returns current [Preferences] and subscribes to changes.
  static Preferences of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_PreferencesInherited>();
    if (scope == null) {
      throw FlutterError(
        'PreferencesScope.of() called with a context that does not contain '
        'a PreferencesScope.\n'
        'Ensure the widget tree includes a PreferencesScope ancestor.',
      );
    }
    return scope.preferences;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Preferences>(
      stream: service.stream,
      initialData: service.current,
      builder: (context, snapshot) {
        return _PreferencesInherited(preferences: snapshot.data!, child: child);
      },
    );
  }
}

class _PreferencesInherited extends InheritedWidget {
  const _PreferencesInherited({
    required super.child,
    required this.preferences,
  });

  final Preferences preferences;

  @override
  bool updateShouldNotify(_PreferencesInherited old) =>
      preferences != old.preferences;
}
