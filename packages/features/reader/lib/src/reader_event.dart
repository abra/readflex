part of 'reader_bloc.dart';

sealed class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  List<Object?> get props => [];
}

final class ReaderSourceLoadRequested extends ReaderEvent {
  const ReaderSourceLoadRequested({required this.sourceId});

  final String sourceId;

  @override
  List<Object?> get props => [sourceId];
}

final class ReaderPositionUpdated extends ReaderEvent {
  const ReaderPositionUpdated({
    this.cfi,
    this.progress,
    this.scrollOffset,
  });

  /// Book: CFI string from foliate-js.
  final String? cfi;

  /// Book: overall reading progress in [0, 1].
  final double? progress;

  /// Article: scroll fraction in [0, 1].
  final double? scrollOffset;

  @override
  List<Object?> get props => [cfi, progress, scrollOffset];
}

final class ReaderTextSelected extends ReaderEvent {
  const ReaderTextSelected({
    required this.selectedText,
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
  });

  final String selectedText;
  final String? cfiRange;
  final int? pageNumber;
  final double? scrollOffset;

  @override
  List<Object?> get props => [selectedText, cfiRange, pageNumber, scrollOffset];
}

final class ReaderTextDeselected extends ReaderEvent {
  const ReaderTextDeselected();
}

final class ReaderHighlightsRefreshed extends ReaderEvent {
  const ReaderHighlightsRefreshed();
}

final class ReaderReviewReminderShown extends ReaderEvent {
  const ReaderReviewReminderShown();
}

final class ReaderReviewReminderDismissed extends ReaderEvent {
  const ReaderReviewReminderDismissed();
}

/// User tapped the reader — flip chrome visibility.
final class ReaderChromeToggled extends ReaderEvent {
  const ReaderChromeToggled();
}

/// Force-hide chrome (e.g. when text selection begins).
final class ReaderChromeHidden extends ReaderEvent {
  const ReaderChromeHidden();
}
