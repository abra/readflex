import 'package:flutter/material.dart';

/// Sizes [child] with the decoded aspect ratio of [image].
///
/// Useful when metadata does not store image dimensions yet, but the detail
/// surface should preserve an imported image's original proportions.
class AppImageAspectRatio extends StatefulWidget {
  const AppImageAspectRatio({
    required this.child,
    this.image,
    this.fallbackAspectRatio = 2 / 3,
    super.key,
  });

  final ImageProvider? image;
  final double fallbackAspectRatio;
  final Widget child;

  @override
  State<AppImageAspectRatio> createState() => _AppImageAspectRatioState();
}

class _AppImageAspectRatioState extends State<AppImageAspectRatio> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageProvider? _resolvedImage;
  ImageConfiguration? _resolvedConfiguration;
  double? _imageAspectRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant AppImageAspectRatio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _resolveImage() {
    final image = widget.image;
    final configuration = createLocalImageConfiguration(context);
    if (image == _resolvedImage && configuration == _resolvedConfiguration) {
      return;
    }

    _stopListening();
    _resolvedImage = image;
    _resolvedConfiguration = configuration;
    _imageAspectRatio = null;

    if (image == null) return;

    final stream = image.resolve(configuration);
    final listener = ImageStreamListener(_handleImage, onError: _handleError);
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _handleImage(ImageInfo imageInfo, bool synchronousCall) {
    final width = imageInfo.image.width;
    final height = imageInfo.image.height;
    final aspectRatio = width > 0 && height > 0 ? width / height : null;

    if (synchronousCall) {
      _imageAspectRatio = aspectRatio;
      return;
    }

    if (!mounted) return;
    setState(() => _imageAspectRatio = aspectRatio);
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() => _imageAspectRatio = null);
  }

  void _stopListening() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _validAspectRatio(
      _imageAspectRatio ?? widget.fallbackAspectRatio,
    );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: widget.child,
    );
  }
}

double _validAspectRatio(double value) {
  if (value.isFinite && value > 0) return value;
  return 2 / 3;
}
