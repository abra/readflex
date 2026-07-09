import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'article_url_utils.dart';
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
class _ImportFlowSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: isOfflineStream,
      initialData: isOffline,
      builder: (context, snapshot) {
        final isOffline = snapshot.data ?? this.isOffline;
        return BlocBuilder<ImportFlowCubit, ImportFlowState>(
          builder: (context, state) {
            // Hard-pin all states to the same body height so the
            // sheet never resizes between menu / uploading / done /
            // failure. Action-heavy states control their own spacing so
            // controls stay visually close to their related content.
            return SizedBox(
              height: 280,
              child: _ImportFlowStepSwitcher(
                state: state,
                child: KeyedSubtree(
                  key: ValueKey(state.runtimeType),
                  child: switch (state) {
                    ImportFlowMenu() => _MenuView(isOffline: isOffline),
                    ImportFlowBookTermsRequired() => _BookTermsView(
                      onOpenTerms: onOpenTerms,
                      onOpenPrivacy: onOpenPrivacy,
                    ),
                    ImportFlowArticleUrlEntry() => _ArticleUrlEntryView(
                      state: state,
                      isOffline: isOffline,
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
    required this.child,
  });

  final ImportFlowState state;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) => ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
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
          translation: Offset(sign * (1 - value), 0),
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

/// Initial picker — title + Upload Book tile at the top, Cancel
/// anchored to the bottom of the fixed sheet body.
class _MenuView extends StatelessWidget {
  const _MenuView({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();
    final warning = context.appColors.warning;
    final l10n = context.l10n;

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(title: l10n.importAddToLibraryTitle),
          const SizedBox(height: AppSpacing.lg),
          AppActionCard(
            icon: AppIcons.uploadFile,
            title: l10n.importUploadBook,
            subtitle: l10n.importUploadBookFormats,
            onTap: cubit.requestBookImport,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppActionCard(
            icon: isOffline ? AppIcons.offline : AppIcons.global,
            title: l10n.importSaveArticle,
            subtitle: l10n.importSaveArticleDescription,
            iconColor: isOffline ? warning : null,
            onTap: isOffline ? null : cubit.showArticleUrlEntry,
          ),
          const Spacer(),
          _PlainTextButton(
            label: l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

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

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(title: l10n.importBeforeUploadingTitle),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.importBookTermsBody,
                    style: text.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
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
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _PlainTextButton(
                  label: l10n.commonCancel,
                  onPressed: cubit.cancelBookImportTerms,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _accepted ? cubit.acceptTermsAndPickBook : null,
                  child: Text(l10n.commonContinue),
                ),
              ),
            ],
          ),
        ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!accepted),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: accepted,
              onChanged: (value) => onChanged(value ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.importBookTermsConfirm,
                  style: context.text.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTermsLinks extends StatelessWidget {
  const _BookTermsLinks({
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final Future<void> Function() onOpenTerms;
  final Future<void> Function() onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.text.bodySmall.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(context.l10n.importLegalPrefix, style: textStyle),
        _InlineLinkButton(
          label: context.l10n.importTerms,
          onPressed: onOpenTerms,
        ),
        Text(context.l10n.importLegalAnd, style: textStyle),
        _InlineLinkButton(
          label: context.l10n.importPrivacyPolicy,
          onPressed: onOpenPrivacy,
        ),
        Text(context.l10n.importLegalSuffix, style: textStyle),
      ],
    );
  }
}

class _InlineLinkButton extends StatelessWidget {
  const _InlineLinkButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 24),
      child: InkWell(
        key: ValueKey('importFlowLegalLink-$label'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: context.text.bodySmall.copyWith(
                color: context.colors.primary,
                decoration: TextDecoration.underline,
                decorationColor: context.colors.primary,
              ),
            ),
          ),
        ),
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
    ImportFlowErrorCode.bookImportFailed => l10n.importBookImportFailed,
    ImportFlowErrorCode.articleSaveFailed => l10n.importArticleSaveFailed,
  };
}

/// Full-width outlined button for Cancel and other secondary actions
/// inside the sheet. Matches the Cancel in the delete-confirmation
/// sheet so the two destructive entry points feel like one app.
class _PlainTextButton extends StatelessWidget {
  const _PlainTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

/// URL entry step for article import.
class _ArticleUrlEntryView extends StatefulWidget {
  const _ArticleUrlEntryView({
    required this.state,
    required this.isOffline,
  });

  final ImportFlowArticleUrlEntry state;
  final bool isOffline;

  @override
  State<_ArticleUrlEntryView> createState() => _ArticleUrlEntryViewState();
}

class _ArticleUrlEntryViewState extends State<_ArticleUrlEntryView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _readClipboardArticleUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return normalizeArticleUrl(data?.text ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _pasteClipboardArticleUrl() async {
    final url = await _readClipboardArticleUrl();
    if (!mounted) return;
    if (url == null) return;
    _controller.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
    context.read<ImportFlowCubit>().articleUrlChanged(url);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();
    final colors = context.colors;
    final muted = colors.onSurface.withValues(alpha: 0.55);
    final l10n = context.l10n;

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(title: l10n.importSaveArticle),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: l10n.importArticleUrlHint,
              errorText: _errorMessageFor(context, widget.state.errorCode),
              suffixIcon: _PasteUrlButton(
                onPressed: _pasteClipboardArticleUrl,
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 52,
                height: 48,
              ),
            ),
            onSubmitted: widget.isOffline
                ? null
                : (_) => cubit.submitArticleUrl(),
            onChanged: cubit.articleUrlChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          _ArticleUrlHints(color: muted),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _PlainTextButton(
                  label: l10n.commonBack,
                  onPressed: cubit.backToMenu,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: widget.isOffline || !widget.state.canSubmit
                      ? null
                      : cubit.submitArticleUrl,
                  child: Text(l10n.commonSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasteUrlButton extends StatelessWidget {
  const _PasteUrlButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 52,
      height: 48,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Semantics(
            label: context.l10n.importPasteUrl,
            button: true,
            child: GestureDetector(
              key: const ValueKey('articleUrlPasteButton'),
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 40,
                child: Center(
                  child: Icon(
                    AppIcons.paste,
                    size: AppIconSize.sm,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
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

/// Book is uploading. Shows either an indeterminate spinner (while
/// metadata is being parsed) or a progress bar with percentage (during
/// the byte-copy phase).
class _BookUploadingView extends StatelessWidget {
  const _BookUploadingView({required this.state});

  final ImportFlowBookUploading state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final progress = state.progress;

    return _StatusLayout(
      reserveActionSpace: true,
      content: _BookUploadStatusContent(
        filename: state.filename,
        progress: progress,
        titleStyle: text.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        detailStyle: text.labelSmall.copyWith(color: muted),
        progressBackgroundColor: cs.surfaceContainerHighest,
        progressColor: cs.primary,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _kBookUploadProgressReserveHeight),
        const Center(
          child: _StatusIconSlot(
            key: ValueKey('importFlowStatusIcon'),
            child: CenteredCircularProgressIndicator(),
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
            value: progress,
            minHeight: 6,
            backgroundColor: progressBackgroundColor,
            color: progressColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: _kBookUploadProgressLabelHeight,
          child: progress == null
              ? null
              : Text(
                  '${(progress! * 100).clamp(0, 100).toInt()}%',
                  textAlign: TextAlign.center,
                  style: detailStyle.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ],
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
        detailStyle: text.labelSmall.copyWith(
          color: colors.onSurface.withValues(alpha: 0.55),
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

/// Shared vertical layout for upload/progress states.
///
/// [reserveActionSpace] keeps the sheet height stable before a retry/done action
/// appears.
class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    required this.content,
    this.action,
    this.reserveActionSpace = false,
  });

  final Widget content;
  final Widget? action;
  final bool reserveActionSpace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Center(child: content)),
          const SizedBox(height: AppSpacing.md),
          if (action case final action?)
            action
          else if (reserveActionSpace)
            const SizedBox(height: _kStatusActionHeight),
        ],
      ),
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

const _kStatusActionHeight = 48.0;
const _kBookUploadProgressLabelHeight = 16.0;
const _kBookUploadProgressReserveHeight =
    AppSpacing.md + 6 + AppSpacing.xs + _kBookUploadProgressLabelHeight;

/// Insets used by the title-less status views (uploading, done,
/// failure) so they line up with the [_MenuView]'s ActionBottomSheet
/// gutter.
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

/// Terminal failure screen. "Try again" returns to the right failed flow.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.state});

  final ImportFlowFailure state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ImportFlowCubit>();

    return _StatusLayout(
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
        detailStyle: text.labelSmall.copyWith(
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      ),
      // Side-by-side buttons keep the failure state close to the menu height.
      action: Row(
        children: [
          Expanded(
            child: _PlainTextButton(
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: cubit.retryAfterFailure,
              child: Text(context.l10n.importTryAgain),
            ),
          ),
        ],
      ),
    );
  }
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
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return _StatusLayout(
      content: _StatusContent(
        icon: _StatusIconSlot(
          child: _IconDisc(
            key: const ValueKey('importFlowStatusIcon'),
            child: Icon(AppIcons.check, color: cs.primary, size: 24),
          ),
        ),
        title: title,
        detail: detail,
        subtitle: subtitle,
        titleStyle: text.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        detailStyle: text.labelSmall.copyWith(color: muted),
      ),
      action: FilledButton(
        onPressed: onDone,
        child: Text(context.l10n.commonDone),
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
      width: 56,
      height: 56,
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}
