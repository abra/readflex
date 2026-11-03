part of 'library_bloc.dart';

/// One deadline timer; foreground updates read only the review queue.
extension _LibraryPracticeSchedule on LibraryBloc {
  Set<ReviewableType> get _activeReviewTypes => {
    ReviewableType.dictionary,
    if (_preferencesService?.current.practiceReviewHighlights ?? true)
      ReviewableType.highlight,
  };

  void _cancelPracticeTimer() {
    _practiceTimer?.cancel();
    _practiceTimer = null;
  }

  bool get _canSchedulePractice =>
      !isClosed &&
      _isForeground &&
      !_libraryLoading &&
      _fsrsRepository != null &&
      state.status == LibraryStatus.success;

  void _schedulePracticeRefresh(DateTime? nextReviewAt) {
    _cancelPracticeTimer();
    if (!_canSchedulePractice || nextReviewAt == null) return;
    final remaining = nextReviewAt.difference(_clock());
    // Timer rounds sub-millisecond durations down; avoid firing before the
    // queue's timestamp boundary and repeatedly requesting the same deadline.
    const minimumDelay = Duration(milliseconds: 1);
    _setPracticeTimer(remaining < minimumDelay ? minimumDelay : remaining);
  }

  void _schedulePracticeRetry() {
    _cancelPracticeTimer();
    if (_canSchedulePractice) {
      // Keep the last counts on a read error, with a bounded retry delay.
      _setPracticeTimer(const Duration(minutes: 1));
    }
  }

  void _setPracticeTimer(Duration delay) {
    _practiceTimer = Timer(delay, () {
      _practiceTimer = null;
      if (_canSchedulePractice) add(const LibraryPracticeRefreshRequested());
    });
  }

  void _onForegroundChanged(
    LibraryForegroundChanged event,
    Emitter<LibraryState> emit,
  ) {
    if (_isForeground == event.isForeground) return;
    _isForeground = event.isForeground;
    _practiceGeneration++;
    _cancelPracticeTimer();
    if (!_isForeground) return;
    if (_libraryLoading) {
      _refreshPracticeAfterLoad = true;
    } else {
      add(const LibraryPracticeRefreshRequested());
    }
  }
}
