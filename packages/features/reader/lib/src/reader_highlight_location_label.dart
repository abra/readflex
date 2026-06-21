import 'package:domain_models/domain_models.dart';

String? readerHighlightLocationLabel(Highlight highlight) {
  final progress = highlight.progress;
  if (progress != null) {
    final percentage = (progress * 100).clamp(0, 100).round();
    final chapterTitle = highlight.chapterTitle?.trim();
    return [
      if (chapterTitle != null && chapterTitle.isNotEmpty) chapterTitle,
      '$percentage%',
    ].join(' · ');
  }

  final pageNumber = highlight.pageNumber;
  if (pageNumber != null) return 'Page $pageNumber';

  return null;
}
