import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'app_button.dart';
import 'app_button_label.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_sizes.dart';

/// Confirms a command on the root navigator. Only an explicit confirm is true.
/// Cancel returns false; system Back or the Material scrim returns null.
Future<bool?> showAppConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final reduceMotion = context.reduceMotion;
  final direction = Directionality.of(context);
  final dialog = Builder(
    builder: (dialogContext) => Directionality(
      textDirection: direction,
      child: AppConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        onConfirm: () => _completeConfirmation(dialogContext, true),
        onCancel: () => _completeConfirmation(dialogContext, false),
      ),
    ),
  );
  if (context.isCupertino) {
    final themes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    return navigator.push<bool>(
      _CupertinoConfirmationRoute(
        context: context,
        reduceMotion: reduceMotion,
        builder: (_) => themes.wrap(dialog),
      ),
    );
  }
  return material.showDialog<bool>(
    context: context,
    useRootNavigator: true,
    requestFocus: true,
    animationStyle: reduceMotion ? material.AnimationStyle.noAnimation : null,
    builder: (_) => dialog,
  );
}

void _completeConfirmation(BuildContext context, bool confirmed) {
  // An exiting dialog must not let a repeated tap pop the page beneath it.
  if (ModalRoute.of(context)?.isCurrent ?? false) {
    Navigator.of(context, rootNavigator: true).pop(confirmed);
  }
}

/// Platform alert presentation with caller-owned text and commands.
/// Cancellation is the default keyboard action; destructive text uses error.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
    this.destructive = false,
    super.key,
  });

  static const confirmButtonKey = ValueKey('appConfirmationConfirm');
  static const cancelButtonKey = ValueKey('appConfirmationCancel');

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return cupertino.CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        insetAnimationDuration: context.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 100),
        actions: [
          _CupertinoConfirmationAction(
            key: cancelButtonKey,
            label: cancelLabel,
            onPressed: onCancel,
            defaultAction: true,
          ),
          _CupertinoConfirmationAction(
            key: confirmButtonKey,
            label: confirmLabel,
            onPressed: onConfirm,
            destructive: destructive,
          ),
        ],
      );
    }
    return material.AlertDialog(
      title: Text(title),
      content: Text(message),
      scrollable: true,
      actions: [
        AppButton.text(
          key: cancelButtonKey,
          onPressed: onCancel,
          autofocus: true,
          child: AppButtonLabel(cancelLabel, maxLines: null),
        ),
        AppButton.text(
          key: confirmButtonKey,
          onPressed: onConfirm,
          foregroundColor: destructive ? context.colors.error : null,
          child: AppButtonLabel(confirmLabel, maxLines: null),
        ),
      ],
    );
  }
}

class _CupertinoConfirmationAction extends StatelessWidget {
  const _CupertinoConfirmationAction({
    required this.label,
    required this.onPressed,
    this.defaultAction = false,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool defaultAction;
  final bool destructive;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    autofocus: defaultAction,
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          onPressed();
          return null;
        },
      ),
    },
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
      // The native accessibility-size policy omits action semantics.
      child: Semantics(
        button: true,
        enabled: true,
        onTap: onPressed,
        child: cupertino.CupertinoDialogAction(
          onPressed: onPressed,
          isDefaultAction: defaultAction,
          isDestructiveAction: destructive,
          textStyle: TextStyle(
            color: destructive
                ? context.colors.error
                : context.actionForeground,
          ),
          child: AppButtonLabel(label, maxLines: null),
        ),
      ),
    ),
  );
}

class _CupertinoConfirmationRoute extends cupertino.CupertinoDialogRoute<bool> {
  _CupertinoConfirmationRoute({
    required super.context,
    required super.builder,
    required this.reduceMotion,
  }) : super(barrierDismissible: false, requestFocus: true);

  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Simulation createSimulation({required bool forward}) => reduceMotion
      ? _ConfirmationRestSimulation(forward ? 1 : 0)
      : super.createSimulation(forward: forward);
}

class _ConfirmationRestSimulation extends Simulation {
  _ConfirmationRestSimulation(this.value);

  final double value;

  @override
  double x(double time) => value;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => true;
}
