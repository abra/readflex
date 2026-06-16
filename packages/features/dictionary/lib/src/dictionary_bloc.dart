import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'dictionary_event.dart';
part 'dictionary_state.dart';

/// Backs the Dictionary tab ([DictionaryScreen]).
///
/// Loads saved [DictionaryEntry]s from [DictionaryRepository] on
/// [DictionaryLoadRequested] together with the set of mastered ids from
/// [FsrsRepository] for the "Mastered" badge. Handles debounced search
/// ([DictionarySearchChanged]) and entry removal
/// ([DictionaryEntryDeleted]). The repository owns entry + FSRS cleanup so
/// deletion stays transactional below the BLoC layer.
class DictionaryBloc extends Bloc<DictionaryEvent, DictionaryState> {
  DictionaryBloc({
    required DictionaryRepository dictionaryRepository,
    required FsrsRepository fsrsRepository,
    BookRepository? bookRepository,
    ArticleRepository? articleRepository,
  }) : _repository = dictionaryRepository,
       _fsrsRepository = fsrsRepository,
       _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       super(DictionaryState()) {
    on<DictionaryLoadRequested>(_onLoadRequested);
    on<DictionarySearchChanged>(
      _onSearchChanged,
      transformer: _debounce(_searchDelay),
    );
    on<DictionaryFilterChanged>(_onFilterChanged);
    on<DictionaryEntryAdded>(_onEntryAdded);
    on<DictionaryEntryDeleted>(_onEntryDeleted);
    on<DictionaryEntriesDeleted>(_onEntriesDeleted);
  }

  final DictionaryRepository _repository;
  final FsrsRepository _fsrsRepository;
  final BookRepository? _bookRepository;
  final ArticleRepository? _articleRepository;

  static const _searchDelay = Duration(milliseconds: 300);

  static EventTransformer<E> _debounce<E>(Duration duration) {
    return (events, mapper) => events.debounce(duration).asyncExpand(mapper);
  }

  Future<void> _onLoadRequested(
    DictionaryLoadRequested event,
    Emitter<DictionaryState> emit,
  ) async {
    emit(state.copyWith(status: DictionaryStatus.loading));
    await _loadEntries(emit);
  }

  void _onSearchChanged(
    DictionarySearchChanged event,
    Emitter<DictionaryState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterChanged(
    DictionaryFilterChanged event,
    Emitter<DictionaryState> emit,
  ) {
    if (state.filter == event.filter) return;
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _onEntryAdded(
    DictionaryEntryAdded event,
    Emitter<DictionaryState> emit,
  ) async {
    try {
      await _repository.addEntry(
        word: event.word,
        translation: event.translation,
        pronunciation: event.pronunciation,
        partOfSpeech: event.partOfSpeech,
      );
      await _loadEntries(emit);
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: DictionaryStatus.failure));
    }
  }

  Future<void> _onEntryDeleted(
    DictionaryEntryDeleted event,
    Emitter<DictionaryState> emit,
  ) async {
    final deletion = _deletionDescriptorFor({event.entryId});
    try {
      await _repository.deleteEntry(event.entryId);
      await _loadEntries(emit, deletion: deletion);
    } catch (e, st) {
      addError(e, st);
      final effect = _deletionEffect(deletion, success: false);
      emit(
        state.copyWith(
          status: DictionaryStatus.success,
          deletionVersion: effect.version,
          deletionEffect: effect,
        ),
      );
    }
  }

  Future<void> _onEntriesDeleted(
    DictionaryEntriesDeleted event,
    Emitter<DictionaryState> emit,
  ) async {
    final deletion = _deletionDescriptorFor(event.entryIds);
    // Continue the loop on per-id failure so a single broken row
    // doesn't abandon the rest of the selection in a partially-deleted
    // limbo with no toast feedback to the user.
    var anyFailed = false;
    for (final id in event.entryIds) {
      try {
        await _repository.deleteEntry(id);
      } catch (e, st) {
        anyFailed = true;
        addError(e, st);
      }
    }
    if (anyFailed) {
      try {
        final entries = await _repository.getEntries();
        final masteredIds = await _fsrsRepository.getMasteredItemIds(
          type: ReviewableType.dictionary,
        );
        final sourceTitlesById = await _sourceTitlesFor(entries);
        final effect = _deletionEffect(deletion, success: false);
        emit(
          state.copyWith(
            status: DictionaryStatus.success,
            entries: entries,
            masteredIds: masteredIds,
            sourceTitlesById: sourceTitlesById,
            deletionVersion: effect.version,
            deletionEffect: effect,
          ),
        );
      } catch (e, st) {
        addError(e, st);
        final effect = _deletionEffect(deletion, success: false);
        emit(
          state.copyWith(
            status: DictionaryStatus.success,
            deletionVersion: effect.version,
            deletionEffect: effect,
          ),
        );
      }
      return;
    }
    await _loadEntries(emit, deletion: deletion);
  }

