import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:reader/src/reader_bloc.dart';

import '../packages/features/reader/test/helpers/fake_book_repository.dart';

void main() {
  test('a delayed color edit preserves an independently saved note', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _DelayedColorRepository(database: db);
    final highlight = await repository.addImageAreaHighlight(
      sourceId: 'book',
      sourceType: SourceType.book,
      pageIndex: 0,
      x: 0.1,
      y: 0.1,
      width: 0.2,
      height: 0.2,
      note: 'Original note',
    );
    final bloc = ReaderBloc(
      bookRepository: FakeBookRepository(),
      highlightRepository: repository,
      initialSource: Book(
        id: 'book',
        title: 'Book',
        filePath: '/book.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    );
    addTearDown(bloc.close);
    final loaded = bloc.stream.firstWhere(
      (state) => state.highlights.isNotEmpty,
    );
    bloc.add(const ReaderHighlightsRefreshed());
    await loaded;
    bloc.add(
      ReaderHighlightColorChangeRequested(
        highlightId: highlight.id,
        color: HighlightColor.blue,
      ),
    );
    await repository.started.future;
    // Another editor commits while the reader still holds its old snapshot.
    await HighlightRepository(database: db).updateHighlight(
      highlight.copyWith(note: 'New note'),
    );
    final saved = bloc.stream.firstWhere(
      (state) => state.highlights.single.color == HighlightColor.blue,
    );
    repository.release.complete();
    await saved;
    final stored = await repository.getHighlightById(highlight.id);
    expect(
      stored,
      highlight.copyWith(
        note: 'New note',
        color: HighlightColor.blue,
      ),
    );
  });
}

class _DelayedColorRepository extends HighlightRepository {
  _DelayedColorRepository({required super.database});
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> updateHighlightColor(String id, HighlightColor color) async {
    started.complete();
    await release.future;
    await super.updateHighlightColor(id, color);
  }
}
