import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the app fullscreen while preserving the top status overlay.
class AppSystemUiMode extends StatefulWidget {
  const AppSystemUiMode({required this.child, super.key});

  final Widget child;

  @override
  State<AppSystemUiMode> createState() => _AppSystemUiModeState();
}

class _AppSystemUiModeState extends State<AppSystemUiMode>
    with WidgetsBindingObserver {
  static const _restoreRetryDelay = Duration(milliseconds: 1100);

  Timer? _restoreRetryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_applyAppMode());
    unawaited(
      SystemChrome.setSystemUIChangeCallback(_handleSystemUiChanged),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_applyAppMode());
      _restoreForcedOverlays();
    }
  }

  @override
  void didChangeMetrics() {
    _restoreForcedOverlays();
  }

  @override
  void dispose() {
    _restoreRetryTimer?.cancel();
    unawaited(SystemChrome.setSystemUIChangeCallback(null));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _applyAppMode() {
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  Future<void> _handleSystemUiChanged(bool systemOverlaysAreVisible) async {
    if (systemOverlaysAreVisible) {
      _restoreForcedOverlays();
    }
  }

  void _restoreForcedOverlays() {
    unawaited(SystemChrome.restoreSystemUIOverlays());
    _restoreRetryTimer?.cancel();
    _restoreRetryTimer = Timer(_restoreRetryDelay, () {
      if (!mounted) return;
      unawaited(SystemChrome.restoreSystemUIOverlays());
      unawaited(_applyAppMode());
    });
  }
}
