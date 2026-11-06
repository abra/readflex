import 'dart:async';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:practice/src/practice_words_cubit.dart';

import 'helpers/practice_harness.dart';

void main() {
  late PracticeHarness h;

  setUp(() async => h = await PracticeHarness.create());
  tearDown(() => h.dispose());

  PracticeWordsCubit cubit() => PracticeWordsCubit(
    dictionaryRepository: h.dictionary,
    fsrsRepository: h.fsrs,
    bookRepository: h.books,
    articleRepository: h.articles,
  );

  test('loads words newest first with source titles and anchors', () async {
    await h.addBook('b1', title: 'Dune');
    await h.addWord('old', addedAt: DateTime(2026, 1, 1));
    await h.addWord('new', sourceId: 'b1', addedAt: DateTime(2026, 2, 1));
    final c = cubit();
    addTearDown(c.close);

    await c.load();

    expect(c.state.status, PracticeWordsStatus.ready);
    expect(c.state.words.map((w) => w.entry.word), ['new', 'old']);
    expect(c.state.words.first.sourceTitle, 'Dune');
    expect(c.state.words.first.cfiRange, isNotNull);
    expect(c.state.words.last.sourceTitle, isNull);
    expect(c.state.words.first.isNew, isTrue);
  });

  test('search and filters narrow the visible words', () async {
    final mastered = await h.addWord('light', translation: 'свет');
    await h.addWord('dark', translation: 'тьма');
    await h.review(mastered.id, ReviewableType.dictionary, Rating.good);
    final c = cubit();
    addTearDown(c.close);
    await c.load();

    c.setQuery('све');
    expect(c.state.visible.map((w) => w.entry.word), ['light']);

    c.setQuery('');
    c.setFilter(PracticeWordsFilter.mastered);
    expect(c.state.visible.map((w) => w.entry.word), ['light']);

    c.setFilter(PracticeWordsFilter.learning);
    expect(c.state.visible.map((w) => w.entry.word), ['dark']);
  });

  test('remove drops the word and its review row', () async {
    final word = await h.addWord('gone');
    final c = cubit();
    addTearDown(c.close);
    await c.load();

    await c.remove(c.state.words.single);

    expect(c.state.words, isEmpty);
    expect(await h.dictionary.getEntryById(word.id), isNull);
    expect(await h.fsrs.getReviewState(word.id), isNull);
  });

  PracticeWordsCubit controlled(
    _CountingDictionary dictionary,
    _CountingFsrs fsrs,
  ) => PracticeWordsCubit(
    dictionaryRepository: dictionary,
    fsrsRepository: fsrs,
    bookRepository: h.books,
    articleRepository: h.articles,
  );

  test(
    'large vocabulary uses one batch anchor lookup and no per-word reads',
    () async {
      await h.addBook('book');
      for (var index = 0; index < 120; index++) {
        await h.addWord('word-$index', sourceId: 'book');
      }
      final dictionary = _CountingDictionary(h);
      final fsrs = _CountingFsrs(h);
      final c = controlled(dictionary, fsrs);
      addTearDown(c.close);
      await c.load();
      expect(c.state.words, hasLength(120));
      expect(dictionary.batchReads, 1);
      expect(dictionary.batchIds, hasLength(120));
      expect(dictionary.individualReads, 0);
      expect(fsrs.reads, 1);
      expect(c.state.words.every((word) => word.cfiRange != null), isTrue);
      await dictionary.dispose();
    },
  );

  for (final closeDuringFsrs in [false, true]) {
    test(
      'closing during ${closeDuringFsrs ? 'FSRS' : 'entries'} read stops subsequent lookups',
      () async {
        await h.addWord('word');
        final dictionary = _CountingDictionary(h);
        final fsrs = _CountingFsrs(h);
        final gate = Completer<void>();
        if (closeDuringFsrs) {
          fsrs.gate = gate;
        } else {
          dictionary.firstEntriesGate = gate;
        }
        final c = controlled(dictionary, fsrs);
        final loading = c.load();
        await (closeDuringFsrs
            ? fsrs.started.future
            : dictionary.started.future);
        await c.close();
        gate.complete();
        await loading;
        expect(dictionary.batchReads, 0);
        expect(dictionary.individualReads, 0);
        expect(fsrs.reads, closeDuringFsrs ? 1 : 0);
        await dictionary.dispose();
      },
    );
  }

  test(
    'superseded entry snapshot does not start more reads or overwrite the new list',
    () async {
      await h.addWord('old');
      final dictionary = _CountingDictionary(h)
        ..firstEntriesGate = Completer<void>();
      final fsrs = _CountingFsrs(h);
      final c = controlled(dictionary, fsrs);
      addTearDown(c.close);
      final oldLoad = c.load();
      await dictionary.started.future;
      await h.addWord('new');
      await c.load();
      dictionary.firstEntriesGate!.complete();
      await oldLoad;
      expect(c.state.words.map((word) => word.entry.word).toSet(), {
        'old',
        'new',
      });
      expect(dictionary.batchReads, 1);
      expect(fsrs.reads, 1);
      await dictionary.dispose();
    },
  );
}

class _CountingDictionary extends DictionaryRepository {
  _CountingDictionary(PracticeHarness harness)
    : super(database: harness.database);
  final started = Completer<void>();
  Completer<void>? firstEntriesGate;
  int entryReads = 0;
  int batchReads = 0;
  int individualReads = 0;
  List<String> batchIds = [];

  @override
  Future<List<DictionaryEntry>> getEntries() async {
    final call = ++entryReads;
    final entries = await super.getEntries();
    if (call == 1) {
      started.complete();
      await firstEntriesGate?.future;
    }
    return entries;
  }

  @override
  Future<Map<String, DictionaryAnchor>> getFirstAnchorsByEntries(
    Iterable<String> ids,
  ) {
    batchReads++;
    batchIds = ids.toList();
    return super.getFirstAnchorsByEntries(batchIds);
  }

  @override
  Future<List<DictionaryAnchor>> getAnchorsByEntry(String id) {
    individualReads++;
    return super.getAnchorsByEntry(id);
  }
}

class _CountingFsrs extends FsrsRepository {
  _CountingFsrs(PracticeHarness harness)
    : super(database: harness.database, clock: () => harness.now);
  final started = Completer<void>();
  Completer<void>? gate;
  int reads = 0;

  @override
  Future<Map<String, FsrsCardData>> getReviewStates(List<String> ids) async {
    reads++;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    return super.getReviewStates(ids);
  }
}
