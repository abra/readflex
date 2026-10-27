import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
