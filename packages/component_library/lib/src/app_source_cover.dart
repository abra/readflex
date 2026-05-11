import 'package:flutter/material.dart';

import 'app_cover_art.dart';
import 'theme/tokens/app_radius.dart';

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
              errorBuilder: (_, _, _) => fallback,
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
