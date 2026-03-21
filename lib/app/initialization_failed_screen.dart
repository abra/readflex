// Fallback screen shown when app initialization throws an error.
//
// Displayed instead of a blank screen or a crash when composeDependencies()
// fails. The retry button re-invokes composeAndRun() without restarting
// the process.

import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final typography = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Initialization failed', style: typography.headlineMedium),
              const SizedBox(height: 16),
              Text(
                '${widget.error}',
                style: typography.bodyLarge?.copyWith(color: colorScheme.error),
              ),
              const SizedBox(height: 24),
              if (widget.onRetryInitialization != null)
                ValueListenableBuilder<bool>(
                  valueListenable: _inProgress,
                  builder: (context, inProgress, _) => FilledButton.icon(
                    onPressed: inProgress ? null : _retryInitialization,
                    icon: inProgress
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(inProgress ? 'Retrying...' : 'Retry'),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${widget.stackTrace}',
                  style: typography.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
