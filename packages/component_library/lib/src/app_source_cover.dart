import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_cover_art.dart';
import 'theme/tokens/app_radius.dart';

final _reportedCoverDecodeFailures = <String>{};

/// Shared renderer for imported source covers and deterministic fallback art.
class AppSourceCover extends StatelessWidget {
  const AppSourceCover({
    required this.title,
    required this.seed,
    this.author,
    this.coverImage,
    this.progress,
    this.showAuthor = true,
    this.showTitle = true,
    this.showProgress = true,
    this.showMatte = true,
    this.fit = BoxFit.fill,
    super.key,
  });

  final String title;
  final String seed;
  final String? author;
  final ImageProvider? coverImage;
  final double? progress;
  final bool showAuthor;
  final bool showTitle;
  final bool showProgress;
  final bool showMatte;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallback = AppCoverArt(
          title: title,
          author: author,
          seed: seed,
          progress: showProgress ? progress : null,
          showAuthor: showAuthor,
          showTitle: showTitle,
          showMatte: showMatte,
          height: constraints.maxHeight,
          width: constraints.maxWidth,
        );

        if (coverImage case final imageProvider?) {
          final image = ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image(
              image: imageProvider,
              fit: fit,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              errorBuilder: (_, error, stackTrace) {
                _reportCoverDecodeFailure(
                  imageProvider: imageProvider,
                  title: title,
                  seed: seed,
                  error: error,
                  stackTrace: stackTrace,
                );
                return fallback;
              },
            ),
          );
          if (!showMatte) return image;
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: image,
          );
        }

        return fallback;
      },
    );
  }
}

void _reportCoverDecodeFailure({
  required ImageProvider imageProvider,
  required String title,
  required String seed,
  required Object error,
  required StackTrace? stackTrace,
}) {
  final key = '$imageProvider|$seed';
  if (!_reportedCoverDecodeFailures.add(key)) return;

  debugPrint(
    '[source-cover-decode] Failed to decode cover '
    '(sourceId=$seed, title="$title", provider=$imageProvider): $error',
  );

  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'component_library',
      context: ErrorDescription('while decoding a source cover image'),
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'image provider',
          imageProvider,
        );
        yield StringProperty('title', title);
        yield StringProperty('source id', seed);
      },
    ),
  );
}
