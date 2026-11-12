// Platform application entry point: wires theme and router.
//
// StatefulWidget so that GoRouter is created once in initState and disposed
// properly, avoiding recreation on every settings change (theme/locale).

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/app_system_ui_mode.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:readflex/app/routing.dart';

import 'readflex_platform_app.dart';

import 'package:toast_service/toast_service.dart';

/// Retains the feature router across platform theme and locale changes.
class ReadflexApp extends StatefulWidget {
  const ReadflexApp({this.initialLocation = AppRoutes.root, super.key});

  /// Where the router starts; tests can open a route directly.
  final String initialLocation;

  @override
  State<ReadflexApp> createState() => _ReadflexAppState();
}

class _ReadflexAppState extends State<ReadflexApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      deps: DependenciesScope.of(context),
      initialLocation: widget.initialLocation,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = PreferencesScope.themeModeOf(context);
    final locale = PreferencesScope.localeOf(context);

    return AppSystemUiMode(
      child: ToastWrapper(
        child: ReadflexPlatformApp(
          locale: locale,
          brightness: switch (themeMode) {
            AppThemeMode.system => null,
            AppThemeMode.light => Brightness.light,
            AppThemeMode.dark => Brightness.dark,
          },
          routerConfig: _router,
          builder: (context, child) => _AppTextScaling(child: child!),
        ),
      ),
    );
  }
}

/// App-wide MediaQuery wrapper that caps text scale at the current design limit.
class _AppTextScaling extends StatelessWidget {
  const _AppTextScaling({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child);
}
