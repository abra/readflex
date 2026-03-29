// MaterialApp entry point: wires theme and router.
//
// StatefulWidget so that GoRouter is created once in initState and disposed
// properly, avoiding recreation on every settings change (theme/locale).

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:readflex/app/routing.dart';

/// Entry point for the application that creates [MaterialApp.router].
class MaterialContext extends StatefulWidget {
  const MaterialContext({super.key});

  @override
  State<MaterialContext> createState() => _MaterialContextState();
}

class _MaterialContextState extends State<MaterialContext> {
  static final _globalKey = GlobalKey(debugLabel: 'MaterialContext');

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(dependencies: DependenciesScope.of(context));
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = PreferencesScope.themeModeOf(context);
    const lightTheme = LightAppThemeData();
    const darkTheme = DarkAppThemeData();

    return AppTheme(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: lightTheme.materialThemeData,
        darkTheme: darkTheme.materialThemeData,
        routerConfig: _router,
        builder: (context, child) {
          return KeyedSubtree(
            key: _globalKey,
            child: _MediaQueryRootOverride(child: child!),
          );
        },
      ),
    );
  }
}

// Clamps system text scale so large accessibility font sizes don't break layouts.
class _MediaQueryRootOverride extends StatelessWidget {
  const _MediaQueryRootOverride({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child);
}
