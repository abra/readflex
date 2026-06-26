import 'dart:async';

import 'package:flutter/widgets.dart';

typedef ReaderRouteMountGateBuilder =
    Widget Function(BuildContext context, bool canMountChild);

/// Defers heavy reader subtree mounting until the reader route has had time to
/// finish its entrance animation.
class ReaderRouteMountGate extends StatefulWidget {
  const ReaderRouteMountGate({
    required this.builder,
    this.delay = Duration.zero,
    super.key,
  });

  final Duration delay;
  final ReaderRouteMountGateBuilder builder;

  @override
  State<ReaderRouteMountGate> createState() => _ReaderRouteMountGateState();
}

class _ReaderRouteMountGateState extends State<ReaderRouteMountGate> {
  Timer? _mountTimer;
  late bool _canMountChild = widget.delay == Duration.zero;

  @override
  void initState() {
    super.initState();
    _scheduleMount();
  }

  @override
  void didUpdateWidget(covariant ReaderRouteMountGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_canMountChild || oldWidget.delay == widget.delay) return;
    _scheduleMount();
  }

  @override
  void dispose() {
    _mountTimer?.cancel();
    super.dispose();
  }

  void _scheduleMount() {
    _mountTimer?.cancel();
    if (widget.delay == Duration.zero) {
      _canMountChild = true;
      return;
    }
    _mountTimer = Timer(widget.delay, _allowMount);
  }

  void _allowMount() {
    if (_canMountChild) return;
    _mountTimer?.cancel();
    _mountTimer = null;
    if (!mounted) {
      _canMountChild = true;
      return;
    }
    setState(() => _canMountChild = true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _canMountChild);
  }
}
