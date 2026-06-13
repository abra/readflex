part of 'reader_screen.dart';

/// Calls [onSourceOpened] once after the reader records a real open timestamp.
class _ReaderSourceOpenedNotifier extends StatefulWidget {
  const _ReaderSourceOpenedNotifier({
    required this.onSourceOpened,
    required this.child,
  });

  final VoidCallback? onSourceOpened;
  final Widget child;

  @override
  State<_ReaderSourceOpenedNotifier> createState() =>
      _ReaderSourceOpenedNotifierState();
}

class _ReaderSourceOpenedNotifierState
    extends State<_ReaderSourceOpenedNotifier> {
  bool _notified = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReaderBloc, ReaderState>(
      listenWhen: (previous, current) {
        if (_notified || current.status != ReaderStatus.ready) {
          return false;
        }
        final previousOpenedAt = previous.book?.lastOpenedAt;
        final currentOpenedAt = current.book?.lastOpenedAt;
        return currentOpenedAt != null && currentOpenedAt != previousOpenedAt;
      },
      listener: (_, _) {
        if (_notified) return;
        _notified = true;
        widget.onSourceOpened?.call();
      },
      child: widget.child,
    );
  }
}

class ReaderKeepAwakeDriver extends StatelessWidget {
  const ReaderKeepAwakeDriver({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final readerReady = context.select<ReaderBloc, bool>(
      (bloc) => bloc.state.status == ReaderStatus.ready,
    );

    return BlocSelector<ReaderUiCubit, ReaderUiState, bool>(
      selector: (state) => state.contentOnlyVisible,
      builder: (context, contentOnlyVisible) {
        return ReaderKeepAwakeScope(
          active: readerReady && contentOnlyVisible,
          child: child,
        );
      },
    );
  }
}

/// Keeps the device awake only while the reader shows bare reading content.
///
/// Chrome panels, drawers, and bottom sheets release keep-awake because the user
/// is interacting with controls rather than passively reading.
class ReaderKeepAwakeScope extends StatefulWidget {
  const ReaderKeepAwakeScope({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  State<ReaderKeepAwakeScope> createState() => _ReaderKeepAwakeScopeState();
}

/// Synchronizes keep-awake with both reader visibility and app foreground state.
class _ReaderKeepAwakeScopeState extends State<ReaderKeepAwakeScope>
    with WidgetsBindingObserver {
  late ReaderKeepAwakeCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<ReaderKeepAwakeCubit>();
    _cubit.setActive(widget.active);
  }

  @override
  void didUpdateWidget(ReaderKeepAwakeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _cubit.setActive(widget.active);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cubit.appLifecycleChanged(state);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cubit.appLifecycleChanged(state);
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.setActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Activates temporary reader brightness while this route is foregrounded.
class ReaderBrightnessLifecycleScope extends StatefulWidget {
  const ReaderBrightnessLifecycleScope({
    required this.cubit,
    required this.child,
    super.key,
  });

  final ReaderBrightnessCubit cubit;
  final Widget child;

  @override
  State<ReaderBrightnessLifecycleScope> createState() =>
      _ReaderBrightnessLifecycleScopeState();
}

/// Resets reader brightness when the app backgrounds, route disposes, or the
/// brightness cubit instance changes.
class _ReaderBrightnessLifecycleScopeState
    extends State<ReaderBrightnessLifecycleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.cubit.activate();
  }

  @override
  void didUpdateWidget(ReaderBrightnessLifecycleScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cubit == oldWidget.cubit) return;
    unawaited(oldWidget.cubit.deactivate());
    widget.cubit.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.cubit.activate();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(widget.cubit.deactivate());
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.cubit.deactivate());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
