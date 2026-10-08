import 'package:reader_webview/reader_webview.dart';

/// Where a chapter row stands relative to the chapter being read.
enum ReaderTocReadingState { read, active, upcoming }

/// Chapters before the active one are read, except the active chapter's
/// ancestors: a part that contains the current chapter is not finished.
/// Without an active chapter every row is upcoming.
List<ReaderTocReadingState> readerTocReadingStates(
  List<ReaderTocItem> items,
  int? activeIndex,
) {
  if (activeIndex == null || activeIndex < 0 || activeIndex >= items.length) {
    return List.filled(items.length, ReaderTocReadingState.upcoming);
  }
  final states = [
    for (var index = 0; index < items.length; index += 1)
      index < activeIndex
          ? ReaderTocReadingState.read
          : ReaderTocReadingState.upcoming,
  ];
  states[activeIndex] = ReaderTocReadingState.active;
  var level = items[activeIndex].level;
  for (var index = activeIndex - 1; index >= 0 && level > 0; index -= 1) {
    if (items[index].level < level) {
      states[index] = ReaderTocReadingState.upcoming;
      level = items[index].level;
    }
  }
  return states;
}

/// Estimated page the chapter starts on, when the renderer reports one.
///
/// The renderer rounds the chapter's start fraction up, so the opening
/// chapter can report page 0; it is shown as page 1.
int? readerTocStartPage(ReaderTocItem item) {
  final page = item.startPage;
  if (page == null || page < 0) return null;
  return page < 1 ? 1 : page;
}

/// Whole-percent start of the chapter, used when no page is known.
int? readerTocStartPercent(ReaderTocItem item) {
  final fraction = item.startPercentage;
  if (fraction == null || !fraction.isFinite) return null;
  return (fraction.clamp(0.0, 1.0) * 100).round();
}
