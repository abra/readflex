import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'highlight_color_resolver.dart';
import 'highlight_cubit.dart';

/// Opens the standalone [HighlightSheet] as a modal bottom sheet.
Future<void> showHighlightSheet(
  BuildContext context, {
  required HighlightRepository highlightRepository,
  required TextSelectionContext selection,
  HighlightColorResolver? resolveColor,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => HighlightSheet(
      highlightRepository: highlightRepository,
      selection: selection,
      resolveColor: resolveColor,
    ),
  );
}

/// Bottom sheet for creating a new highlight from selected reader text.
///
/// Shows the selected passage, a color picker, and an optional note field.
/// Provides its own [HighlightCubit]; closes itself on successful save.
/// Usually launched via [showHighlightSheet], not constructed directly.
/// [resolveColor] overrides the app palette so swatches and the preview tint
/// can follow a reader theme.
class HighlightSheet extends StatelessWidget {
  const HighlightSheet({
    required this.highlightRepository,
    required this.selection,
    this.resolveColor,
    super.key,
  });

  final HighlightRepository highlightRepository;
  final TextSelectionContext selection;
  final HighlightColorResolver? resolveColor;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HighlightCubit(
        highlightRepository: highlightRepository,
      ),
      child: _HighlightSheetView(
        selection: selection,
        resolveColor: resolveColor,
      ),
    );
  }
}

/// Highlight form bound to [HighlightCubit], with a discard step that
/// protects a typed note from scrim, drag, Close and system Back.
class _HighlightSheetView extends StatefulWidget {
  const _HighlightSheetView({
    required this.selection,
    required this.resolveColor,
  });

  final TextSelectionContext selection;
  final HighlightColorResolver? resolveColor;

  @override
  State<_HighlightSheetView> createState() => _HighlightSheetViewState();
}

class _HighlightSheetViewState extends State<_HighlightSheetView> {
  // Owned here so the typed note survives the switch to the discard step.
  late final TextEditingController _noteController = TextEditingController(
    text: context.read<HighlightCubit>().state.note,
  );
  bool _confirmingDiscard = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool _hasDraft(HighlightSheetState state) => state.note.trim().isNotEmpty;

  void _requestClose() {
    final state = context.read<HighlightCubit>().state;
    if (state.status == HighlightSheetStatus.saving) return;
    if (!_hasDraft(state)) {
      Navigator.of(context).pop();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _confirmingDiscard = true);
  }

  void _keepEditing() => setState(() => _confirmingDiscard = false);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HighlightCubit, HighlightSheetState>(
      listener: (context, state) {
        if (state.status == HighlightSheetStatus.success) {
          Navigator.of(context).pop();
        }
      },
      // Rebuild on the draft becoming empty/non-empty, not on every keystroke.
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.selectedColor != curr.selectedColor ||
          _hasDraft(prev) != _hasDraft(curr),
      builder: (context, state) {
        final isSaving = state.status == HighlightSheetStatus.saving;
        final guarded = isSaving || _hasDraft(state) || _confirmingDiscard;
        return PopScope(
          canPop: !guarded,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _confirmingDiscard ? _keepEditing() : _requestClose();
          },
          child: AppSheetDismissGuard(
            enabled: guarded,
            onDismissAttempt: _requestClose,
            child: _confirmingDiscard
                ? _HighlightDiscardStep(
                    onKeepEditing: _keepEditing,
                    onDiscard: () => Navigator.of(context).pop(),
                  )
                : _HighlightFormStep(
                    selection: widget.selection,
                    resolveColor: widget.resolveColor,
                    noteController: _noteController,
                    state: state,
                    onClose: _requestClose,
                  ),
          ),
        );
      },
    );
  }
}

class _HighlightDiscardStep extends StatelessWidget {
  const _HighlightDiscardStep({
    required this.onKeepEditing,
    required this.onDiscard,
  });

