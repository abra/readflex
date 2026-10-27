import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// A source's cover in the shared frame, artwork only.
class PracticeSourceCover extends StatelessWidget {
  const PracticeSourceCover({required this.source, super.key});

  final LibrarySource source;

  @override
  Widget build(BuildContext context) => AppSourceCoverFrame(
    cover: AppSourceCover(
      title: source.title,
      author: source.author,
      source: source.sourceName,
      seed: source.id,
      isArticle: source.sourceType == SourceType.article,
      coverImage: appSourceCoverImageFromPath(source.coverImagePath),
      textDirection: switch (source.inferredTextDirection) {
        ArticleTextDirection.rtl => TextDirection.rtl,
        ArticleTextDirection.ltr || null => TextDirection.ltr,
      },
      showAuthor: false,
      showTitle: false,
      showProgress: false,
      showMatte: false,
    ),
  );
}
