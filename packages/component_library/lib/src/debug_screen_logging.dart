import 'package:flutter/foundation.dart';

/// Logs a `[SCREEN] build <name>` line in debug builds.
///
/// Intended to be called at the top of `build()` on top-level screen
/// widgets so that the widget tree rebuild cadence is visible in the
/// console during development. The call is wrapped in `assert(() { ... }())`
/// under the hood, so it is tree-shaken in release builds and has zero cost.
///
/// Example:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   debugLogScreenBuild('HomeScreen');
///   ...
/// }
/// ```
void debugLogScreenBuild(String screenName) {
  assert(() {
    debugPrint('[SCREEN] build $screenName');
    return true;
  }());
}
