import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Per-step dismiss guard for a sheet shown with `showAppBottomSheet`.
///
/// While [enabled], a scrim tap or a drag-down on the sheet does not pop the
/// route; [onDismissAttempt] runs instead so the step can show its discard
/// confirmation, exactly as its explicit Close does. The drag handle is
/// replaced by a same-height spacer so the title does not move. When
/// [enabled] is false the route's normal dismissal applies, including
/// `scrimClosesFlow`. System Back is not affected; guard it with `PopScope`
/// in the same step.
///
/// Place it once inside the step whose draft needs protection; only the
/// innermost active guard applies.
class AppSheetDismissGuard extends StatefulWidget {
  const AppSheetDismissGuard({
    required this.enabled,
    required this.onDismissAttempt,
    required this.child,
    super.key,
  });

  final bool enabled;
  final VoidCallback onDismissAttempt;
  final Widget child;

  @override
  State<AppSheetDismissGuard> createState() => _AppSheetDismissGuardState();
}

class _AppSheetDismissGuardState extends State<AppSheetDismissGuard> {
  AppSheetDismissRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = AppSheetDismissScope.maybeOf(context);
    if (!identical(registry, _registry)) {
      _registry?.release(this);
      _registry = registry;
    }
    _publish();
  }

  @override
  void didUpdateWidget(AppSheetDismissGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  // Both call sites run inside a build; the route listens above this
  // widget, so the notification is deferred to the end of the frame.
  void _publish() {
    if (_registry == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final registry = _registry;
      if (registry == null) return;
      if (widget.enabled) {
        registry.hold(this, widget.onDismissAttempt);
      } else {
        registry.release(this);
      }
    });
  }

  @override
  void dispose() {
    final registry = _registry;
    if (registry != null) {
      // Unmount runs with the tree locked; the route may still be open
      // (step change), so the release is notified after the frame.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => registry.release(this),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Route-owned registry: the active guard's callback, or null.
///
/// Exposed for `showAppBottomSheet`; feature code uses [AppSheetDismissGuard].
class AppSheetDismissRegistry extends ValueNotifier<VoidCallback?> {
  AppSheetDismissRegistry() : super(null);

  Object? _owner;
  bool _disposed = false;

  void hold(Object owner, VoidCallback onDismissAttempt) {
    if (_disposed) return;
    _owner = owner;
    value = onDismissAttempt;
  }

  void release(Object owner) {
    if (_disposed || !identical(_owner, owner)) return;
    _owner = null;
    value = null;
  }

  bool get guarded => value != null;

  // Guards release themselves while the route's exit animation tears the
  // tree down; the registry may already be gone by then.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Makes the route's [AppSheetDismissRegistry] available to sheet content.
class AppSheetDismissScope extends InheritedWidget {
  const AppSheetDismissScope({
    required this.registry,
    required super.child,
    super.key,
  });

  final AppSheetDismissRegistry registry;

  static AppSheetDismissRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppSheetDismissScope>()
      ?.registry;

  @override
  bool updateShouldNotify(AppSheetDismissScope oldWidget) =>
      !identical(registry, oldWidget.registry);
}
