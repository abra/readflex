import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_cover_art.dart';
import 'source_cover_tokens.dart';

final _reportedCoverDecodeFailures = <String>{};

/// Shared renderer for imported source covers and deterministic fallback art.
class AppSourceCover extends StatelessWidget {
  const AppSourceCover({
    required this.title,
    required this.seed,
    this.author,
    this.source,
    this.coverImage,
    this.progress,
    this.isArticle = false,
    this.showAuthor = true,
    this.showTitle = true,
    this.showProgress = true,
    this.showMatte = true,
    this.centerText = false,
    this.bottomReserve = 0,
    this.fit = BoxFit.fill,
    this.articleBadgeAlignment = Alignment.topLeft,
    this.showArticleBadge = true,
    this.textScale = 1,
    super.key,
  });

  final String title;
  final String seed;
  final String? author;
  final String? source;
  final ImageProvider? coverImage;
  final double? progress;
  final bool isArticle;
  final bool showAuthor;
  final bool showTitle;
  final bool showProgress;
  final bool showMatte;
  final bool centerText;
  final double bottomReserve;
  final BoxFit fit;
  final Alignment articleBadgeAlignment;
  final bool showArticleBadge;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallback = AppCoverArt(
          title: title,
          author: author,
          source: source,
          seed: seed,
          isArticle: isArticle,
          progress: showProgress ? progress : null,
          showAuthor: showAuthor,
          showTitle: showTitle,
          showMatte: showMatte,
          centerText: centerText,
          bottomReserve: bottomReserve,
          articleBadgeAlignment: articleBadgeAlignment,
          showArticleBadge: showArticleBadge,
          textScale: textScale,
          height: constraints.maxHeight,
          width: constraints.maxWidth,
        );

        if (!isArticle) {
          if (coverImage case final imageProvider?) {
            final image = ClipRRect(
              borderRadius: BorderRadius.circular(appSourceCoverRadius),
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
                borderRadius: BorderRadius.circular(appSourceCoverRadius),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: image,
            );
          }
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
