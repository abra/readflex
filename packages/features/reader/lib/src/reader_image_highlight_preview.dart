import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_comic_thumbnail_cubit.dart';

/// Crops a shared, bounded page thumbnail, never the full archive image.
class ReaderImageHighlightPreview extends StatefulWidget {
  const ReaderImageHighlightPreview({required this.area, super.key});

  final HighlightImageArea area;

  @override
  State<ReaderImageHighlightPreview> createState() =>
      _ReaderImageHighlightPreviewState();
}

class _ReaderImageHighlightPreviewState
    extends State<ReaderImageHighlightPreview> {
  late final _thumbnails = context.read<ReaderComicThumbnailCubit>();

  @override
  void initState() {
    super.initState();
    _thumbnails.request(widget.area.pageIndex);
  }

  @override
  void didUpdateWidget(covariant ReaderImageHighlightPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area.pageIndex != widget.area.pageIndex) {
      _thumbnails.release(oldWidget.area.pageIndex);
      _thumbnails.request(widget.area.pageIndex);
    }
  }

  @override
  void dispose() {
    _thumbnails.release(widget.area.pageIndex);
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
          loaded: state.containsKey(widget.area.pageIndex),
          bytes: state[widget.area.pageIndex],
        ),
        builder: (context, preview) => ColoredBox(
          color: context.colors.surfaceContainerLow,
          child: preview.bytes != null
              ? _CroppedThumbnail(bytes: preview.bytes!, area: widget.area)
              : Center(
                  child: preview.loaded
                      ? Semantics(
                          label: context.l10n.readerThumbnailUnavailable,
                          child: AppPlainIconButton(
                            icon: AppIcons.refresh,
                            tooltip: context.l10n.commonRetry,
                            onPressed: () =>
                                _thumbnails.retry(widget.area.pageIndex),
                          ),
                        )
                      : const _PreviewPlaceholder(),
                ),
        ),
      );
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) => Icon(
    AppIcons.book,
    size: AppIconSize.md,
    color: context.colors.onSurfaceVariant,
  );
}

class _CroppedThumbnail extends StatefulWidget {
  const _CroppedThumbnail({required this.bytes, required this.area});

  final Uint8List bytes;
  final HighlightImageArea area;

  @override
  State<_CroppedThumbnail> createState() => _CroppedThumbnailState();
}

class _CroppedThumbnailState extends State<_CroppedThumbnail> {
  ImageStream? _stream;
  ImageInfo? _image;
  late final _listener = ImageStreamListener(
    (image, _) => _replaceImage(image),
    onError: (Object error, StackTrace? stack) => _replaceImage(null),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _CroppedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) _resolve();
  }

  void _resolve() {
    // MemoryImage uses the page's shared byte identity as its ImageCache key.
    final stream = MemoryImage(
      widget.bytes,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _replaceImage(null);
    _stream = stream..addListener(_listener);
  }

  void _replaceImage(ImageInfo? image) {
    final previous = _image;
    setState(() => _image = image);
    // A painter from the preceding frame may still hold the old handle.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image?.image;
    final area = widget.area;
    final normalized = Rect.fromLTWH(area.x, area.y, area.width, area.height);
    if (image == null || !normalized.isFinite || normalized.isEmpty) {
      return const Center(child: _PreviewPlaceholder());
    }
    final clipped = normalized.intersect(const Rect.fromLTWH(0, 0, 1, 1));
    if (clipped.isEmpty) return const Center(child: _PreviewPlaceholder());
    return CustomPaint(
      painter: _AreaPainter(
        image,
        Rect.fromLTWH(
          clipped.left * image.width,
          clipped.top * image.height,
          clipped.width * image.width,
          clipped.height * image.height,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _AreaPainter extends CustomPainter {
  const _AreaPainter(this.image, this.source);

  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = applyBoxFit(BoxFit.contain, source.size, size);
    final destination = Alignment.center.inscribe(
      fit.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaPainter oldDelegate) =>
      image != oldDelegate.image || source != oldDelegate.source;
}
