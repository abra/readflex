part of 'show_app_bottom_sheet.dart';

Future<T?> _showCupertinoAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required bool dismissible,
  required bool scrimClosesFlow,
  required AppSheetPresentation presentation,
  VoidCallback? onFullyHidden,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );
  final registry = AppSheetDismissRegistry();
  late final _CupertinoAppSheetRoute<T> route;
  route = _CupertinoAppSheetRoute<T>(
    reduceMotion: context.reduceMotion,
    scrimClosesFlow: scrimClosesFlow,
    dismissRegistry: registry,
    presentation: presentation,
    barrierDismissible: dismissible,
    barrierColor: AppCupertinoSheetSurface.barrierColorOf(context),
    barrierLabel: CupertinoLocalizations.of(context).modalBarrierDismissLabel,
    builder: (context) => themes.wrap(
      _CupertinoAppSheetSurface<T>(
        route: route,
        dismissible: dismissible,
        dismissRegistry: registry,
        child: AppSheetDismissScope(
          registry: registry,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
  final result = navigator.push<T>(route);
  unawaited(SystemChrome.restoreSystemUIOverlays());
  unawaited(
    route.completed.then((_) {
      registry.dispose();
      unawaited(SystemChrome.restoreSystemUIOverlays());
      onFullyHidden?.call();
    }),
  );
  return result;
}

class _CupertinoAppSheetRoute<T> extends CupertinoModalPopupRoute<T> {
  _CupertinoAppSheetRoute({
    required this.reduceMotion,
    required this.scrimClosesFlow,
    required this.dismissRegistry,
    required this.presentation,
    required super.builder,
    required super.barrierDismissible,
    required super.barrierColor,
    required super.barrierLabel,
  }) : super(semanticsDismissible: true);

  final bool reduceMotion;
  final bool scrimClosesFlow;
  final AppSheetDismissRegistry dismissRegistry;
  final AppSheetPresentation presentation;

  AnimationController? get dragController => controller;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Simulation createSimulation({required bool forward}) => reduceMotion
      ? _InstantSheetSimulation(forward ? 1 : 0)
      : super.createSimulation(forward: forward);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppWindowSize.isWide(context)
      ? child
      : super.buildTransitions(context, animation, secondaryAnimation, child);

  void onScrimDismiss() {
    final guard = dismissRegistry.value;
    if (guard != null) {
      guard();
    } else if (isCurrent) {
      if (scrimClosesFlow) {
        navigator?.pop();
      } else {
        navigator?.maybePop();
      }
    }
  }

  void dismissFromDrag() {
    if (isCurrent && !dismissRegistry.guarded) navigator?.pop();
  }

  void restoreAfterDrag() {
    final animationController = controller;
    if (animationController == null || !isCurrent) return;
    animationController.animateWith(createSimulation(forward: true));
  }

  @override
  Widget buildModalBarrier() => AnimatedModalBarrier(
    color: animation!.drive(
      ColorTween(begin: const Color(0x00000000), end: barrierColor),
    ),
    dismissible: barrierDismissible,
    onDismiss: onScrimDismiss,
    semanticsLabel: barrierLabel,
    barrierSemanticsDismissible: semanticsDismissible,
  );
}

class _InstantSheetSimulation extends Simulation {
  _InstantSheetSimulation(this.value);

  final double value;

  @override
  double x(double time) => value;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => true;
}

class _CupertinoAppSheetSurface<T> extends StatefulWidget {
  const _CupertinoAppSheetSurface({
    required this.route,
    required this.dismissible,
    required this.dismissRegistry,
    required this.child,
  });

  final _CupertinoAppSheetRoute<T> route;
  final bool dismissible;
  final AppSheetDismissRegistry dismissRegistry;
  final Widget child;

  @override
  State<_CupertinoAppSheetSurface<T>> createState() =>
      _CupertinoAppSheetSurfaceState<T>();
}

class _CupertinoAppSheetSurfaceState<T>
    extends State<_CupertinoAppSheetSurface<T>> {
  final _cardKey = GlobalKey();
  final _contentKey = GlobalKey();
  bool _dragging = false;
  bool _userGesture = false;

  // The SDK translates its whole route child, including safe/keyboard gaps.
  double get _translationHeight {
    final render = context.findRenderObject();
    return render is RenderBox ? render.size.height : 0;
  }

  double get _cardHeight {
    final render = _cardKey.currentContext?.findRenderObject();
    return render is RenderBox && render.hasSize ? render.size.height : 0;
  }

  void _finishUserGesture() {
    if (!_userGesture) return;
    _userGesture = false;
    widget.route.navigator?.didStopUserGesture();
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.route.isCurrent || widget.dismissRegistry.guarded) return;
    _dragging = true;
    widget.route.dragController?.stop();
    _userGesture = true;
    widget.route.navigator?.didStartUserGesture();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    if (widget.dismissRegistry.guarded) {
      _onDragCancel();
      return;
    }
    final height = _translationHeight;
    final controller = widget.route.dragController;
    if (height <= 0 || controller == null) return;
    controller.value = (controller.value - details.primaryDelta! / height)
        .clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final controller = widget.route.dragController;
    final displacement = (1 - (controller?.value ?? 1)) * _translationHeight;
    final cardHeight = _cardHeight;
    // Dismiss against the visible card, not the padding translated with it.
    final passedHalfCard = cardHeight > 0 && displacement > cardHeight / 2;
    final dismiss =
        !widget.dismissRegistry.guarded &&
        ((details.primaryVelocity ?? 0) > 700 || passedHalfCard);
    _finishUserGesture();
    if (dismiss) {
      widget.route.dismissFromDrag();
    } else {
      widget.route.restoreAfterDrag();
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _finishUserGesture();
    widget.route.restoreAfterDrag();
  }

  @override
  void dispose() {
    _finishUserGesture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    final wide = AppWindowSize.isWide(context);
    final content = DefaultTextStyle(
      key: _contentKey,
      style: cupertinoTheme.textTheme.textStyle,
      child: ValueListenableBuilder<VoidCallback?>(
        valueListenable: widget.dismissRegistry,
        child: Flexible(child: widget.child),
        builder: (context, guard, body) {
          final canDrag = widget.dismissible && guard == null && !wide;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: canDrag ? _onDragStart : null,
            onVerticalDragUpdate: canDrag ? _onDragUpdate : null,
            onVerticalDragEnd: canDrag ? _onDragEnd : null,
            onVerticalDragCancel: canDrag ? _onDragCancel : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canDrag)
                  const AppSheetDragHandle()
                else
                  SizedBox(height: wide ? 12 : kAppSheetDragHandleExtent),
                body!,
              ],
            ),
          );
        },
      ),
    );
    if (wide) {
      return _ExpandedAppSheet(
        presentation: widget.route.presentation,
        animation: widget.route.animation!,
        child: content,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          minimum: const EdgeInsets.all(AppCupertinoSheetSurface.minimumGap),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppCupertinoSheetSurface.maxWidth,
              ),
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                child: AppCupertinoSheetSurface(
                  key: _cardKey,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
