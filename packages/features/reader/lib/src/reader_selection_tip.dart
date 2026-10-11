import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'reader_bloc.dart';
import 'reader_search_cubit.dart';
import 'reader_selection_cubit.dart';
import 'reader_selection_tip_cubit.dart';
import 'reader_ui_cubit.dart';

/// Places the one-time selection tip at the bottom of the reader and feeds
/// [ReaderSelectionTipCubit] what the reader shows. A direct child of the
/// reader's content [Stack].
///
/// The tip is due on a page of selectable text ([readerSupportsSelectionTip])
/// once the WebView has painted it, with no controls, search navigation or
/// selection on screen.
class ReaderSelectionTipDriver extends StatelessWidget {
  const ReaderSelectionTipDriver({required this.webViewReady, super.key});

  /// Whether the WebView finished loading the current source.
  final bool webViewReady;

  @override
  Widget build(BuildContext context) {
    final supported = context.select<ReaderBloc, bool>((bloc) {
      final state = bloc.state;
      return state.status == ReaderStatus.ready &&
          state.document != null &&
          readerSupportsSelectionTip(
            sourceType: state.sourceType,
            format: state.document?.format,
            hasSearchableText: state.documentFeatures?.hasSearchableText,
          );
    });
    final contentOnly = context.select<ReaderUiCubit, bool>(
      (cubit) => cubit.state.contentOnlyVisible,
    );
    final navigating = context.select<ReaderSearchCubit, bool>(
      (cubit) => cubit.state.isNavigating,
    );
    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (cubit) => cubit.state.hasSelection,
    );
    final controlsVisible = !contentOnly || navigating;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ReaderSelectionTipScope(
        textPageVisible:
            supported && webViewReady && !controlsVisible && !hasSelection,
        controlsVisible: controlsVisible,
        hasSelection: hasSelection,
        child: const ReaderSelectionTipOverlay(),
      ),
    );
  }
}

/// Applies the reader's state to [ReaderSelectionTipCubit] when it changes,
/// outside of `build`: a selection ends the tip for good, controls hide it
/// for the session, a bare text page shows it when due.
class ReaderSelectionTipScope extends StatefulWidget {
  const ReaderSelectionTipScope({
    required this.textPageVisible,
    required this.controlsVisible,
    required this.hasSelection,
    required this.child,
    super.key,
  });

  final bool textPageVisible;
  final bool controlsVisible;
  final bool hasSelection;
  final Widget child;

  @override
  State<ReaderSelectionTipScope> createState() =>
      _ReaderSelectionTipScopeState();
}

class _ReaderSelectionTipScopeState extends State<ReaderSelectionTipScope> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(ReaderSelectionTipScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textPageVisible != oldWidget.textPageVisible ||
        widget.controlsVisible != oldWidget.controlsVisible ||
        widget.hasSelection != oldWidget.hasSelection) {
      _apply();
    }
  }

  void _apply() {
    final cubit = context.read<ReaderSelectionTipCubit>();
    if (widget.hasSelection) {
      cubit.dismissForever();
    } else if (widget.controlsVisible) {
      cubit.hideForSession();
    } else if (widget.textPageVisible) {
      cubit.showIfDue();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows [ReaderSelectionTipCard] while the tip is visible, inset from the
/// screen edges and safe area, and fades it in and out.
class ReaderSelectionTipOverlay extends StatelessWidget {
  const ReaderSelectionTipOverlay({super.key});

  /// A tablet keeps the tip at a readable width instead of spanning the page.
  static const maxWidth = 560.0;

  /// Share of the screen height the tip may take; at the largest text sizes
  /// its message scrolls instead of covering the page.
  static const maxHeightFraction = 0.6;

  @override
  Widget build(BuildContext context) {
    final visible = context.select<ReaderSelectionTipCubit, bool>(
      (cubit) => cubit.state == ReaderSelectionTipPhase.visible,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return AnimatedSwitcher(
      duration: context.motion(AppMotion.short),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: visible
          ? Padding(
              key: const ValueKey('readerSelectionTip'),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                bottomInset + AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  // Toasts float above the tip instead of covering it.
                  child: ToastAvoidArea(
                    child: ReaderSelectionTipCard(
                      onDismiss: context
                          .read<ReaderSelectionTipCubit>()
                          .dismissForever,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// The tip itself: a neutral inverse plate like the app's toasts, with the
/// Translate glyph, "Press and hold a word", the selection menu's commands by
/// their real labels, and "Got it".
///
/// "Got it" sits beside the text, or below it at large text sizes, where a
/// side button would squeeze the text into a tall sliver.
class ReaderSelectionTipCard extends StatelessWidget {
  const ReaderSelectionTipCard({required this.onDismiss, super.key});

  /// Alpha of the detail line on the plate; it keeps at least 4.5:1.
  static const detailAlpha = 0.8;

  /// Text scale from which "Got it" moves below the text.
  static const stackedTextScale = 1.3;

  static const _referenceFontSize = 14.0;

  final VoidCallback onDismiss;

  /// The action color on an inverse plate: the opposite theme's action
  /// color, as the plate is the opposite theme's surface.
  static Color actionColor(ColorScheme colors) =>
      colors.brightness == Brightness.dark
      ? colors.primary
      : colors.primaryFixedDim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = actionColor(colors);
    final radius = BorderRadius.circular(AppRadius.lg);
    // Measured on a body-size font: nonlinear scalers grow small and large
    // sizes differently.
    final stacked =
        MediaQuery.textScalerOf(context).scale(_referenceFontSize) >=
        _referenceFontSize * stackedTextScale;

    const glyphGap = SizedBox(width: AppSpacing.md);
    final glyph = Icon(AppIcons.translate, size: AppIconSize.md, color: accent);
    const message = Expanded(
      child: SingleChildScrollView(child: _ReaderSelectionTipMessage()),
    );
    final dismiss = TextButton(
      onPressed: onDismiss,
      style: TextButton.styleFrom(foregroundColor: accent),
      child: AppButtonLabel(context.l10n.readerSelectionTipDismiss),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.popover,
      ),
      child: Material(
        color: colors.inverseSurface,
        borderRadius: radius,
        child: stacked
            ? Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [glyph, glyphGap, message],
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: dismiss,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    glyph,
                    glyphGap,
                    message,
                    const SizedBox(width: AppSpacing.xs),
                    dismiss,
                  ],
                ),
              ),
      ),
    );
  }
}

/// The tip's title and detail, announced together when the tip appears,
/// without moving focus.
class _ReaderSelectionTipMessage extends StatelessWidget {
  const _ReaderSelectionTipMessage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final foreground = context.colors.onInverseSurface;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxs,
        children: [
          Text(
            l10n.readerSelectionTipTitle,
            style: text.titleSmall.copyWith(color: foreground),
          ),
          Text(
            l10n.readerSelectionTipBody(
              l10n.highlightAction,
              l10n.commonCopy,
              l10n.translationAction,
              l10n.dictionaryAction,
            ),
            style: text.bodySmall.copyWith(
              color: foreground.withValues(
                alpha: ReaderSelectionTipCard.detailAlpha,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
