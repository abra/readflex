import 'package:domain_models/domain_models.dart';

String readerProgressLabel({
  SourceType sourceType = SourceType.book,
  required BookFormat? format,
  required double progress,
  required int? chapterCurrentPage,
  required int? chapterTotalPages,
  required bool isDragging,
}) {
  if (isImagePageFormat(format)) {
    return comicPageLabel(
          currentPage: isDragging
              ? _zeroIndexedPageFromProgress(progress, chapterTotalPages)
              : chapterCurrentPage,
          totalPages: chapterTotalPages,
        ) ??
        '';
  }

  if (sourceType == SourceType.article) {
    return visualSectionPageLabel(
          currentPage: isDragging
              ? _oneIndexedPageFromProgress(progress, chapterTotalPages)
              : chapterCurrentPage,
          totalPages: chapterTotalPages,
        ) ??
        readingPercentLabel(progress);
  }

  final percent = readingPercentLabel(progress);
  if (isDragging) return percent;

  final sectionPage = visualSectionPageLabel(
    currentPage: chapterCurrentPage,
    totalPages: chapterTotalPages,
  );
  return sectionPage == null ? percent : '$percent · $sectionPage';
}

bool isImagePageFormat(BookFormat? format) {
  return format == BookFormat.cbz || format == BookFormat.djvu;
}

const readerDefaultSeekSettleTimeout = Duration(milliseconds: 600);
const readerImagePageSeekSettleTimeout = Duration(seconds: 3);

Duration readerSeekSettleTimeout({required BookFormat? format}) {
  if (isImagePageFormat(format)) return readerImagePageSeekSettleTimeout;
  return readerDefaultSeekSettleTimeout;
}

String readingPercentLabel(double progress) {
  final clamped = _clampProgress(progress);
  return '${(clamped * 100).round()}%';
}

int? readerSliderDivisions({
  required SourceType sourceType,
  required BookFormat? format,
  required int? totalPages,
}) {
  final hasDiscretePages =
      sourceType == SourceType.article || isImagePageFormat(format);
  if (!hasDiscretePages || totalPages == null || totalPages <= 1) {
    return null;
  }
  return totalPages - 1;
}

bool shouldShowReaderProgressSlider({
  required SourceType sourceType,
  required BookFormat? format,
  required int? totalPages,
}) {
  final isPageOnlyProgress =
      sourceType == SourceType.article || isImagePageFormat(format);
  if (isPageOnlyProgress && totalPages != null && totalPages <= 1) {
    return false;
  }
  return true;
}

double snappedReaderSeekProgress({
  required SourceType sourceType,
  required BookFormat? format,
  required double progress,
  required int? totalPages,
}) {
  final clamped = _clampProgress(progress);
  final hasDiscretePages =
      sourceType == SourceType.article || isImagePageFormat(format);
  if (!hasDiscretePages || totalPages == null || totalPages <= 1) {
    return clamped;
  }
  final divisions = totalPages - 1;
  return (_clampProgress((clamped * divisions).round() / divisions));
}

double readerSliderValue({
  required SourceType sourceType,
  required BookFormat? format,
  required double progress,
  required int? currentPage,
  required int? totalPages,
}) {
  final usesPagePosition =
      sourceType == SourceType.article || isImagePageFormat(format);
  if (!usesPagePosition) {
    return _clampProgress(progress);
  }
  if (currentPage == null || totalPages == null || totalPages <= 0) {
    return snappedReaderSeekProgress(
      sourceType: sourceType,
      format: format,
      progress: progress,
      totalPages: totalPages,
    );
  }
  if (totalPages == 1) return 0;

  final page = isImagePageFormat(format)
      ? displayZeroIndexedPage(currentPage, totalPages)
      : _displayVisualSectionPage(currentPage, totalPages);
  return _clampProgress((page - 1) / (totalPages - 1));
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
  if (totalPages == 1) return 0;
  return (_clampProgress(progress) * (totalPages - 1)).round();
}

int? _oneIndexedPageFromProgress(double progress, int? totalPages) {
  if (totalPages == null || totalPages <= 0) return null;
  if (totalPages == 1) return 1;
  return (_clampProgress(progress) * (totalPages - 1)).round() + 1;
}

double _clampProgress(double progress) {
  if (!progress.isFinite) return 0;
  if (progress < 0) return 0;
  if (progress > 1) return 1;
  return progress;
}