  /// Pulls entries + mastered ids and emits success/failure. Pass [deletion]
  /// when this is the post-delete refresh so the screen can show the correct
  /// toast without tracking a local queue.
  Future<void> _loadEntries(
    Emitter<DictionaryState> emit, {
    _DictionaryDeletionDescriptor? deletion,
  }) async {
    try {
      final entries = await _repository.getEntries();
      final masteredIds = await _fsrsRepository.getMasteredItemIds(
        type: ReviewableType.dictionary,
      );
      final sourceTitlesById = await _sourceTitlesFor(entries);
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: true);
      emit(
        state.copyWith(
          status: DictionaryStatus.success,
          entries: entries,
          masteredIds: masteredIds,
          sourceTitlesById: sourceTitlesById,
          deletionVersion: effect?.version,
          deletionEffect: effect,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      final effect = deletion == null
          ? null
          : _deletionEffect(deletion, success: false);
      final status = deletion == null
          ? DictionaryStatus.failure
          : DictionaryStatus.success;
      emit(
        state.copyWith(
          status: status,
          deletionVersion: effect?.version,
          deletionEffect: effect,
        ),
      );
    }
  }

  Future<Map<String, String>> _sourceTitlesFor(
    List<DictionaryEntry> entries,
  ) async {
    final sourceTypesById = <String, SourceType?>{};
    for (final entry in entries) {
      final sourceId = entry.sourceId;
      if (sourceId == null || sourceId.isEmpty) continue;
      sourceTypesById[sourceId] = entry.sourceType;
    }
    if (sourceTypesById.isEmpty) return const {};

    final titles = <String, String>{};
    for (final source in sourceTypesById.entries) {
      try {
        final title = await _sourceTitleFor(source.key, source.value);
        if (title != null && title.trim().isNotEmpty) {
          titles[source.key] = title.trim();
        }
      } catch (e, st) {
        addError(e, st);
      }
    }
    return titles;
  }

  Future<String?> _sourceTitleFor(String sourceId, SourceType? type) async {
    return switch (type) {
      SourceType.book => _bookTitleFor(sourceId),
      SourceType.article => _articleTitleFor(sourceId),
      null => await _bookTitleFor(sourceId) ?? await _articleTitleFor(sourceId),
    };
  }

  Future<String?> _bookTitleFor(String sourceId) async {
    final repository = _bookRepository;
    if (repository == null) return null;
    return (await repository.getBookById(sourceId))?.title;
  }

  Future<String?> _articleTitleFor(String sourceId) async {
    final repository = _articleRepository;
    if (repository == null) return null;
    return (await repository.getArticleById(sourceId))?.title;
  }

  _DictionaryDeletionDescriptor _deletionDescriptorFor(Iterable<String> ids) {
    final idList = ids.toList(growable: false);
    return _DictionaryDeletionDescriptor(
      count: idList.length,
      singleWord: idList.length == 1 ? _wordOf(idList.first) : null,
    );
  }

  DictionaryDeletionEffect _deletionEffect(
    _DictionaryDeletionDescriptor deletion, {
    required bool success,
  }) {
    final version = state.deletionVersion + 1;
    return DictionaryDeletionEffect(
      version: version,
      success: success,
      count: deletion.count,
      singleWord: deletion.singleWord,
    );
  }

  String? _wordOf(String id) {
    for (final entry in state.entries) {
      if (entry.id == id) return entry.word;
    }
    return null;
  }
}

/// Stable deletion metadata captured before the dictionary list refreshes.
///
/// The toast needs the old word/count even after the deleted row disappears
/// from [DictionaryState.entries].
class _DictionaryDeletionDescriptor {
  const _DictionaryDeletionDescriptor({
    required this.count,
    this.singleWord,
  });

  final int count;
  final String? singleWord;
}
