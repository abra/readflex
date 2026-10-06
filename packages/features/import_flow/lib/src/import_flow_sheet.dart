import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'import_flow_cubit.dart';
import 'import_flow_result.dart';

/// Shows the multi-step Add-to-Library bottom sheet.
///
/// The sheet is driven by an [ImportFlowCubit] over a sealed
/// [ImportFlowState] hierarchy: menu → uploading → done.
///
/// Two callbacks are injected from the composition root:
///   * [onPickBookFile] opens the platform file picker and returns the
///     selected file (or `null` on cancel).
///   * [onImportBook] takes that file, parses metadata, and persists
///     the book — exposing byte-level progress through `onProgress` so
///     the sheet can show a real progress bar.
///   * [isOffline] / [isOfflineStream] disable article import because it
///     depends on network extraction; local book uploads remain available.
///   * [onOpenTerms] and [onOpenPrivacy] open legal documents outside
///     the sheet; the cubit never launches URLs directly.
///
/// Returns [ImportFlowResult.bookImported] when the user finished an
/// import, or `null` if they dismissed without finishing.
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required PickBookFile onPickBookFile,
  required ImportBookFile onImportBook,
  required ImportArticleUrl onImportArticle,
  bool isOffline = false,
  Stream<bool>? isOfflineStream,
  IsBookImportTermsAccepted? isBookImportTermsAccepted,
  AcceptBookImportTerms? acceptBookImportTerms,
  Future<void> Function()? onOpenTerms,
  Future<void> Function()? onOpenPrivacy,
}) {
  return showAppBottomSheet<ImportFlowResult>(
    context,
    scrimClosesFlow: true,
    builder: (_) => BlocProvider(
      create: (_) => ImportFlowCubit(
        onPickBookFile: onPickBookFile,
        onImportBook: onImportBook,
        onImportArticle: onImportArticle,
        isBookImportTermsAccepted: isBookImportTermsAccepted,
        acceptBookImportTerms: acceptBookImportTerms,
      ),
      child: _ImportFlowSheet(
        isOffline: isOffline,
        isOfflineStream: isOfflineStream,
        onOpenTerms: onOpenTerms ?? _noopFuture,
        onOpenPrivacy: onOpenPrivacy ?? _noopFuture,
      ),
    ),
  );
}

