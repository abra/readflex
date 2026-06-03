import 'package:reader_webview/reader_webview.dart';

const _progressEpsilon = 0.000001;

int? readerActiveTocIndex({
  required List<ReaderTocItem> items,
  required double? readingProgress,
  required String? chapterTitle,
}) {
  return readerActiveTocIndexFromTitle(
        items: items,
        chapterTitle: chapterTitle,
      ) ??
      readerActiveTocIndexFromProgress(
        items: items,
        readingProgress: readingProgress,
      );
}

int? readerActiveTocIndexFromProgress({
  required List<ReaderTocItem> items,
  required double? readingProgress,
}) {
  if (items.isEmpty || readingProgress == null || readingProgress.isNaN) {
    return null;
  }

  final progress = readingProgress.clamp(0.0, 1.0).toDouble();
  int? activeIndex;
  double? activeStart;
  int? firstPositionedIndex;

  for (var index = 0; index < items.length; index += 1) {
    final start = items[index].startPercentage;
    if (start == null || start.isNaN) continue;

    final normalizedStart = start.clamp(0.0, 1.0).toDouble();
    firstPositionedIndex ??= index;
    if (normalizedStart <= progress + _progressEpsilon &&
        (activeStart == null || normalizedStart >= activeStart)) {
      activeIndex = index;
      activeStart = normalizedStart;
    }
  }

  return activeIndex ?? firstPositionedIndex;
}

int? readerActiveTocIndexFromTitle({
  required List<ReaderTocItem> items,
  required String? chapterTitle,
}) {
  final title = chapterTitle?.trim();
  if (items.isEmpty || title == null || title.isEmpty) return null;

  final exactIndex = items.indexWhere((item) => item.label.trim() == title);
  if (exactIndex != -1) return exactIndex;

  final foldedTitle = title.toLowerCase();
  final foldedIndex = items.indexWhere(
    (item) => item.label.trim().toLowerCase() == foldedTitle,
  );
  return foldedIndex == -1 ? null : foldedIndex;
}
