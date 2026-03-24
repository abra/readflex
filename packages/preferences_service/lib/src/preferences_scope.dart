import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'preferences.dart';
import 'preferences_service.dart';

enum _PreferencesAspect {
  all,
  themeMode,
  readerAppearance,
}

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
    final scope = InheritedModel.inheritFrom<_PreferencesInherited>(
      context,
      aspect: _PreferencesAspect.all,
    );
    if (scope == null) {
      throw FlutterError(
        'PreferencesScope.of() called with a context that does not contain '
        'a PreferencesScope.\n'
        'Ensure the widget tree includes a PreferencesScope ancestor.',
      );
    }
    return scope.preferences;
  }

  /// Returns [ThemeMode] and rebuilds only when the app theme preference changes.
  static ThemeMode themeModeOf(BuildContext context) {
    final scope = InheritedModel.inheritFrom<_PreferencesInherited>(
      context,
      aspect: _PreferencesAspect.themeMode,
    );
    if (scope == null) {
      throw FlutterError(
        'PreferencesScope.themeModeOf() called with a context that does not '
        'contain a PreferencesScope.\n'
        'Ensure the widget tree includes a PreferencesScope ancestor.',
      );
    }
    return scope.preferences.themeMode;
  }

  /// Returns reader appearance settings and rebuilds only when they change.
  static ReaderAppearancePreferences readerAppearanceOf(BuildContext context) {
    final scope = InheritedModel.inheritFrom<_PreferencesInherited>(
      context,
      aspect: _PreferencesAspect.readerAppearance,
    );
    if (scope == null) {
      throw FlutterError(
        'PreferencesScope.readerAppearanceOf() called with a context that does '
        'not contain a PreferencesScope.\n'
        'Ensure the widget tree includes a PreferencesScope ancestor.',
      );
    }
    return scope.preferences.readerAppearance;
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

class _PreferencesInherited extends InheritedModel<_PreferencesAspect> {
  const _PreferencesInherited({
    required super.child,
    required this.preferences,
  });

  final Preferences preferences;

  @override
  bool updateShouldNotify(_PreferencesInherited old) =>
      preferences != old.preferences;

  @override
  bool updateShouldNotifyDependent(
    _PreferencesInherited old,
    Set<_PreferencesAspect> dependencies,
  ) {
    if (dependencies.contains(_PreferencesAspect.all)) {
      return preferences != old.preferences;
    }

    if (dependencies.contains(_PreferencesAspect.themeMode) &&
        preferences.themeMode != old.preferences.themeMode) {
      return true;
    }

    if (dependencies.contains(_PreferencesAspect.readerAppearance) &&
        preferences.readerAppearance != old.preferences.readerAppearance) {
      return true;
    }

    return false;
  }
}