/// Import-flow shell bound to [ImportFlowCubit].
class _ImportFlowSheet extends StatefulWidget {
  const _ImportFlowSheet({
    required this.isOffline,
    required this.isOfflineStream,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool isOffline;
  final Stream<bool>? isOfflineStream;
  final Future<void> Function() onOpenTerms;
  final Future<void> Function() onOpenPrivacy;

  @override
  State<_ImportFlowSheet> createState() => _ImportFlowSheetState();
}

class _ImportFlowSheetState extends State<_ImportFlowSheet> {
  // UI-only: the cubit keeps the URL draft; this only shows the decision.
  var _confirmingDiscard = false;

  bool _hasDraft(ImportFlowState state) =>
      state is ImportFlowArticleUrlEntry && state.url.trim().isNotEmpty;

  /// Close, scrim and drag-down: a typed URL asks before leaving the flow.
  void _requestClose() {
    if (!_hasDraft(context.read<ImportFlowCubit>().state)) {
      Navigator.of(context).pop();
      return;
    }
    // Repeated attempts keep the decision visible until the user chooses.
    if (_confirmingDiscard) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _confirmingDiscard = true);
  }

  void _keepEditing() => setState(() => _confirmingDiscard = false);

  void _discardDraft() => Navigator.of(context).pop();

  void _backToMenu() {
    FocusManager.instance.primaryFocus?.unfocus();
    _confirmingDiscard = false;
    context.read<ImportFlowCubit>().backToMenu();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.isOfflineStream,
      initialData: widget.isOffline,
      builder: (context, snapshot) {
        final isOffline = snapshot.data ?? widget.isOffline;
        return BlocBuilder<ImportFlowCubit, ImportFlowState>(
          builder: (context, state) {
            // Keep compact steps level; consent can grow for longer text.
            // The viewport still bounds every step.
            final stepHeight =
                272 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                  1.0,
                  3.0,
                );
            final hasPreviousStep =
                state is ImportFlowArticleUrlEntry ||
                state is ImportFlowBookTermsRequired;
            final confirmingDiscard = _confirmingDiscard && _hasDraft(state);
            // Status steps carry the flow header above the same content box.
            final isStatusStep = switch (state) {
              ImportFlowBookUploading() ||
              ImportFlowArticleUploading() ||
              ImportFlowBookDone() ||
              ImportFlowArticleDone() ||
              ImportFlowFailure() => true,
              ImportFlowMenu() ||
              ImportFlowBookTermsRequired() ||
              ImportFlowArticleUrlEntry() => false,
            };
            final step = _ImportFlowStepSwitcher(
              state: state,
              confirmingDiscard: confirmingDiscard,
              child: ConstrainedBox(
                key: confirmingDiscard
                    ? const ValueKey('importFlowDiscardStep')
                    : ValueKey(state.runtimeType),
                constraints: BoxConstraints(minHeight: stepHeight),
                child: SizedBox(
                  height: state is ImportFlowBookTermsRequired
                      ? null
                      : isStatusStep
                      ? stepHeight + _kStatusHeaderExtent
                      : stepHeight,
                  child: switch (state) {
                    ImportFlowMenu() => _MenuView(isOffline: isOffline),
                    ImportFlowBookTermsRequired() => _BookTermsView(
                      onOpenTerms: widget.onOpenTerms,
                      onOpenPrivacy: widget.onOpenPrivacy,
                    ),
                    ImportFlowArticleUrlEntry() => AppSheetDismissGuard(
                      enabled: _hasDraft(state),
                      onDismissAttempt: _requestClose,
                      child: confirmingDiscard
                          ? _DiscardDraftView(
                              onKeepEditing: _keepEditing,
                              onDiscard: _discardDraft,
                              onClose: _requestClose,
                            )
                          : _ArticleUrlEntryView(
                              state: state,
                              isOffline: isOffline,
                              onBack: _backToMenu,
                              onClose: _requestClose,
                            ),
                    ),
                    ImportFlowBookUploading() => _BookUploadingView(
                      state: state,
                    ),
                    ImportFlowArticleUploading() => _ArticleUploadingView(
                      state: state,
                    ),
                    ImportFlowBookDone() => _BookDoneView(state: state),
                    ImportFlowArticleDone() => _ArticleDoneView(state: state),
                    ImportFlowFailure() => _FailureView(state: state),
                  },
                ),
              ),
            );
            // Storage work in flight: the greyed Close already says "wait",
            // so scrim, drag and system Back must not dismiss either.
            final working =
                state is ImportFlowBookUploading ||
                state is ImportFlowArticleUploading;
            return PopScope(
              canPop: !hasPreviousStep && !working,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop || working || !hasPreviousStep) return;
                // Back is a step back, not a dismissal: the draft is kept.
                if (confirmingDiscard) {
                  _keepEditing();
                } else {
                  _backToMenu();
                }
              },
              child: context.reduceMotion
                  ? step
                  : AnimatedSize(
                      duration: context.motion(AppMotion.medium),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.bottomCenter,
                      child: step,
                    ),
            );
          },
        );
      },
    );
  }
}

/// Chooses the animated transition style when the import flow changes state.
///
/// Menu/form steps slide horizontally, while upload terminal states use a
/// softer fade+scale transition.
class _ImportFlowStepSwitcher extends StatefulWidget {
  const _ImportFlowStepSwitcher({
    required this.state,
    required this.confirmingDiscard,
    required this.child,
  });

  final ImportFlowState state;
  final bool confirmingDiscard;
  final Widget child;

  @override
  State<_ImportFlowStepSwitcher> createState() =>
      _ImportFlowStepSwitcherState();
}

class _ImportFlowStepSwitcherState extends State<_ImportFlowStepSwitcher> {
  var _slideDirection = 1;
  var _transitionStyle = _ImportFlowTransitionStyle.slide;

