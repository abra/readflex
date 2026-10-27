import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/practice_highlights_cubit.dart';

import 'helpers/practice_harness.dart';

void main() {
  late PracticeHarness h;

  setUp(() async => h = await PracticeHarness.create());
  tearDown(() => h.dispose());

  PracticeHighlightsCubit cubit() => PracticeHighlightsCubit(
    highlightRepository: h.highlights,
    fsrsRepository: h.fsrs,
    bookRepository: h.books,
    articleRepository: h.articles,
  );

  test('groups text highlights by source, newest first', () async {
    await h.addBook('b1', title: 'Dune');
    await h.addBook('b2', title: 'Emma');
    await h.addHighlight('b1', 'First', color: HighlightColor.green);
    await h.addHighlight('b2', 'Second', note: 'a note');
    await h.highlights.addImageAreaHighlight(
      sourceId: 'b1',
      sourceType: SourceType.book,
      pageIndex: 1,
      x: 0,
      y: 0,
      width: 1,
      height: 1,
    );
    final c = cubit();
    addTearDown(c.close);

    await c.load();

    expect(c.state.highlights.length, 2);
    expect(c.state.groups.map((g) => g.title), ['Emma', 'Dune']);

    c.setColor(HighlightColor.green);
    expect(c.state.groups.single.title, 'Dune');

    c.setColor(null);
    c.setQuery('note');
    expect(c.state.groups.single.items.single.highlight.text, 'Second');
  });
}
