import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:stream_transform/stream_transform.dart';

import 'practice_item_loader.dart';
import 'practice_source_index.dart';
import 'practice_source_summary.dart';

part 'practice_event.dart';
part 'practice_state.dart';

/// The Practice hub: counts for today, totals per collection and per source.
///
/// Each load first registers review rows for highlights that predate review
/// tracking, so the counts include them.
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc({
    required FsrsRepository fsrsRepository,
    required DictionaryRepository dictionaryRepository,
    required HighlightRepository highlightRepository,
    required BookRepository bookRepository,
    required PreferencesService preferencesService,
    ArticleRepository? articleRepository,
  }) : _fsrsRepository = fsrsRepository,
       _dictionaryRepository = dictionaryRepository,
       _highlightRepository = highlightRepository,
       _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _preferencesService = preferencesService,
       _loader = PracticeItemLoader(
         dictionaryRepository: dictionaryRepository,
         highlightRepository: highlightRepository,
         fsrsRepository: fsrsRepository,
       ),
       super(const PracticeState()) {
    on<PracticeLoadRequested>(
      _onLoadRequested,
      transformer: (events, mapper) => events.switchMap(mapper),
    );
  }

  final FsrsRepository _fsrsRepository;
  final DictionaryRepository _dictionaryRepository;
  final HighlightRepository _highlightRepository;
  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  final PreferencesService _preferencesService;
  final PracticeItemLoader _loader;

  Future<void> _onLoadRequested(
    PracticeLoadRequested event,
    Emitter<PracticeState> emit,
  ) async {
    if (state.status == PracticeStatus.initial) {
      emit(state.copyWith(status: PracticeStatus.loading));
    }
    try {
      await _loader.backfillHighlights();
      final (stats, sources, entries, highlights, due) = await (
        _fsrsRepository.getStats(),
        PracticeSourceIndex.load(
          bookRepository: _bookRepository,
          articleRepository: _articleRepository,
        ),
        _dictionaryRepository.getEntries(),
        _highlightRepository.getHighlights(),
        _fsrsRepository.getDueItems(),
      ).wait;
      emit(
        state.copyWith(
          status: PracticeStatus.ready,
          stats: stats,
          sources: _summaries(sources, entries, highlights, due),
          reviewHighlights:
              _preferencesService.current.practiceReviewHighlights,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }

  static List<PracticeSourceSummary> _summaries(
    PracticeSourceIndex sources,
    List<DictionaryEntry> entries,
    List<Highlight> highlights,
    List<ReviewItem> due,
  ) {
    final words = <String, int>{};
    final quotes = <String, int>{};
    final dueBySource = <String, int>{};
    for (final entry in entries) {
      final id = entry.sourceId;
      if (id != null) words[id] = (words[id] ?? 0) + 1;
    }
    for (final highlight in highlights) {
      if (highlight.kind != HighlightKind.text) continue;
      quotes[highlight.sourceId] = (quotes[highlight.sourceId] ?? 0) + 1;
    }
    for (final item in due) {
      final id = item.sourceId;
      if (id != null) dueBySource[id] = (dueBySource[id] ?? 0) + 1;
    }
    final summaries = [
      for (final id in {...words.keys, ...quotes.keys})
        if (sources[id] case final source?)
          PracticeSourceSummary(
            source: source,
            words: words[id] ?? 0,
            highlights: quotes[id] ?? 0,
            due: dueBySource[id] ?? 0,
          ),
    ];
    summaries.sort((a, b) {
      final byDue = b.due.compareTo(a.due);
      if (byDue != 0) return byDue;
      return a.source.title.toLowerCase().compareTo(
        b.source.title.toLowerCase(),
      );
    });
    return summaries;
  }
}
