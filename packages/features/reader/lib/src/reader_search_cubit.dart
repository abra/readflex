import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

typedef ReaderBookSearch = Stream<ReaderSearchEvent> Function(String query);

class ReaderSearchState extends Equatable {
  const ReaderSearchState({
    this.query = '',
    this.results = const [],
    this.recentQueries = const [],
    this.progress = 0,
    this.isLoading = false,
    this.errorMessage,
    this.clearSearchToken = 0,
  });

  final String query;
  final List<ReaderSearchResult> results;
  final List<String> recentQueries;
  final double progress;
  final bool isLoading;
  final String? errorMessage;

  /// Incremented when an already-rendered foliate-js search needs clearing.
  final int clearSearchToken;

  bool get hasSearchContent =>
      isLoading || results.isNotEmpty || errorMessage != null;

  ReaderSearchState copyWith({
    String? query,
    List<ReaderSearchResult>? results,
    List<String>? recentQueries,
    double? progress,
    bool? isLoading,
    String? errorMessage,
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

  final ValueChanged<List<String>>? _onRecentQueriesChanged;

  Timer? _debounce;
  StreamSubscription<ReaderSearchEvent>? _searchSubscription;
  int _searchGeneration = 0;

  @override
  Future<void> close() async {
    _debounce?.cancel();
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
    var completedWithError = false;
    unawaited(_searchSubscription?.cancel());

    _searchSubscription = searchBook(query).listen(
      (event) {
        if (isClosed || generation != _searchGeneration) return;
        switch (event) {
          case ReaderSearchProgress(:final progress):
            if (progress == state.progress) return;
            emit(state.copyWith(progress: progress));
          case ReaderSearchResults(:final results):
            if (results.isEmpty) return;
            emit(state.copyWith(results: [...state.results, ...results]));
          case ReaderSearchDone():
            emit(state.copyWith(progress: 1));
          case ReaderSearchError(:final message):
            completedWithError = true;
            emit(
              state.copyWith(
                results: const [],
                isLoading: false,
                errorMessage: message,
              ),
            );
        }
      },
      onError: (_) {
        if (isClosed || generation != _searchGeneration) return;
        completedWithError = true;
        emit(
          state.copyWith(
            results: const [],
            isLoading: false,
            errorMessage: 'Search failed',
          ),
        );
      },
      onDone: () {
        if (isClosed || generation != _searchGeneration || completedWithError) {
          return;
        }
        emit(
          state.copyWith(
            progress: 1,
            isLoading: false,
          ),
        );
      },
    );
  }
}
