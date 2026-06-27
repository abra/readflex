import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the app chrome visible while restoring system overlays after app
/// lifecycle and metric changes.
class AppSystemUiMode extends StatefulWidget {
  const AppSystemUiMode({required this.child, super.key});

  final Widget child;

  static AppSystemUiModeController? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<_AppSystemUiModeScope>();
    return (element?.widget as _AppSystemUiModeScope?)?.controller;
  }

  @override
  State<AppSystemUiMode> createState() => _AppSystemUiModeState();
}

class _AppSystemUiModeState extends State<AppSystemUiMode>
    with WidgetsBindingObserver {
  static const _restoreRetryDelay = Duration(milliseconds: 1100);

  late final AppSystemUiModeController _controller =
      AppSystemUiModeController._(_setBottomSystemOverlayVisible);
  Timer? _restoreRetryTimer;
  bool _bottomSystemOverlayVisible = true;

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
  Widget build(BuildContext context) {
    return _AppSystemUiModeScope(
      controller: _controller,
      child: widget.child,
    );
  }

  Future<void> _applyAppMode() {
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [
        SystemUiOverlay.top,
        if (_bottomSystemOverlayVisible) SystemUiOverlay.bottom,
      ],
    );
  }

  Future<void> _setBottomSystemOverlayVisible(bool visible) {
    if (_bottomSystemOverlayVisible == visible && visible) {
      return Future<void>.value();
    }
    _bottomSystemOverlayVisible = visible;
    _restoreRetryTimer?.cancel();
    return _applyAppModeWithRetry();
  }

  Future<void> _handleSystemUiChanged(bool systemOverlaysAreVisible) async {
    if (systemOverlaysAreVisible) {
      _restoreForcedOverlays();
    }
  }

  void _restoreForcedOverlays() {
    if (_bottomSystemOverlayVisible) {
      unawaited(SystemChrome.restoreSystemUIOverlays());
    }
    unawaited(_applyAppModeWithRetry());
  }

  Future<void> _applyAppModeWithRetry() {
    final result = _applyAppMode();
    _restoreRetryTimer?.cancel();
    _restoreRetryTimer = Timer(_restoreRetryDelay, () {
      if (!mounted) return;
      if (_bottomSystemOverlayVisible) {
        unawaited(SystemChrome.restoreSystemUIOverlays());
      }
      unawaited(_applyAppMode());
    });
    return result;
  }
}

class AppSystemUiModeController {
  const AppSystemUiModeController._(this._setBottomSystemOverlayVisible);

  final Future<void> Function(bool visible) _setBottomSystemOverlayVisible;

  Future<void> showBottomSystemOverlay() {
    return _setBottomSystemOverlayVisible(true);
  }

  Future<void> hideBottomSystemOverlay() {
    return _setBottomSystemOverlayVisible(false);
  }
}

class AppBottomSystemOverlayVisibility extends StatefulWidget {
  const AppBottomSystemOverlayVisibility({
    required this.visible,
    required this.child,
    super.key,
  });

  final bool visible;
  final Widget child;

  @override
  State<AppBottomSystemOverlayVisibility> createState() =>
      _AppBottomSystemOverlayVisibilityState();
}

class _AppBottomSystemOverlayVisibilityState
    extends State<AppBottomSystemOverlayVisibility> {
  AppSystemUiModeController? _controller;
  Animation<double>? _routeAnimation;
  bool _appliedHidden = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindRouteAnimation();
    _syncController();
  }

  @override
  void didUpdateWidget(AppBottomSystemOverlayVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _applyRequestedVisibility();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _restoreBottomOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _bindRouteAnimation() {
    final animation = ModalRoute.of(context)?.animation;
    if (identical(_routeAnimation, animation)) return;

    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
  }

  void _syncController() {
    final controller = AppSystemUiMode.maybeOf(context);
    if (identical(_controller, controller)) return;

    _restoreBottomOverlay();
    _controller = controller;
    _applyRequestedVisibility();
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        _restoreBottomOverlay();
        return;
      case AnimationStatus.completed:
      case AnimationStatus.forward:
        _applyRequestedVisibility();
        return;
    }
  }

  void _applyRequestedVisibility() {
    final controller = _controller;
    if (controller == null) return;

    if (widget.visible) {
      _appliedHidden = false;
      unawaited(controller.showBottomSystemOverlay());
      return;
    }

    _appliedHidden = true;
    unawaited(controller.hideBottomSystemOverlay());
  }

  void _restoreBottomOverlay() {
    if (!_appliedHidden) return;
    _appliedHidden = false;
    unawaited(_controller?.showBottomSystemOverlay());
  }
}

class _AppSystemUiModeScope extends InheritedWidget {
  const _AppSystemUiModeScope({
    required this.controller,
    required super.child,
  });

  final AppSystemUiModeController controller;

  @override
  bool updateShouldNotify(_AppSystemUiModeScope oldWidget) =>
      controller != oldWidget.controller;
}
