// MaterialApp entry point: wires theme and router.
//
// StatefulWidget so that GoRouter is created once in initState and disposed
// properly, avoiding recreation on every settings change (theme/locale).

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/app_system_ui_mode.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

/// Entry point for the application that creates [MaterialApp.router].
class ReadflexApp extends StatefulWidget {
  const ReadflexApp({super.key});

  @override
  State<ReadflexApp> createState() => _ReadflexAppState();
}

class _ReadflexAppState extends State<ReadflexApp> {
  final _globalKey = GlobalKey(debugLabel: 'ReadflexApp');

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(deps: DependenciesScope.of(context));
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
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: _router,
          builder: (context, child) {
            final theme = Theme.of(context);
            return KeyedSubtree(
              key: _globalKey,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: appSystemUiOverlayStyle(
                  brightness: theme.brightness,
                  backgroundColor: theme.scaffoldBackgroundColor,
                ),
                child: _AppTextScaling(child: child!),
              ),
            );
          },
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
