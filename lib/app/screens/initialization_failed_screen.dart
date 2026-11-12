// Fallback screen shown when app initialization throws an error.
//
// The bootstrap callback owns recovery and replacement of the app tree.

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../readflex_platform_app.dart';

/// Screen shown when app initialization fails, with an optional retry button.
class InitializationFailedScreen extends StatefulWidget {
  const InitializationFailedScreen({
    required this.error,
    required this.stackTrace,
    this.onRetryInitialization,
    super.key,
  });

  final Object error;
  final StackTrace stackTrace;
  final Future<void> Function()? onRetryInitialization;

  @override
  State<InitializationFailedScreen> createState() =>
      _InitializationFailedScreenState();
}

class _InitializationFailedScreenState
    extends State<InitializationFailedScreen> {
  final _inProgress = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _inProgress.dispose();
    super.dispose();
  }

  Future<void> _retryInitialization() async {
    if (_inProgress.value) return;
    _inProgress.value = true;
    try {
      await widget.onRetryInitialization?.call();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'readflex',
          context: ErrorDescription(
            'while retrying application initialization',
          ),
        ),
      );
    } finally {
      if (mounted) _inProgress.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('InitializationFailedScreen');

    return ReadflexPlatformApp(
      home: AppScaffold(
        body: Builder(
          builder: (context) {
            final text = context.text;
            final l10n = context.l10n;

            // The state applies its own 16dp gutter and sits centred in the
            // viewport; the whole page still scrolls when diagnostics expand.
            return SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: widget.onRetryInitialization != null
                              ? ValueListenableBuilder<bool>(
                                  valueListenable: _inProgress,
                                  builder: (context, inProgress, _) =>
                                      ErrorState(
                                        icon: AppIcons.error,
                                        title: l10n.appInitializationFailed,
                                        message:
                                            l10n.appInitializationFailedBody,
                                        // One label keeps the busy geometry
                                        // stable.
                                        retryLabel: l10n.appRetry,
                                        onRetry: _retryInitialization,
                                        busy: inProgress,
                                      ),
                                )
                              // No recovery callback: same frame, without a
                              // command.
                              : EmptyState(
                                  icon: AppIcons.error,
                                  message: l10n.appInitializationFailed,
                                  subtitle: l10n.appInitializationFailedBody,
                                ),
                        ),
                        if (kDebugMode)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: _TechnicalDetails(
                              title: l10n.appTechnicalDetails,
                              child: AppTextSelectionHost(
                                child: SelectableText(
                                  '${widget.error}\n${widget.stackTrace}',
                                  style: text.bodySmall,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TechnicalDetails extends StatefulWidget {
  const _TechnicalDetails({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return ExpansionTile(title: Text(widget.title), children: [widget.child]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: AppButton.text(
            foregroundColor: context.colors.onSurface,
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(child: Text(widget.title)),
                Icon(_expanded ? AppIcons.chevronDown : AppIcons.chevronRight),
              ],
            ),
          ),
        ),
        if (_expanded) widget.child,
      ],
    );
  }
}
