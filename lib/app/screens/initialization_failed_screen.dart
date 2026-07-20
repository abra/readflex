// Fallback screen shown when app initialization throws an error.
//
// Displayed instead of a blank screen or a crash when composeDependencies()
// fails. The retry button re-invokes composeAndRun() without restarting
// the process.

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

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
    _inProgress.value = true;
    await widget.onRetryInitialization?.call();
    _inProgress.value = false;
  }

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('InitializationFailedScreen');

    return MaterialApp(
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final text = context.text;
            final colors = context.colors;
            final l10n = context.l10n;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.appInitializationFailed,
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${widget.error}',
                    style: text.bodyLarge.copyWith(
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (widget.onRetryInitialization != null)
                    ValueListenableBuilder<bool>(
                      valueListenable: _inProgress,
                      builder: (context, inProgress, _) => FilledButton.icon(
                        onPressed: inProgress ? null : _retryInitialization,
                        icon: inProgress
                            ? const ButtonLoadingIndicator(size: AppIconSize.sm)
                            : const Icon(AppIcons.refresh),
                        label: AppButtonLabel(
                          inProgress ? l10n.appRetrying : l10n.appRetry,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      '${widget.stackTrace}',
                      style: text.bodySmall,
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
