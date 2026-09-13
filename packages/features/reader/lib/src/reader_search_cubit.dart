import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

typedef ReaderBookSearch = Stream<ReaderSearchEvent> Function(String query);

enum ReaderSearchErrorCode { searchFailed }

class ReaderSearchState extends Equatable {
  const ReaderSearchState({
    this.query = '',
    this.results = const [],
    this.recentQueries = const [],
    this.progress = 0,
    this.isLoading = false,
    this.errorMessage,
    this.errorCode,
    this.clearSearchToken = 0,
  });

  final String query;
  final List<ReaderSearchResult> results;
  final List<String> recentQueries;
  final double progress;
  final bool isLoading;
  final String? errorMessage;
  final ReaderSearchErrorCode? errorCode;

  /// Incremented when an already-rendered foliate-js search needs clearing.
  final int clearSearchToken;

  bool get hasSearchContent =>
      isLoading ||
      results.isNotEmpty ||
      errorMessage != null ||
      errorCode != null;

  ReaderSearchState copyWith({
    String? query,
    List<ReaderSearchResult>? results,
    List<String>? recentQueries,
    double? progress,
    bool? isLoading,
    String? errorMessage,
    ReaderSearchErrorCode? errorCode,
    bool clearError = false,
    int? clearSearchToken,
  }) {
    return ReaderSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      recentQueries: recentQueries ?? this.recentQueries,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      clearSearchToken: clearSearchToken ?? this.clearSearchToken,
    );
  }

  @override
  List<Object?> get props => [
    query,
    results,
    recentQueries,
    progress,
    isLoading,
    errorMessage,
    errorCode,
    clearSearchToken,
  ];
}

class ReaderSearchCubit extends Cubit<ReaderSearchState> {
  ReaderSearchCubit({
    List<String> initialRecentQueries = const [],
    ValueChanged<List<String>>? onRecentQueriesChanged,
  }) : _onRecentQueriesChanged = onRecentQueriesChanged,
       super(ReaderSearchState(recentQueries: initialRecentQueries));

  static const minQueryLength = 2;
  static const historyLimit = 10;
  static const _debounceDelay = Duration(milliseconds: 300);
  static const _publishInterval = Duration(milliseconds: 16);

  final ValueChanged<List<String>>? _onRecentQueriesChanged;

  Timer? _debounce;
  Timer? _publishTimer;
  final _pendingResults = <ReaderSearchResult>[];
  double? _pendingProgress;
  StreamSubscription<ReaderSearchEvent>? _searchSubscription;
  int _searchGeneration = 0;

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _searchGeneration++;
    _discardPendingUpdates();
    await _searchSubscription?.cancel();
    return super.close();
  }

  void queryChanged(String value, {required ReaderBookSearch searchBook}) {
    _queueSearch(value, debounce: true, searchBook: searchBook);
  }

  void recentQuerySelected(
    String query, {
    required ReaderBookSearch searchBook,
  }) {
    _queueSearch(query, debounce: false, searchBook: searchBook);
  }

  void resultSelected() {
    final recentQueries = _updatedRecentQueries(state.query);
    if (listEquals(recentQueries, state.recentQueries)) return;
    emit(state.copyWith(recentQueries: recentQueries));
    _onRecentQueriesChanged?.call(recentQueries);
  }

  void recentQueryRemoved(String query) {
    final recentQueries = [
      for (final recent in state.recentQueries)
        if (recent != query) recent,
    ];
    emit(state.copyWith(recentQueries: recentQueries));
    _onRecentQueriesChanged?.call(recentQueries);
  }

  void reset() {
    _debounce?.cancel();
    _searchGeneration++;
    _discardPendingUpdates();
    unawaited(_searchSubscription?.cancel());
    _searchSubscription = null;
    emit(
      state.copyWith(
        query: '',
        results: const [],
        progress: 0,
        isLoading: false,
        clearError: true,
      ),
    );
  }

  void _queueSearch(
    String value, {
    required bool debounce,
    required ReaderBookSearch searchBook,
  }) {
    _debounce?.cancel();
    final query = value.trim();
    final shouldClearCurrentSearch = state.hasSearchContent;
    _searchGeneration++;
    _discardPendingUpdates();
    unawaited(_searchSubscription?.cancel());
    _searchSubscription = null;

    final clearSearchToken = shouldClearCurrentSearch
        ? state.clearSearchToken + 1
        : state.clearSearchToken;

    if (query.length < minQueryLength) {
      emit(
        state.copyWith(
          query: value,
          results: const [],
          progress: 0,
          isLoading: false,
          clearError: true,
          clearSearchToken: clearSearchToken,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        query: value,
        results: const [],
        progress: 0,
        isLoading: true,
        clearError: true,
        clearSearchToken: clearSearchToken,
      ),
    );

    if (debounce) {
      _debounce = Timer(_debounceDelay, () => _runSearch(query, searchBook));
    } else {
      _runSearch(query, searchBook);
    }
  }

  List<String> _updatedRecentQueries(String query) {
    final normalized = query.trim();
    if (normalized.length < minQueryLength) return state.recentQueries;
    return [
      normalized,
      for (final recent in state.recentQueries)
        if (recent.toLowerCase() != normalized.toLowerCase()) recent,
    ].take(historyLimit).toList(growable: false);
  }

  void _runSearch(String query, ReaderBookSearch searchBook) {
    final generation = ++_searchGeneration;
    var completed = false;
    unawaited(_searchSubscription?.cancel());

    bool isActive() =>
        !isClosed && generation == _searchGeneration && !completed;

    void finish() {
      if (!isActive()) return;
      completed = true;
      _publishPendingUpdates(finished: true);
    }

    void fail({String? message}) {
      if (!isActive()) return;
      completed = true;
      _discardPendingUpdates();
      emit(
        state.copyWith(
          results: const [],
          isLoading: false,
          errorMessage: message,
          errorCode: message == null
              ? ReaderSearchErrorCode.searchFailed
              : null,
        ),
      );
    }

    try {
      _searchSubscription = searchBook(query).listen(
        (event) {
          if (!isActive()) return;
          switch (event) {
            case ReaderSearchProgress(:final progress):
              if (progress == (_pendingProgress ?? state.progress)) return;
              _pendingProgress = progress;
            case ReaderSearchResults(:final results):
              if (results.isEmpty) return;
              _pendingResults.addAll(results);
            case ReaderSearchDone():
              finish();
              return;
            case ReaderSearchError(:final message):
              fail(message: message);
              return;
          }
          // A renderer can emit thousands of tiny chunks in one event-loop turn.
          // Publish bounded batches, preserving immediate completion and errors.
          _publishTimer ??= Timer(_publishInterval, () {
            if (isActive()) _publishPendingUpdates();
          });
        },
        onError: (_) => fail(),
        onDone: finish,
      );
    } catch (_) {
      fail();
    }
  }

  void _publishPendingUpdates({bool finished = false}) {
    final results = _pendingResults.isEmpty
        ? state.results
        : List<ReaderSearchResult>.unmodifiable(
            state.results.followedBy(_pendingResults),
          );
    final progress = finished ? 1.0 : _pendingProgress ?? state.progress;
    _discardPendingUpdates();
    emit(
      state.copyWith(
        results: results,
        progress: progress,
        isLoading: !finished,
      ),
    );
  }

  void _discardPendingUpdates() {
    _publishTimer?.cancel();
    _publishTimer = null;
    _pendingResults.clear();
    _pendingProgress = null;
  }
}