  final VoidCallback onKeepEditing;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionBottomSheetLayout(
      title: l10n.commonDiscardChangesTitle,
      onBack: onKeepEditing,
      backLabel: l10n.commonBack,
      child: AppSheetActions(
        primaryLabel: l10n.commonKeepEditing,
        onPrimary: onKeepEditing,
        secondaryLabel: l10n.commonDiscardChanges,
        onSecondary: onDiscard,
        destructiveSecondary: true,
      ),
    );
  }
}

class _HighlightFormStep extends StatelessWidget {
  const _HighlightFormStep({
    required this.selection,
    required this.resolveColor,
    required this.noteController,
    required this.state,
    required this.onClose,
  });

  final TextSelectionContext selection;
  final HighlightColorResolver? resolveColor;
  final TextEditingController noteController;
  final HighlightSheetState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HighlightCubit>();
    final isSaving = state.status == HighlightSheetStatus.saving;
    final l10n = context.l10n;
    final swatchFor = resolveColor ?? _appPaletteResolver(context);
    final text = selection.selectedText;

    // Body scrolls and Save stays pinned, so 2x text with the keyboard up
    // never clips the command.
    return ActionBottomSheetLayout(
      title: l10n.highlightTitle,
      closeLabel: l10n.commonClose,
      onClose: isSaving ? null : onClose,
      constrainBody: true,
      bodyPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == HighlightSheetStatus.failure)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              // No localized retry hint exists yet; Save is the retry.
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.highlightFailedToSave,
                  style: context.text.bodyMedium.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
            ),
          FilledButton(
            onPressed: isSaving
                ? null
                : () => cubit.save(
                    text: text,
                    sourceId: selection.sourceId,
                    sourceType: selection.sourceType,
                    cfiRange: selection.cfiRange,
                    pageNumber: selection.pageNumber,
                    scrollOffset: selection.scrollOffset,
                    progress: selection.progress,
                    chapterTitle: selection.chapterTitle,
                  ),
            child: isSaving
                ? const ButtonLoadingIndicator()
                : AppButtonLabel(l10n.commonSave),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectionPreviewCard(
              text: text,
              textDirection: Bidi.detectRtlDirectionality(text)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              backgroundColor: swatchFor(
                state.selectedColor,
              ).withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final color in HighlightColor.values)
                  AppColorSwatchButton(
                    key: ValueKey('highlightColorSemantics-${color.name}'),
                    color: swatchFor(color),
                    selected: state.selectedColor == color,
                    tooltip: _labelForHighlightColor(l10n, color),
                    semanticsLabel: l10n.highlightColorSemantics(
                      _labelForHighlightColor(l10n, color),
                    ),
                    onTapHint: l10n.highlightSelectColor,
                    onPressed: isSaving ? null : () => cubit.setColor(color),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: l10n.highlightNoteHint,
                isDense: true,
              ),
              maxLines: 2,
              enabled: !isSaving,
              onChanged: cubit.setNote,
            ),
          ],
        ),
      ),
    );
  }
}

HighlightColorResolver _appPaletteResolver(BuildContext context) {
  final ext = context.appColors;
  return (color) => switch (color) {
    HighlightColor.yellow => ext.highlightYellow,
    HighlightColor.green => ext.highlightGreen,
    HighlightColor.blue => ext.highlightBlue,
    HighlightColor.pink => ext.highlightPink,
    HighlightColor.purple => ext.highlightPurple,
  };
}

String _labelForHighlightColor(
  ReadflexLocalizations l10n,
  HighlightColor color,
) {
  return switch (color) {
    HighlightColor.yellow => l10n.highlightColorYellow,
    HighlightColor.green => l10n.highlightColorGreen,
    HighlightColor.blue => l10n.highlightColorBlue,
    HighlightColor.pink => l10n.highlightColorPink,
    HighlightColor.purple => l10n.highlightColorPurple,
  };
}
