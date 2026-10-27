import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_item.dart';
import 'practice_source_index.dart';

enum PracticeHighlightsStatus { initial, loading, ready, failure }

/// Highlights of one source, in the list's order.
class PracticeHighlightGroup extends Equatable {
  const PracticeHighlightGroup({required this.title, required this.items});

  final String title;
  final List<PracticeHighlightItem> items;

  @override
  List<Object?> get props => [title, items];
}

class PracticeHighlightsState extends Equatable {
  const PracticeHighlightsState({
    this.status = PracticeHighlightsStatus.initial,
    this.highlights = const [],
    this.query = '',
    this.color,
  });

  final PracticeHighlightsStatus status;

  /// Every text highlight, newest first.
  final List<PracticeHighlightItem> highlights;
  final String query;

  /// `null` shows every colour.
  final HighlightColor? color;

  /// [highlights] after [color] and [query], grouped by source in order of
  /// first appearance.
  List<PracticeHighlightGroup> get groups {
    final needle = query.trim().toLowerCase();
    final bySource = <String, List<PracticeHighlightItem>>{};
    final titles = <String, String>{};
    for (final item in highlights) {
      if (color != null && item.highlight.color != color) continue;
      if (needle.isNotEmpty &&
          !item.highlight.text.toLowerCase().contains(needle) &&
          !(item.highlight.note?.toLowerCase().contains(needle) ?? false)) {
        continue;
      }
      final id = item.highlight.sourceId;
      bySource.putIfAbsent(id, () => []).add(item);
      titles[id] = item.sourceTitle ?? '';
    }
    return [
      for (final entry in bySource.entries)
        PracticeHighlightGroup(title: titles[entry.key]!, items: entry.value),
    ];
  }

  PracticeHighlightsState copyWith({
    PracticeHighlightsStatus? status,
    List<PracticeHighlightItem>? highlights,
    String? query,
    Object? color = _absent,
  }) => PracticeHighlightsState(
    status: status ?? this.status,
    highlights: highlights ?? this.highlights,
    query: query ?? this.query,
    color: color == _absent ? this.color : color as HighlightColor?,
  );

  @override
  List<Object?> get props => [status, highlights, query, color];
}

const _absent = Object();

/// The highlights list: load, search, filter by colour.
class PracticeHighlightsCubit extends Cubit<PracticeHighlightsState> {
  PracticeHighlightsCubit({
    required HighlightRepository highlightRepository,
    required FsrsRepository fsrsRepository,
    required BookRepository bookRepository,
    ArticleRepository? articleRepository,
  }) : _highlightRepository = highlightRepository,
       _fsrsRepository = fsrsRepository,
       _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       super(const PracticeHighlightsState());

  final HighlightRepository _highlightRepository;
  final FsrsRepository _fsrsRepository;
  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    if (state.status == PracticeHighlightsStatus.initial) {
      emit(state.copyWith(status: PracticeHighlightsStatus.loading));
    }
    try {
      final (highlights, sources) = await (
        _highlightRepository.getHighlights(),
        PracticeSourceIndex.load(
          bookRepository: _bookRepository,
          articleRepository: _articleRepository,
        ),
      ).wait;
      final text = [
        for (final h in highlights)
          if (h.kind == HighlightKind.text) h,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final states = await _fsrsRepository.getReviewStates([
        for (final h in text) h.id,
      ]);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: PracticeHighlightsStatus.ready,
          highlights: [
            for (final h in text)
              PracticeHighlightItem(
                highlight: h,
                fsrs: states[h.id] ?? const FsrsCardData(),
                sourceTitle: sources.titleOf(h.sourceId),
              ),
          ],
        ),
      );
    } catch (e, st) {
      addError(e, st);
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: PracticeHighlightsStatus.failure));
    }
  }

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setColor(HighlightColor? color) => emit(state.copyWith(color: color));
}
