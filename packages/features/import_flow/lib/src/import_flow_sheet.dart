import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
///
/// Returns [ImportFlowResult.bookImported] when the user finished an
/// import, or `null` if they dismissed without finishing.
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required PickBookFile onPickBookFile,
  required ImportBookFile onImportBook,
}) {
  return showAppBottomSheet<ImportFlowResult>(
    context,
    builder: (_) => BlocProvider(
      create: (_) => ImportFlowCubit(
        onPickBookFile: onPickBookFile,
        onImportBook: onImportBook,
      ),
      child: const _ImportFlowSheet(),
    ),
  );
}

class _ImportFlowSheet extends StatelessWidget {
  const _ImportFlowSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImportFlowCubit, ImportFlowState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(state.runtimeType),
            child: switch (state) {
              ImportFlowMenu() => const _MenuView(),
              ImportFlowBookUploading() => _BookUploadingView(state: state),
              ImportFlowBookDone() => _BookDoneView(state: state),
              ImportFlowFailure() => _FailureView(state: state),
            },
          ),
        );
      },
    );
  }
}

/// Initial picker — single Upload Book tile + Cancel.
class _MenuView extends StatelessWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportFlowCubit>();

    return ActionBottomSheetLayout(
      title: 'Add to Library',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuOption(
            icon: AppIcons.uploadFile,
            title: 'Upload Book',
            subtitle: 'EPUB, PDF, MOBI, CBZ, …',
            onTap: cubit.pickAndImportBook,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PlainTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Card-style menu button: rounded `surfaceContainerHighest @ 0.6`
/// background, 40×40 primary-tinted icon disc on the left, two-line
/// label on the right.
class _MenuOption extends StatelessWidget {
  const _MenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: cs.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.labelSmall.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(child: _IconDisc(child: _Spinner())),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Uploading book...',
            textAlign: TextAlign.center,
            style: text.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            state.filename,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${(progress * 100).clamp(0, 100).toInt()}%',
              textAlign: TextAlign.center,
              style: text.labelSmall.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: muted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

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
    return _SuccessLayout(
      title: 'Book added!',
      detail: state.filename,
      subtitle: state.estimate,
      onDone: () => Navigator.of(context).pop(ImportFlowResult.bookImported),
    );
  }
}

/// Terminal failure screen for the book path. "Try again" goes back to
/// the menu; the user can also dismiss the sheet to exit entirely.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.state});

  final ImportFlowFailure state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final cubit = context.read<ImportFlowCubit>();

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: _IconDisc(
              tint: cs.error,
              child: Icon(AppIcons.error, color: cs.error, size: 22),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: text.bodyMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: cubit.backToMenu,
            child: const Text('Try again'),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PlainTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
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

    return Padding(
      padding: _kStatusViewPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: _IconDisc(
              child: Icon(AppIcons.check, color: cs.primary, size: 24),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall.copyWith(color: muted),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: text.labelSmall.copyWith(color: muted),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
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

/// Inline spinner sized to fit inside [_IconDisc].
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
    );
  }
}
