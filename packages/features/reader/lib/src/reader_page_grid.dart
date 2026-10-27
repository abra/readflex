import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_page_thumbnail_cubit.dart';

/// Thumbnails of every page (comics, PDF) in reading order, with the
/// current page selected and scrolled into view.
///
/// Instantiated only while the Pages tab is visible; tiles request previews
/// as they are built and release them when scrolled away.
class ReaderPageGrid extends StatelessWidget {
  const ReaderPageGrid({
    required this.pageCount,
    required this.currentIndex,
    required this.loadThumbnail,
    required this.onSelected,
    this.pageProgressionRtl = false,
    super.key,
  });

  final int pageCount;

  /// Zero-based index of the page on screen.
  final int currentIndex;
  final PageThumbnailLoader loadThumbnail;

  /// Receives the zero-based index of the tapped page.
  final ValueChanged<int> onSelected;
  final bool pageProgressionRtl;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ReaderPageThumbnailCubit(loadThumbnail),
    child: _PageGridView(
      pageCount: pageCount,
      currentIndex: currentIndex,
      onSelected: onSelected,
      pageProgressionRtl: pageProgressionRtl,
    ),
  );
}

class _PageGridView extends StatefulWidget {
  const _PageGridView({
    required this.pageCount,
    required this.currentIndex,
    required this.onSelected,
    required this.pageProgressionRtl,
  });
  final int pageCount;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool pageProgressionRtl;

  @override
  State<_PageGridView> createState() => _PageGridViewState();
}

class _PageGridViewState extends State<_PageGridView> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Page lists arrive asynchronously. Do not fix the initial offset to
      // zero before the pages and the restored location are available.
      if (widget.pageCount <= 0) return const SizedBox.shrink();
      final scale = MediaQuery.textScalerOf(context);
      final columns = (constraints.maxWidth / math.max(150, scale.scale(120)))
          .floor()
          .clamp(1, 4);
      // 16dp drawer gutter around the grid, 12dp between tiles.
      final width =
          (constraints.maxWidth -
              AppSpacing.lg * 2 -
              AppSpacing.md * (columns - 1)) /
          columns;
      final extent = width * 1.5 + scale.scale(24) + AppSpacing.md;
      final maxOffset = math.max(
        0.0,
        (widget.pageCount / columns).ceil() * (extent + AppSpacing.md) -
            constraints.maxHeight,
      );
      _scroll ??= ScrollController(
        initialScrollOffset: math.min(
          maxOffset,
          widget.currentIndex < columns
              ? 0
              : AppSpacing.lg +
                    (widget.currentIndex ~/ columns) * (extent + AppSpacing.md),
        ),
      );
      final labelDirection = Directionality.of(context);
      return ScrollEdgeFadeStack(
        child: Directionality(
          textDirection: widget.pageProgressionRtl
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: GridView.builder(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: extent,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
            ),
            itemCount: widget.pageCount,
            itemBuilder: (context, index) => Directionality(
              key: ValueKey(index),
              textDirection: labelDirection,
              child: _PageGridTile(
                index: index,
                selected: index == widget.currentIndex,
                onTap: () => widget.onSelected(index),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PageGridTile extends StatefulWidget {
  const _PageGridTile({
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PageGridTile> createState() => _PageGridTileState();
}

class _PageGridTileState extends State<_PageGridTile> {
  late final _thumbnails = context.read<ReaderPageThumbnailCubit>();

  @override
  void initState() {
    super.initState();
    _thumbnails.request(widget.index);
  }

  @override
  void dispose() {
    _thumbnails.release(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<
        ReaderPageThumbnailCubit,
        Map<int, ImageProvider?>,
        ({bool loaded, ImageProvider? image})
      >(
        selector: (state) => (
          loaded: state.containsKey(widget.index),
          image: state[widget.index],
        ),
        builder: (context, preview) {
          final colors = context.colors;
          final label = context.l10n.readerPageNumber(widget.index + 1);
          final foreground = widget.selected
              ? colors.selectedControlForeground
              : colors.onSurfaceVariant;
          return Semantics(
            selected: widget.selected,
            button: true,
            label: label,
            child: Material(
              color: widget.selected
                  ? colors.selectedControlBackground
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox.expand(
                        child: preview.image != null
                            ? Image(
                                image: preview.image!,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => Icon(
                                  AppIcons.book,
                                  color: foreground,
                                ),
                              )
                            : Center(
                                child: preview.loaded
                                    ? Semantics(
                                        label: context
                                            .l10n
                                            .readerThumbnailUnavailable,
                                        child: AppPlainIconButton(
                                          icon: AppIcons.refresh,
                                          tooltip: context.l10n.commonRetry,
                                          onPressed: () =>
                                              _thumbnails.retry(widget.index),
                                        ),
                                      )
                                    : Icon(
                                        AppIcons.book,
                                        color: foreground,
                                      ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.selected) ...[
                            Icon(
                              AppIcons.check,
                              size: AppIconSize.sm,
                              color: colors.selectedControlForeground,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall.copyWith(
                                color: widget.selected
                                    ? colors.selectedControlForeground
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
