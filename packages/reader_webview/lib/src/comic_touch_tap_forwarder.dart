import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Observes short touches without competing with the platform view's gestures.
/// WKWebView in a Flutter platform view can lose the second rapid touch.
/// Only completed taps cross the bridge; pan/pinch stay in the WebView.
class ComicTouchTapForwarder extends StatefulWidget {
  const ComicTouchTapForwarder({
    required this.onTap,
    required this.child,
    super.key,
  });

  final ValueChanged<Offset> onTap;
  final Widget child;

  @override
  State<ComicTouchTapForwarder> createState() => _ComicTouchTapForwarderState();
}

class _ComicTouchTapForwarderState extends State<ComicTouchTapForwarder>
    with WidgetsBindingObserver {
  final _pointers = <int>{};
  PointerDownEvent? _candidate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pointers.clear();
      _candidate = null;
    }
  }

  void _onDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _pointers.add(event.pointer);
    _candidate = _pointers.length == 1 ? event : null;
  }

  void _onMove(PointerMoveEvent event) {
    final candidate = _candidate;
    if (candidate?.pointer == event.pointer &&
        (event.position - candidate!.position).distance > 8) {
      _candidate = null;
    }
  }

  void _onUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    final candidate = _candidate;
    if (candidate?.pointer != event.pointer) return;
    _candidate = null;
    // Image-area long press starts at 280 ms in the reader JS.
    if (_pointers.isEmpty &&
        event.timeStamp - candidate!.timeStamp <
            const Duration(milliseconds: 280) &&
        (event.position - candidate.position).distance <= 8) {
      widget.onTap(event.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onDown,
    onPointerMove: _onMove,
    onPointerUp: _onUp,
    onPointerCancel: (event) {
      _pointers.remove(event.pointer);
      _candidate = null;
    },
    child: widget.child,
  );
}
