import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Renders the cover area for a book tile — either the imported cover image
/// or, when no cover was extracted on import, a deterministic stylised
/// fallback produced by [AppCoverArt].
///
/// Used by both grid- and list-mode tiles; each passes its own toggles to
/// hide portions of the fallback text that would duplicate what the
/// surrounding row already shows.
class BookTileCover extends StatelessWidget {
  const BookTileCover({
    required this.book,
    this.showAuthor = true,
    this.showTitle = true,
    this.showProgress = true,
    super.key,
  });

  final Book book;
  final bool showAuthor;
  final bool showTitle;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallback = AppCoverArt(
          title: book.title,
          author: book.author,
          seed: book.id,
          progress: showProgress && book.readingProgress > 0
              ? book.readingProgress
              : null,
          showAuthor: showAuthor,
          showTitle: showTitle,
          height: constraints.maxHeight,
          width: constraints.maxWidth,
        );

        if (book.coverImagePath case final path? when path.isNotEmpty) {
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.file(
                File(path),
                fit: BoxFit.fill,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
          );
        }

        return fallback;
      },
    );
  }
}
