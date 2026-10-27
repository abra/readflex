import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

import 'practice_item.dart';
import 'practice_source_index.dart';

enum PracticeWordsStatus { initial, loading, ready, failure }

/// Which words the list shows.
enum PracticeWordsFilter { all, learning, mastered }

class PracticeWordsState extends Equatable {
  const PracticeWordsState({
    this.status = PracticeWordsStatus.initial,
    this.words = const [],
    this.query = '',
    this.filter = PracticeWordsFilter.all,
  });

  final PracticeWordsStatus status;

  /// Every saved word, newest first.
  final List<PracticeWordItem> words;
  final String query;
  final PracticeWordsFilter filter;

  /// [words] after [filter] and [query].
  List<PracticeWordItem> get visible {
    final needle = query.trim().toLowerCase();
    return [
      for (final word in words)
        if (switch (filter) {
              PracticeWordsFilter.all => true,
              PracticeWordsFilter.learning => !word.isMastered,
              PracticeWordsFilter.mastered => word.isMastered,
            } &&
            (needle.isEmpty ||
                word.entry.word.toLowerCase().contains(needle) ||
                word.entry.translation.toLowerCase().contains(needle)))
          word,
    ];
  }

  PracticeWordsState copyWith({
    PracticeWordsStatus? status,
    List<PracticeWordItem>? words,
    String? query,
    PracticeWordsFilter? filter,
  }) => PracticeWordsState(
    status: status ?? this.status,
    words: words ?? this.words,
    query: query ?? this.query,
    filter: filter ?? this.filter,
  );

  @override
  List<Object?> get props => [status, words, query, filter];
}

/// The saved words list: load, search, filter, remove.
class PracticeWordsCubit extends Cubit<PracticeWordsState> {
  PracticeWordsCubit({
    required DictionaryRepository dictionaryRepository,
    required FsrsRepository fsrsRepository,
    required BookRepository bookRepository,
    ArticleRepository? articleRepository,
  }) : _dictionaryRepository = dictionaryRepository,
       _fsrsRepository = fsrsRepository,
       _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       super(const PracticeWordsState());

  final DictionaryRepository _dictionaryRepository;
  final FsrsRepository _fsrsRepository;
  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    if (state.status == PracticeWordsStatus.initial) {
      emit(state.copyWith(status: PracticeWordsStatus.loading));
    }
    try {
      final (entries, sources) = await (
        _dictionaryRepository.getEntries(),
        PracticeSourceIndex.load(
          bookRepository: _bookRepository,
          articleRepository: _articleRepository,
        ),
      ).wait;
      final states = await _fsrsRepository.getReviewStates([
        for (final entry in entries) entry.id,
      ]);
      final words = <PracticeWordItem>[];
      for (final entry in entries) {
        final anchors = await _dictionaryRepository.getAnchorsByEntry(entry.id);
        words.add(
          PracticeWordItem(
            entry: entry,
            fsrs: states[entry.id] ?? const FsrsCardData(),
            sourceTitle: sources.titleOf(entry.sourceId),
            anchorCfiRange: anchors.firstOrNull?.cfiRange,
          ),
        );
      }
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: PracticeWordsStatus.ready, words: words));
    } catch (e, st) {
      addError(e, st);
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: PracticeWordsStatus.failure));
    }
  }

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setFilter(PracticeWordsFilter filter) =>
      emit(state.copyWith(filter: filter));

  /// Deletes the word and its review row; the list drops it at once.
  Future<void> remove(PracticeWordItem word) async {
    final remaining = [
      for (final item in state.words)
        if (item.itemId != word.itemId) item,
    ];
    emit(state.copyWith(words: remaining));
    try {
      await _dictionaryRepository.deleteEntry(word.entry.id);
    } catch (e, st) {
      addError(e, st);
      if (!isClosed) await load();
    }
  }
}