  @override
  void didUpdateWidget(covariant _ImportFlowStepSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.runtimeType != widget.state.runtimeType) {
      _slideDirection = _transitionDirection(oldWidget.state, widget.state);
      _transitionStyle = _transitionStyleFor(oldWidget.state, widget.state);
    } else if (oldWidget.confirmingDiscard != widget.confirmingDiscard) {
      // The discard decision is one step deeper than the form.
      _slideDirection = widget.confirmingDiscard ? 1 : -1;
      _transitionStyle = _ImportFlowTransitionStyle.slide;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(AppMotion.medium);
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) => ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outgoing steps animate within the current step's bounds; they
            // must not hold the sheet at the height of the previous form.
            for (final child in previousChildren) Positioned.fill(child: child),
            ?currentChild,
          ],
        ),
      ),
      transitionBuilder: (child, animation) {
        if (_transitionStyle == _ImportFlowTransitionStyle.status) {
          return _ImportFlowStatusTransition(
            animation: animation,
            child: child,
          );
        }
        return _ImportFlowSlideTransition(
          animation: animation,
          direction: _slideDirection,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

enum _ImportFlowTransitionStyle { slide, status }

_ImportFlowTransitionStyle _transitionStyleFor(
  ImportFlowState from,
  ImportFlowState to,
) {
  return switch ((from, to)) {
    (ImportFlowArticleUploading(), ImportFlowArticleDone()) ||
    (ImportFlowArticleUploading(), ImportFlowFailure()) ||
    (
      ImportFlowBookUploading(),
      ImportFlowBookDone(),
    ) ||
    (
      ImportFlowBookUploading(),
      ImportFlowFailure(),
    ) => _ImportFlowTransitionStyle.status,
    _ => _ImportFlowTransitionStyle.slide,
  };
}

/// Directional slide used for menu/form navigation inside the import flow.
class _ImportFlowSlideTransition extends StatelessWidget {
  const _ImportFlowSlideTransition({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = Curves.easeInOutCubic.transform(animation.value);
        final isExiting = animation.status == AnimationStatus.reverse;
        final sign = isExiting ? -direction : direction;
        return FractionalTranslation(
          translation: Offset(
            sign *
                (Directionality.of(context) == TextDirection.rtl ? -1 : 1) *
                (1 - value),
            0,
          ),
          child: child,
        );
      },
    );
  }
}

/// Fade+scale transition for upload progress, success, and failure states.
class _ImportFlowStatusTransition extends StatelessWidget {
  const _ImportFlowStatusTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      key: const ValueKey('importFlowStatusTransition'),
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

int _transitionDirection(ImportFlowState from, ImportFlowState to) {
  final fromDepth = _navigationDepth(from);
  final toDepth = _navigationDepth(to);
  return toDepth < fromDepth ? -1 : 1;
}

int _navigationDepth(ImportFlowState state) {
  return switch (state) {
    ImportFlowMenu() => 0,
    ImportFlowBookTermsRequired() ||
    ImportFlowArticleUrlEntry() ||
    ImportFlowBookUploading() => 1,
    ImportFlowArticleUploading() ||
    ImportFlowBookDone() ||
    ImportFlowFailure() => 2,
    ImportFlowArticleDone() => 3,
  };
}

/// Import choices with a persistent close action above the scrollable rows.
class _MenuView extends StatelessWidget {
  const _MenuView({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();
    final warning = context.appColors.warning;
    final l10n = context.l10n;

    return SizedBox.expand(
      child: ActionBottomSheetLayout(
        title: l10n.importAddToLibraryTitle,
        onClose: () => Navigator.of(context).pop(),
        closeLabel: l10n.commonClose,
        headerSpacing: AppSpacing.sm,
        constrainBody: true,
        child: LayoutBuilder(
          // Center short content in the shared step height; let longer
          // translations scroll without intrinsic measurement or fixed rows.
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDrillInRow(
                    key: const ValueKey('importMenu-book'),
                    icon: AppIcons.book,
                    title: l10n.importUploadBook,
                    subtitle: l10n.importUploadBookFormats,
                    padding: _kMenuRowPadding,
                    onTap: cubit.requestBookImport,
                  ),
                  const Divider(),
                  AppDrillInRow(
                    key: const ValueKey('importMenu-article'),
                    icon: isOffline ? AppIcons.offline : AppIcons.link,
                    iconColor: isOffline ? warning : null,
                    title: l10n.importSaveArticle,
                    // Say why the row is disabled instead of a stale promise.
                    subtitle: isOffline
                        ? l10n.importArticleOfflineSubtitle
                        : l10n.importSaveArticleDescription,
                    padding: _kMenuRowPadding,
                    // Offline keeps the warning glyph and drops the chevron.
                    trailing: isOffline
                        ? const SizedBox(width: AppIconSize.sm)
                        : null,
                    enabled: !isOffline,
                    onTap: isOffline ? null : cubit.showArticleUrlEntry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _kMenuRowPadding = EdgeInsets.symmetric(vertical: AppSpacing.xl);

/// Terms acceptance step shown before importing a local book file.
class _BookTermsView extends StatefulWidget {
  const _BookTermsView({
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final Future<void> Function() onOpenTerms;
  final Future<void> Function() onOpenPrivacy;

  @override
  State<_BookTermsView> createState() => _BookTermsViewState();
}

class _BookTermsViewState extends State<_BookTermsView> {
  var _accepted = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;

    return _ImportFormLayout(
      title: l10n.importBeforeUploadingTitle,
      onBack: cubit.cancelBookImportTerms,
      onClose: () => Navigator.of(context).pop(),
      fitContent: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.importBookTermsBody,
            style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          _BookTermsLinks(
            onOpenTerms: widget.onOpenTerms,
            onOpenPrivacy: widget.onOpenPrivacy,
          ),
          const SizedBox(height: AppSpacing.sm),
          _BookTermsCheckbox(
            accepted: _accepted,
            onChanged: (value) => setState(() => _accepted = value),
          ),
        ],
      ),
      actions: FilledButton(
        onPressed: _accepted ? cubit.acceptTermsAndPickBook : null,
        child: AppButtonLabel(l10n.commonContinue),
      ),
    );
  }
}

class _BookTermsCheckbox extends StatelessWidget {
  const _BookTermsCheckbox({
    required this.accepted,
    required this.onChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => onChanged(!accepted),
        child: Row(
          children: [
            Checkbox(
              value: accepted,
              onChanged: (value) => onChanged(value ?? false),
              visualDensity: VisualDensity.standard,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.importBookTermsConfirm,
                style: context.text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTermsLinks extends StatefulWidget {
  const _BookTermsLinks({
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final Future<void> Function() onOpenTerms;
  final Future<void> Function() onOpenPrivacy;

  @override
  State<_BookTermsLinks> createState() => _BookTermsLinksState();
}

class _BookTermsLinksState extends State<_BookTermsLinks> {
  late final _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => widget.onOpenTerms();
  late final _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => widget.onOpenPrivacy();

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final linkStyle = TextStyle(
      color: context.actionForeground,
      decoration: TextDecoration.underline,
      decorationColor: context.actionForeground,
    );
    // Inline links share the paragraph's line boxes, not button-sized rows.
    return Text.rich(
      key: const ValueKey('importFlowLegalText'),
      TextSpan(
        children: [
          TextSpan(text: l10n.importLegalPrefix),
          TextSpan(
            text: l10n.importTerms,
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          TextSpan(text: l10n.importLegalAnd),
          TextSpan(
            text: l10n.importPrivacyPolicy,
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          TextSpan(text: l10n.importLegalSuffix),
        ],
      ),
      style: context.text.bodySmall.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

Future<void> _noopFuture() async {}

String? _errorMessageFor(
  BuildContext context,
  ImportFlowErrorCode? errorCode,
) {
  if (errorCode == null) return null;
  return _localizedErrorMessage(context, errorCode);
}

String _failureMessageFor(BuildContext context, ImportFlowFailure state) {
  final code = state.errorCode;
  if (code != null) return _localizedErrorMessage(context, code);
  return state.customMessage ?? context.l10n.importBookImportFailed;
}

String _localizedErrorMessage(
  BuildContext context,
  ImportFlowErrorCode errorCode,
) {
  final l10n = context.l10n;
  return switch (errorCode) {
    ImportFlowErrorCode.articleUrlRequired => l10n.importArticleUrlRequired,
    ImportFlowErrorCode.invalidArticleUrl => l10n.importInvalidArticleUrl,
    ImportFlowErrorCode.clipboardUnavailable => l10n.importClipboardUnavailable,
    ImportFlowErrorCode.bookImportFailed => l10n.importBookImportFailed,
    ImportFlowErrorCode.articleSaveFailed => l10n.importArticleSaveFailed,
  };
}

/// URL entry step for article import.
class _ArticleUrlEntryView extends StatefulWidget {
  const _ArticleUrlEntryView({
    required this.state,
    required this.isOffline,
    required this.onBack,
    required this.onClose,
  });

  final ImportFlowArticleUrlEntry state;
  final bool isOffline;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  State<_ArticleUrlEntryView> createState() => _ArticleUrlEntryViewState();
}

class _ArticleUrlEntryViewState extends State<_ArticleUrlEntryView> {
  late final _controller = TextEditingController(text: widget.state.url);
  int _pasteRequest = 0;

  @override
  void didUpdateWidget(covariant _ArticleUrlEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final url = widget.state.url;
    if (_controller.text == url) return;
    _controller.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboardArticleUrl() async {
    final cubit = context.read<ImportFlowCubit>();
    final entryState = cubit.state;
    final request = ++_pasteRequest;
    final value = _controller.value;
    // Ignore clipboard replies after editing, navigation, or a newer paste.
    bool isCurrent() =>
        mounted &&
        !cubit.isClosed &&
        request == _pasteRequest &&
        identical(cubit.state, entryState) &&
        _controller.value == value;

    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      if (isCurrent()) cubit.articleClipboardUnavailable();
      return;
    }
    if (isCurrent()) cubit.articleUrlPasted(data?.text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();
    final colors = context.colors;
    final muted = colors.onSurfaceVariant;
    final l10n = context.l10n;
    final error = _errorMessageFor(context, widget.state.errorCode);

    return _ImportFormLayout(
      title: l10n.importSaveArticle,
      onBack: widget.onBack,
      onClose: widget.onClose,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: l10n.importArticleUrlHint,
              // Offline disables Save; say so where the eye already is.
              helper: _ArticleUrlFeedback(
                key: const ValueKey('articleUrlOfflineHint'),
                message: widget.isOffline ? l10n.importOfflineHint : null,
                isError: false,
              ),
              error: error == null ? null : _ArticleUrlFeedback(message: error),
              suffixIcon: AppPlainIconButton(
                key: const ValueKey('articleUrlPasteButton'),
                tooltip: l10n.importPasteUrl,
                icon: AppIcons.paste,
                color: context.actionForeground,
                onPressed: _pasteClipboardArticleUrl,
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: AppSizes.buttonHeight,
                height: AppSizes.buttonHeight,
              ),
            ),
            onSubmitted: widget.isOffline
                ? null
                : (_) => cubit.submitArticleUrl(),
            onChanged: cubit.articleUrlChanged,
          ),
        ],
      ),
      hints: _ArticleUrlHints(color: muted),
      actions: FilledButton(
        onPressed: widget.isOffline || !widget.state.canSubmit
            ? null
            : cubit.submitArticleUrl,
        child: AppButtonLabel(l10n.commonSave),
      ),
    );
  }
}

/// Reserves the same space for every localized validation message, even when
/// there is no error. Layout follows the actual font, text scale, and width.
class _ArticleUrlFeedback extends StatelessWidget {
  const _ArticleUrlFeedback({this.message, this.isError = true, super.key});

  final String? message;

  /// Errors use the error colour; status hints (offline) stay muted.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = context.text.bodySmall.copyWith(
      color: isError ? context.colors.error : context.colors.onSurfaceVariant,
    );
    return Stack(
      alignment: AlignmentDirectional.topStart,
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: Stack(
              children: [
                for (final text in [
                  l10n.importArticleUrlRequired,
                  l10n.importInvalidArticleUrl,
                  l10n.importClipboardUnavailable,
                  l10n.importOfflineHint,
                ])
                  RichText(
                    text: TextSpan(text: text, style: style),
                    textScaler: MediaQuery.textScalerOf(context),
                    locale: Localizations.localeOf(context),
                  ),
              ],
            ),
          ),
        ),
        if (message != null)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: Text(message!, style: style),
          ),
      ],
    );
  }
}

/// Uses the available height without intrinsic layout or unbounded flex.
class _ImportFormLayout extends StatelessWidget {
  const _ImportFormLayout({
    required this.title,
    required this.onBack,
    required this.onClose,
    required this.content,
    this.hints,
    required this.actions,
    this.fitContent = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final Widget content;
  final Widget? hints;
  final Widget actions;
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final hintGroup = hints == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: hints,
              );
        // On very short viewports, even header + actions can exceed the height.
        // Keep every control reachable by scrolling the complete form instead.
        if (constraints.maxHeight < 240 * scale) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BottomSheetHeader(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  title: title,
                  onBack: onBack,
                  backLabel: context.l10n.commonBack,
                  closeLabel: context.l10n.commonClose,
                  onClose: onClose,
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: _kStatusViewPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      ?hintGroup,
                      const SizedBox(height: AppSpacing.sm),
                      actions,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return ActionBottomSheetLayout(
          title: title,
          onBack: onBack,
          backLabel: context.l10n.commonBack,
          closeLabel: context.l10n.commonClose,
          onClose: onClose,
          constrainBody: true,
          bodyPadding: EdgeInsets.zero,
          footer: actions,
          child: LayoutBuilder(
            builder: (context, bodyConstraints) => ScrollEdgeFadeStack(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: ConstrainedBox(
                  // Give free space to the field/hints gap, while long
                  // forms still scroll without intrinsic measurement.
                  constraints: BoxConstraints(
                    minHeight: fitContent ? 0 : bodyConstraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [content, ?hintGroup],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Discard decision for a typed article URL. Keep editing is the filled
/// default; Close keeps the decision visible until the user chooses.
class _DiscardDraftView extends StatelessWidget {
  const _DiscardDraftView({
    required this.onKeepEditing,
    required this.onDiscard,
    required this.onClose,
  });

  final VoidCallback onKeepEditing;
  final VoidCallback onDiscard;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ImportFormLayout(
      title: l10n.commonDiscardChangesTitle,
      onBack: onKeepEditing,
      onClose: onClose,
      fitContent: true,
      content: Text(
        l10n.importDiscardUrlBody,
        style: context.text.bodyMedium.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      actions: AppSheetActions(
        primaryLabel: l10n.commonKeepEditing,
        onPrimary: onKeepEditing,
        secondaryLabel: l10n.commonDiscardChanges,
        onSecondary: onDiscard,
        destructiveSecondary: true,
      ),
    );
  }
}

class _ArticleUrlHints extends StatelessWidget {
  const _ArticleUrlHints({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArticleUrlHint(
          text: context.l10n.importArticleHintClean,
          color: color,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ArticleUrlHint(
          text: context.l10n.importArticleHintSource,
          color: color,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ArticleUrlHint(
          text: context.l10n.importArticleHintLibrary,
          color: color,
        ),
      ],
    );
  }
}

class _ArticleUrlHint extends StatelessWidget {
  const _ArticleUrlHint({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 4, height: 4),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.labelSmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Local import uses one bar; copy completion is not repository completion.
class _BookUploadingView extends StatelessWidget {
  const _BookUploadingView({required this.state});

  final ImportFlowBookUploading state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurfaceVariant;
    final progress = state.progress;

    return _StatusLayout(
      closable: false,
      reserveActionSpace: true,
      content: _BookUploadStatusContent(
        filename: state.filename,
        progress: progress,
        titleStyle: text.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        detailStyle: text.bodySmall.copyWith(color: muted),
        progressBackgroundColor: cs.surfaceContainerHighest,
        progressColor: context.actionForeground,
      ),
    );
  }
}

/// Progress/status body for local book import.
class _BookUploadStatusContent extends StatelessWidget {
  const _BookUploadStatusContent({
    required this.filename,
    required this.titleStyle,
    required this.detailStyle,
    required this.progressBackgroundColor,
    required this.progressColor,
    this.progress,
  });

  final String filename;
  final double? progress;
  final TextStyle titleStyle;
  final TextStyle detailStyle;
  final Color progressBackgroundColor;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finishing = progress != null && progress! >= 1;
    final phase = progress == null
        ? l10n.importPreparingBook
        : finishing
        ? l10n.importFinishingBook
        : l10n.importCopyingBook;
    return LayoutBuilder(
      builder: (context, constraints) {
        final percent = TextPainter(
          text: TextSpan(text: '100%', style: detailStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final labelWidth = math.max(
          1.0,
          constraints.maxWidth - percent.width - AppSpacing.sm,
        );
        var labelHeight = percent.height;
        percent.dispose();
        for (final label in [
          l10n.importPreparingBook,
          l10n.importCopyingBook,
          l10n.importFinishingBook,
        ]) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: detailStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: labelWidth);
          labelHeight = math.max(labelHeight, painter.height);
          painter.dispose();
        }
        // Balance the footer above the status block, keeping its icon aligned
        // with success/failure while translated phase labels change below it.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.md + 6 + AppSpacing.xs + labelHeight),
            Center(
              child: _StatusIconSlot(
                key: const ValueKey('importFlowStatusIcon'),
                child: Icon(
                  AppIcons.book,
                  color: context.actionForeground,
                  size: AppIconSize.lg,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.importUploadingBook,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
            const SizedBox(height: 2),
            Text(
              filename,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: detailStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: finishing ? null : progress,
                minHeight: 6,
                backgroundColor: progressBackgroundColor,
                color: progressColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: labelHeight,
              child: Row(
                children: [
                  Expanded(child: Text(phase, style: detailStyle)),
                  const SizedBox(width: AppSpacing.sm),
                  Visibility(
                    visible: progress != null && !finishing,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      '${((progress ?? 0) * 100).clamp(0, 100).toInt()}%',
                      style: detailStyle.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Progress/status body for article extraction and persistence.
class _ArticleUploadingView extends StatelessWidget {
  const _ArticleUploadingView({required this.state});

  final ImportFlowArticleUploading state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return _StatusLayout(
      closable: false,
      reserveActionSpace: true,
      content: _StatusContent(
        icon: const _StatusIconSlot(
          key: ValueKey('importFlowStatusIcon'),
          child: CenteredCircularProgressIndicator(),
        ),
        title: _articleUploadingTitle(context, state.stage),
        detail: state.url,
        titleStyle: text.bodyMedium.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
        detailStyle: text.bodySmall.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _articleUploadingTitle(
  BuildContext context,
  ImportFlowArticleStage stage,
) => switch (stage) {
  ImportFlowArticleStage.fetching => context.l10n.importFetchingArticle,
  ImportFlowArticleStage.saving => context.l10n.importSavingArticle,
};

/// Shared vertical layout for upload/progress states, under the flow's
/// header so Close stays where the menu put it.
///
/// [reserveActionSpace] keeps the sheet height stable before a retry/done action
/// appears. [closable] is false while storage work is in flight; the step
/// then swallows scrim and drag dismissal as well.
void _ignoreDismissAttempt() {}

class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    required this.content,
    required this.closable,
    this.action,
    this.reserveActionSpace = false,
  });

  final Widget content;
  final bool closable;
  final Widget? action;
  final bool reserveActionSpace;

  @override
  Widget build(BuildContext context) {
    final layout = _buildLayout(context);
    if (closable) return layout;
    return AppSheetDismissGuard(
      enabled: true,
      onDismissAttempt: _ignoreDismissAttempt,
      child: layout,
    );
  }

  Widget _buildLayout(BuildContext context) {
    final l10n = context.l10n;
    final onClose = closable ? () => Navigator.of(context).pop() : null;
    final actionSlot =
        action ??
        (reserveActionSpace
            ? const SizedBox(height: _kStatusActionHeight)
            : null);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        // Keyboard or large text can leave less than the header and stacked
        // actions need; scroll the whole step like the URL form does.
        if (constraints.maxHeight < 240 * scale) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BottomSheetHeader(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  title: l10n.importAddToLibraryTitle,
                  closeLabel: l10n.commonClose,
                  onClose: onClose,
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: _kStatusViewPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: AppSpacing.sm),
                      ?actionSlot,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return ActionBottomSheetLayout(
          title: l10n.importAddToLibraryTitle,
          onClose: onClose,
          closeLabel: l10n.commonClose,
          headerSpacing: AppSpacing.sm,
          constrainBody: true,
          bodyPadding: _kStatusViewPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(child: SingleChildScrollView(child: content)),
              ),
              const SizedBox(height: AppSpacing.sm),
              ?actionSlot,
            ],
          ),
        );
      },
    );
  }
}

/// Icon, title, detail, and optional subtitle block used by status screens.
class _StatusContent extends StatelessWidget {
  const _StatusContent({
    required this.icon,
    required this.title,
    required this.detail,
    required this.titleStyle,
    required this.detailStyle,
    this.subtitle,
  });

  final Widget icon;
  final String title;
  final String? detail;
  final TextStyle titleStyle;
  final TextStyle detailStyle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: icon),
        const SizedBox(height: AppSpacing.md),
        Text(title, textAlign: TextAlign.center, style: titleStyle),
        const SizedBox(height: 2),
        if (detail != null && detail!.isNotEmpty)
          Text(
            detail!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: detailStyle,
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: detailStyle,
          ),
        ],
      ],
    );
  }
}

const _kStatusActionHeight = AppSizes.buttonHeight;

/// Header row plus its body gap, added to the shared step height so status
/// content keeps the room it had before the header was introduced.
const _kStatusHeaderExtent = AppSizes.buttonHeight + AppSpacing.sm;

/// Body insets for the status steps (uploading, done, failure), matching the
/// [_MenuView] gutter below the shared header.
const _kStatusViewPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  0,
  AppSpacing.xl,
  AppSpacing.lg,
);

/// Book import succeeded — checkmark, filename, optional estimate, Done.
class _BookDoneView extends StatelessWidget {
  const _BookDoneView({required this.state});

  final ImportFlowBookDone state;

  @override
  Widget build(BuildContext context) {
    // CBZ is the only comic format the picker accepts; everything else
    // (epub/mobi/pdf/fb2/azw3) reads as a regular book.
    final isComic = state.format == BookFormat.cbz;
    return _SuccessLayout(
      title: isComic
          ? context.l10n.importComicAdded
          : context.l10n.importBookAdded,
      detail: state.filename,
      subtitle: state.estimate,
      onDone: () => Navigator.of(context).pop(ImportFlowResult.bookImported),
    );
  }
}

/// Success state after article import completes.
class _ArticleDoneView extends StatelessWidget {
  const _ArticleDoneView({required this.state});

  final ImportFlowArticleDone state;

  @override
  Widget build(BuildContext context) {
    return _SuccessLayout(
      title: context.l10n.importArticleSaved,
      detail: state.title,
      onDone: () => Navigator.of(context).pop(ImportFlowResult.articleImported),
    );
  }
}

/// Import failure with an explicit picker or URL-editing action.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.state});

  final ImportFlowFailure state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ImportFlowCubit>();

    return _StatusLayout(
      closable: true,
      content: _StatusContent(
        icon: _StatusIconSlot(
          child: _IconDisc(
            tint: cs.error,
            // Bare exclamation glyph keeps the disc as the only ring
            // around the mark, mirroring the success view's bare check.
            child: Text(
              '!',
              style: text.statusGlyph.copyWith(color: cs.error),
            ),
          ),
        ),
        title: _failureMessageFor(context, state),
        detail: state.filename,
        titleStyle: text.bodyMedium.copyWith(color: cs.onSurface),
        detailStyle: text.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      action: _FailureActions(
        primaryLabel: state.retryTarget == ImportFlowRetryTarget.article
            ? context.l10n.importEditLink
            : context.l10n.importChooseFile,
        onRetry: cubit.retryAfterFailure,
      ),
    );
  }
}

class _FailureActions extends StatelessWidget {
  const _FailureActions({required this.primaryLabel, required this.onRetry});

  final String primaryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppSheetActions(
    primaryLabel: primaryLabel,
    onPrimary: onRetry,
    secondaryLabel: context.l10n.commonCancel,
    onSecondary: () => Navigator.of(context).pop(),
  );
}

/// Spring-animated checkmark, title, detail line, optional subtitle,
/// full-width Done button — used for the book-done success state.
class _SuccessLayout extends StatelessWidget {
  const _SuccessLayout({
    required this.title,
    required this.detail,
    required this.onDone,
    this.subtitle,
  });

  final String title;
  final String detail;
  final String? subtitle;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurfaceVariant;

    return _StatusLayout(
      closable: true,
      content: _StatusContent(
        icon: _StatusIconSlot(
          child: _IconDisc(
            key: const ValueKey('importFlowStatusIcon'),
            child: Icon(
              AppIcons.check,
              color: context.actionForeground,
              size: AppIconSize.md,
            ),
          ),
        ),
        title: title,
        detail: detail,
        subtitle: subtitle,
        titleStyle: text.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        detailStyle: text.bodySmall.copyWith(color: muted),
      ),
      action: FilledButton(
        onPressed: onDone,
        child: AppButtonLabel(context.l10n.commonDone),
      ),
    );
  }
}

class _StatusIconSlot extends StatelessWidget {
  const _StatusIconSlot({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.stateIconFrame,
      height: AppSizes.stateIconFrame,
      child: Center(child: child),
    );
  }
}

/// Round 56×56 disc with a primary-tinted background. Used as a frame
/// for spinners, checkmarks and the error icon in the various
/// transient states.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.child, this.tint, super.key});

  final Widget child;

  /// Custom tint colour (defaults to primary). The error variant uses
  /// `cs.error` so the failure card reads differently from success.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final fill = (tint ?? cs.primary).withValues(alpha: 0.10);

    return Container(
      width: AppSizes.stateIconFrame,
      height: AppSizes.stateIconFrame,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}
