// MaterialApp entry point: wires theme and router.
//
// StatefulWidget so that GoRouter is created once in initState and disposed
// properly, avoiding recreation on every settings change (theme/locale).

import 'dart:io' show Platform;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:monitoring/monitoring.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:readflex/app/routing.dart';

/// Entry point for the application that creates [MaterialApp.router].
class MaterialContext extends StatefulWidget {
  const MaterialContext({super.key});

  @override
  State<MaterialContext> createState() => _MaterialContextState();
}

class _MaterialContextState extends State<MaterialContext>
    with WidgetsBindingObserver {
  static final _globalKey = GlobalKey(debugLabel: 'MaterialContext');

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(deps: DependenciesScope.of(context));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS can kill the loopback socket while the app is suspended.
    // Restart the server when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed && Platform.isIOS) {
      final deps = DependenciesScope.of(context);
      final server = deps.readerServer;
      if (!server.isRunning) {
        _restartReaderServer(server, deps.logger);
      }
    }
  }

  Future<void> _restartReaderServer(ReaderServer server, Logger logger) async {
    try {
      await server.start();
    } catch (e, st) {
      logger.error(
        'ReaderServer restart after resume failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = PreferencesScope.themeModeOf(context);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
      builder: (context, child) {
        return KeyedSubtree(
          key: _globalKey,
          child: _MediaQueryRootOverride(child: child!),
        );
      },
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
