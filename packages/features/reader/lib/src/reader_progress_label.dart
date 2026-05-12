import 'package:domain_models/domain_models.dart';

String readerProgressLabel({
  required BookFormat? format,
  required double progress,
  required int? chapterCurrentPage,
  required int? chapterTotalPages,
  required bool isDragging,
}) {
  if (format == BookFormat.cbz) {
    return comicPageLabel(
          currentPage: isDragging
              ? _zeroIndexedPageFromProgress(progress, chapterTotalPages)
              : chapterCurrentPage,
          totalPages: chapterTotalPages,
        ) ??
        '';
  }

  final percent = readingPercentLabel(progress);
  if (isDragging) return percent;

  final sectionPage = visualSectionPageLabel(
    currentPage: chapterCurrentPage,
    totalPages: chapterTotalPages,
  );
  return sectionPage == null ? percent : '$percent · $sectionPage';
}

String readingPercentLabel(double progress) {
  final clamped = _clampProgress(progress);
  return '${(clamped * 100).round()}%';
}

String? visualSectionPageLabel({
  required int? currentPage,
  required int? totalPages,
}) {
  if (currentPage == null || totalPages == null || totalPages <= 0) return null;
  final page = _displayVisualSectionPage(currentPage, totalPages);
  return '$page / $totalPages';
}

String? comicPageLabel({required int? currentPage, required int? totalPages}) {
  if (currentPage == null || totalPages == null || totalPages <= 0) return null;
  final page = displayZeroIndexedPage(currentPage, totalPages);
  return '$page / $totalPages';
}

int displayZeroIndexedPage(int pageIndex, int totalPages) {
  final oneIndexed = pageIndex + 1;
  if (oneIndexed < 1) return 1;
  if (totalPages > 0 && oneIndexed > totalPages) return totalPages;
  return oneIndexed;
}

int _displayVisualSectionPage(int pageIndex, int totalPages) {
  if (pageIndex < 1) return 1;
  if (pageIndex > totalPages) return totalPages;
  return pageIndex;
}

int? _zeroIndexedPageFromProgress(double progress, int? totalPages) {
  if (totalPages == null || totalPages <= 0) return null;
  return (_clampProgress(progress) * totalPages).floor();
}

double _clampProgress(double progress) {
  if (!progress.isFinite) return 0;
  if (progress < 0) return 0;
  if (progress > 1) return 1;
  return progress;
}
