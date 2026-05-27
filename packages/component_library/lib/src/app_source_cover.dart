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
    this.topAlignText = false,
    this.topReserve = 0,
    this.bottomReserve = 0,
    this.fit = BoxFit.fill,
    this.articleBadgeAlignment = Alignment.topLeft,
    this.showArticleBadge = true,
    this.textDirection,
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
  final bool topAlignText;
  final double topReserve;
  final double bottomReserve;
  final BoxFit fit;
  final Alignment articleBadgeAlignment;
  final bool showArticleBadge;
  final TextDirection? textDirection;
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
          topAlignText: topAlignText,
          topReserve: topReserve,
          bottomReserve: bottomReserve,
          articleBadgeAlignment: articleBadgeAlignment,
          showArticleBadge: showArticleBadge,
          textDirection: textDirection,
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
                errorBuilder: (_, error, _) {
                  _reportCoverDecodeFailure(
                    imageProvider: imageProvider,
                    title: title,
                    seed: seed,
                    error: error,
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
}) {
  final key = '$imageProvider|$seed';
  if (!_reportedCoverDecodeFailures.add(key)) return;

  debugPrint(
    '[source-cover-decode] Failed to decode cover '
    '(sourceId=$seed, title="$title", provider=$imageProvider): $error',
  );
}
