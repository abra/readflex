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
    this.location,
    this.progress,
    this.scrollOffset,
  });

  final int? location;
  final double? progress;
  final double? scrollOffset;

  @override
  List<Object?> get props => [location, progress, scrollOffset];
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

final class ReaderReviewReminderShown extends ReaderEvent {
  const ReaderReviewReminderShown();
}

final class ReaderReviewReminderDismissed extends ReaderEvent {
  const ReaderReviewReminderDismissed();
}
