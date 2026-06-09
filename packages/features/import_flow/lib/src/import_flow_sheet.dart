import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

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
        onOpenTerms: onOpenTerms ?? _noopFuture,
        onOpenPrivacy: onOpenPrivacy ?? _noopFuture,
      ),
    ),
  );
}

class _ImportFlowSheet extends StatelessWidget {
  const _ImportFlowSheet({
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final Future<void> Function() onOpenTerms;
  final Future<void> Function() onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
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
                ImportFlowMenu() => const _MenuView(),
                ImportFlowBookTermsRequired() => _BookTermsView(
                  onOpenTerms: onOpenTerms,
                  onOpenPrivacy: onOpenPrivacy,
                ),
                ImportFlowArticleUrlEntry() => const _ArticleUrlEntryView(),
                ImportFlowBookUploading() => _BookUploadingView(state: state),
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
  }
}

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
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHeader(title: 'Add to Library'),
          const SizedBox(height: AppSpacing.lg),
          AppActionCard(
            icon: AppIcons.uploadFile,
            title: 'Upload Book',
            subtitle: 'EPUB, FB2, MOBI, PDF, AZW3, CBZ',
            onTap: cubit.requestBookImport,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppActionCard(
            icon: AppIcons.global,
            title: 'Save Article',
            subtitle: 'Paste a web URL for offline reading',
            onTap: cubit.showArticleUrlEntry,
          ),
          const Spacer(),
          _PlainTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

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

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHeader(title: 'Before uploading'),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Only upload books, comics, and documents you have the right to use in ReadFlex.',
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
                  label: 'Cancel',
                  onPressed: cubit.cancelBookImportTerms,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _accepted ? cubit.acceptTermsAndPickBook : null,
                  child: const Text('Continue'),
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
                  'I confirm I have the right to upload this file.',
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
        Text('By continuing, you accept the ', style: textStyle),
        _InlineLinkButton(label: 'Terms', onPressed: onOpenTerms),
        Text(' and ', style: textStyle),
        _InlineLinkButton(label: 'Privacy Policy', onPressed: onOpenPrivacy),
        Text('.', style: textStyle),
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

class _ArticleUrlEntryView extends StatefulWidget {
  const _ArticleUrlEntryView();

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
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();
    final colors = context.colors;
    final muted = colors.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHeader(title: 'Save Article'),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://example.com/article',
              suffixIcon: _PasteUrlButton(
                onPressed: _pasteClipboardArticleUrl,
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 52,
                height: 48,
              ),
            ),
            onSubmitted: cubit.importArticle,
          ),
          const SizedBox(height: AppSpacing.md),
          _ArticleUrlHints(color: muted),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _PlainTextButton(
                  label: 'Back',
                  onPressed: cubit.backToMenu,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => cubit.importArticle(_controller.text),
                  child: const Text('Save'),
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
            label: 'Paste URL',
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
          text: 'Creates a clean article for offline reading.',
          color: color,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ArticleUrlHint(
          text: 'Keeps the original source link.',
          color: color,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ArticleUrlHint(
          text: 'Adds it to your Library.',
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
        const Center(child: CenteredCircularProgressIndicator()),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Uploading book...',
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
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(progress! * 100).clamp(0, 100).toInt()}%',
            textAlign: TextAlign.center,
            style: detailStyle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

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
        icon: const CenteredCircularProgressIndicator(),
        title: 'Saving article...',
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

const _kStatusActionHeight = 40.0;

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
      title: isComic ? 'Comic added!' : 'Book added!',
      detail: state.filename,
      subtitle: state.estimate,
      onDone: () => Navigator.of(context).pop(ImportFlowResult.bookImported),
    );
  }
}

class _ArticleDoneView extends StatelessWidget {
  const _ArticleDoneView({required this.state});

  final ImportFlowArticleDone state;

  @override
  Widget build(BuildContext context) {
    return _SuccessLayout(
      title: 'Article saved!',
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
        icon: _IconDisc(
          tint: cs.error,
          // Bare exclamation glyph keeps the disc as the only ring
          // around the mark, mirroring the success view's bare check.
          child: Text(
            '!',
            style: text.statusGlyph.copyWith(color: cs.error),
          ),
        ),
        title: state.message,
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
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: cubit.retryAfterFailure,
              child: const Text('Try again'),
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
        icon: _IconDisc(
          child: Icon(AppIcons.check, color: cs.primary, size: 24),
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
      action: FilledButton(onPressed: onDone, child: const Text('Done')),
    );
  }
}

/// Round 56×56 disc with a primary-tinted background. Used as a frame
/// for spinners, checkmarks and the error icon in the various
/// transient states.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.child, this.tint});

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
