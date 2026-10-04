import 'dart:math' as math;
import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader_webview/reader_webview.dart';

import 'reader_comic_thumbnail_cubit.dart';

/// Instantiated only while the comic Pages tab is visible.
class ReaderComicPages extends StatelessWidget {
  const ReaderComicPages({
    required this.items,
    required this.currentIndex,
    required this.loadThumbnail,
    required this.onSelected,
    this.pageProgressionRtl = false,
    super.key,
  });

  final List<ReaderTocItem> items;
  final int currentIndex;
  final ComicThumbnailLoader loadThumbnail;
  final ValueChanged<ReaderTocItem> onSelected;
  final bool pageProgressionRtl;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ReaderComicThumbnailCubit(loadThumbnail),
    child: _ComicPagesView(
      items: items,
      currentIndex: currentIndex,
      onSelected: onSelected,
      pageProgressionRtl: pageProgressionRtl,
    ),
  );
}

class _ComicPagesView extends StatefulWidget {
  const _ComicPagesView({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.pageProgressionRtl,
  });
  final List<ReaderTocItem> items;
  final int currentIndex;
  final ValueChanged<ReaderTocItem> onSelected;
  final bool pageProgressionRtl;

  @override
  State<_ComicPagesView> createState() => _ComicPagesViewState();
}

class _ComicPagesViewState extends State<_ComicPagesView> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // TOC arrives asynchronously. Do not fix the initial offset to zero before
      // its pages and the restored location are available.
      if (widget.items.isEmpty) return const SizedBox.shrink();
      final scale = MediaQuery.textScalerOf(context);
      final columns = (constraints.maxWidth / math.max(150, scale.scale(120)))
          .floor()
          .clamp(1, 4);
      final width =
          (constraints.maxWidth - AppSpacing.md * (columns + 1)) / columns;
      final extent = width * 1.5 + scale.scale(24) + AppSpacing.md;
      final maxOffset = math.max(
        0.0,
        (widget.items.length / columns).ceil() * (extent + AppSpacing.md) -
            constraints.maxHeight,
      );
      _scroll ??= ScrollController(
        initialScrollOffset: math.min(
          maxOffset,
          widget.currentIndex < columns
              ? 0
              : AppSpacing.md +
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
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: extent,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
            ),
            itemCount: widget.items.length,
            itemBuilder: (context, index) => Directionality(
              key: ValueKey(index),
              textDirection: labelDirection,
              child: _ComicPageTile(
                index: index,
                selected: index == widget.currentIndex,
                onTap: () => widget.onSelected(widget.items[index]),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ComicPageTile extends StatefulWidget {
  const _ComicPageTile({
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ComicPageTile> createState() => _ComicPageTileState();
}

class _ComicPageTileState extends State<_ComicPageTile> {
  late final _thumbnails = context.read<ReaderComicThumbnailCubit>();

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
        ReaderComicThumbnailCubit,
        Map<int, Uint8List?>,
        ({bool loaded, Uint8List? bytes})
      >(
        selector: (state) => (
          loaded: state.containsKey(widget.index),
          bytes: state[widget.index],
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
                        child: preview.bytes != null
                            ? Image.memory(
                                preview.bytes!,
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
