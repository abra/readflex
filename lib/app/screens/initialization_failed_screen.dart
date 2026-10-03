// Fallback screen shown when app initialization throws an error.
//
// The bootstrap callback owns recovery and replacement of the app tree.

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final text = context.text;
            final colors = context.colors;
            final l10n = context.l10n;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      l10n.appInitializationFailed,
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.appInitializationFailedBody,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (widget.onRetryInitialization != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: _inProgress,
                        builder: (context, inProgress, _) => FilledButton.icon(
                          onPressed: inProgress ? null : _retryInitialization,
                          icon: inProgress
                              ? const ButtonLoadingIndicator(
                                  size: AppIconSize.sm,
                                )
                              : const Icon(AppIcons.refresh),
                          label: AppButtonLabel(
                            inProgress ? l10n.appRetrying : l10n.appRetry,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    if (kDebugMode)
                      ExpansionTile(
                        title: Text(l10n.appTechnicalDetails),
                        children: [
                          SelectableText(
                            '${widget.error}\n${widget.stackTrace}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
