import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'reader_progress_label.dart';

const _kOverlayVisibleDuration = Duration(seconds: 3);
const _kOverlayAnimDuration = Duration(milliseconds: 200);
const _kOverlayShowCurve = Curves.easeOutCubic;
const _kOverlayHideCurve = Curves.easeInCubic;

/// Transient "page X / Y" indicator for image-page books.
///
/// CBZ still needs quick page feedback, but a permanent badge sits on top of
/// artwork. Show it when metrics arrive and after page changes, then fade it
/// away.
class ReaderImagePageProgressOverlay extends StatefulWidget {
  const ReaderImagePageProgressOverlay({
    required this.format,
    required this.chromeVisible,
    required this.selectionActionsVisible,
    required this.currentPage,
    required this.totalPages,
    super.key,
  });

  final BookFormat? format;
  final bool chromeVisible;
  final bool selectionActionsVisible;
  final int? currentPage;
  final int? totalPages;

  @override
  State<ReaderImagePageProgressOverlay> createState() =>
      _ReaderImagePageProgressOverlayState();
}

typedef _ImagePageProgressMetric = ({
  BookFormat format,
  int currentPage,
  int totalPages,
});

class _ReaderImagePageProgressOverlayState
    extends State<ReaderImagePageProgressOverlay> {
  Timer? _hideTimer;
  _ImagePageProgressMetric? _metric;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(ReaderImagePageProgressOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility();
  }

  void _syncVisibility() {
    final nextMetric = _metricFor(widget);
    if (nextMetric == null || widget.chromeVisible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _visible = false;
      if (nextMetric == null) _metric = null;
      return;
    }

    if (nextMetric == _metric) return;
    _metric = nextMetric;
    _visible = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(_kOverlayVisibleDuration, () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  _ImagePageProgressMetric? _metricFor(ReaderImagePageProgressOverlay widget) {
    final format = widget.format;
    final currentPage = widget.currentPage;
    final totalPages = widget.totalPages;
    if (!isImagePageFormat(format) ||
        currentPage == null ||
        totalPages == null ||
        totalPages <= 0) {
      return null;
    }
    return (
      format: format!,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metric = _metricFor(widget);
    if (metric == null) return const SizedBox.shrink();

    final displayed = displayZeroIndexedPage(
      metric.currentPage,
      metric.totalPages,
    );
    final colors = context.colors;
    final visible =
        _visible && !widget.chromeVisible && !widget.selectionActionsVisible;
    return Positioned(
      left: 0,
      right: 0,
      bottom: _appBottomSafeInset(context) + AppSpacing.md,
      child: IgnorePointer(
        key: const ValueKey('readerImagePageProgressOverlayIgnorePointer'),
        child: AnimatedOpacity(
          key: const ValueKey('readerImagePageProgressOverlayOpacity'),
          opacity: visible ? 1 : 0,
          duration: _kOverlayAnimDuration,
          curve: visible ? _kOverlayShowCurve : _kOverlayHideCurve,
          child: Center(
            child: _ImagePageProgressOverlayPill(
              text: '$displayed / ${metric.totalPages}',
              maxText: '${metric.totalPages} / ${metric.totalPages}',
              panelColor: colors.surface,
              textColor: colors.onSurfaceVariant,
              dividerColor: colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePageProgressOverlayPill extends StatelessWidget {
  const _ImagePageProgressOverlayPill({
    required this.text,
    required this.maxText,
    required this.panelColor,
    required this.textColor,
    required this.dividerColor,
  });

  final String text;
  final String maxText;
  final Color panelColor;
  final Color textColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final style = context.text.readerChromeNumber.copyWith(color: textColor);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: panelColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0,
                child: ExcludeSemantics(child: Text(maxText, style: style)),
              ),
              Text(text, style: style),
            ],
          ),
        ],
      ),
    );
  }
}

double _appBottomSafeInset(BuildContext context) {
  return MediaQuery.viewInsetsOf(context).bottom +
      MediaQuery.paddingOf(context).bottom;
}
