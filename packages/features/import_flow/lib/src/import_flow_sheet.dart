import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
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
        // Hard-pin all four states to the same body height so the
        // sheet never resizes between menu / uploading / done /
        // failure. Content sits at the top of this box; any unused
        // space appears as natural padding at the bottom — none of
        // the inner Columns use Spacer, so buttons stay where they
        // belong relative to their own content.
        return SizedBox(
          height: 200,
          child: AnimatedSwitcher(
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
          ),
        );
      },
    );
  }
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
          _MenuOption(
            icon: AppIcons.uploadFile,
            title: 'Upload Book',
            subtitle: 'EPUB, FB2, MOBI, PDF, AZW3, CBZ',
            onTap: cubit.pickAndImportBook,
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
          // Heavier vertical padding makes the menu state's Upload
          // Book card tall enough that the Cancel button below it
          // sits at the same y-position as the Done button in the
          // book-imported state. Without this, the action button
          // visibly shifts when the sheet transitions states.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
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
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

/// Terminal failure screen for the book path. "Try again" re-opens the
/// file picker; the user can also dismiss the sheet to exit entirely.
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
        mainAxisSize: MainAxisSize.max,
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
          const Spacer(),
          // Side-by-side buttons (instead of stacked) so failure
          // collapses to roughly the menu state's height.
          Row(
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
                  // Re-open the file picker directly. Going back to the
                  // menu would force the user to tap "Upload Book"
                  // again — the failure context already implies that's
                  // what they want to retry.
                  onPressed: cubit.pickAndImportBook,
                  child: const Text('Try again'),
                ),
              ),
            ],
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
        mainAxisSize: MainAxisSize.max,
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
            maxLines: 1,
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
          const Spacer(),
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
