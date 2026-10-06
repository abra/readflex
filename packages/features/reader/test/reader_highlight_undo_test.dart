import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  final book = Book(
    id: 'book',
    title: 'Book',
    filePath: '/book.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  );
  final text = Highlight(
    id: 'text',
    sourceId: book.id,
    sourceType: SourceType.book,
    text: 'A saved passage',
    note: 'A note',
    cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
    progress: .3,
    chapterTitle: 'Chapter',
    color: HighlightColor.green,
    createdAt: DateTime(2025, 3),
  );
  final image = Highlight(
    id: 'image',
    sourceId: book.id,
    sourceType: SourceType.book,
    text: 'Page highlight',
    kind: HighlightKind.imageArea,
    imageArea: const HighlightImageArea(
      pageIndex: 4,
      x: .1,
      y: .2,
      width: .3,
      height: .4,
    ),
    pageNumber: 5,
    color: HighlightColor.pink,
    createdAt: DateTime(2025, 2),
  );
  late FakeHighlightRepository repository;
  late ReaderBloc bloc;

  Future<ReaderState> send(
    ReaderEvent event,
    bool Function(ReaderState) matches,
  ) {
    final result = bloc.stream
        .firstWhere(matches)
        .timeout(const Duration(seconds: 3));
    bloc.add(event);
    return result;
  }

  setUp(() async {
    repository = FakeHighlightRepository()
      ..seedHighlights(book.id, [text, image]);
    bloc = ReaderBloc(
      bookRepository: FakeBookRepository()..seedBook(book),
      highlightRepository: repository,
      initialSource: book,
    );
    await send(
      ReaderSourceLoadRequested(sourceId: book.id),
      (s) => s.highlights.length == 2,
    );
  });
  tearDown(() => bloc.close());

  test('popup delete persists immediately and keeps an undo row', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEdits.removed.isNotEmpty,
    );
    expect(bloc.state.highlights, [image]);
    expect(repository.deletedHighlightIds, ['text']);
    expect(bloc.state.highlightEdits.removed, [text]);
    expect(bloc.state.highlightEdits.busyId, isNull);
    expect(
      bloc.state.highlightEffect?.operation,
      ReaderHighlightOperation.delete,
    );
    expect(bloc.state.highlightEffect?.success, isTrue);
  });

  test(
    'undo re-adds a text highlight with its fields and original date',
    () async {
      await send(
        const ReaderHighlightDeleteRequested(highlightId: 'text'),
        (s) => s.highlightEdits.removed.isNotEmpty,
      );
      await send(
        const ReaderHighlightRestored(highlightId: 'text'),
        (s) => s.highlights.length == 2,
      );
      final restored = bloc.state.highlights.firstWhere(
        (h) => h.id != image.id,
      );
      expect(restored.id, isNot('text'));
      expect(restored.text, text.text);
      expect(restored.note, text.note);
      expect(restored.cfiRange, text.cfiRange);
      expect(restored.progress, text.progress);
      expect(restored.chapterTitle, text.chapterTitle);
      expect(restored.color, text.color);
      expect(repository.updatedHighlights.single.createdAt, text.createdAt);
      expect(bloc.state.highlightEdits, const ReaderHighlightEdits());
      // Undo is not a user-visible mutation; no new toast effect.
      expect(
        bloc.state.highlightEffect?.operation,
        ReaderHighlightOperation.delete,
      );
    },
  );

  test('undo re-adds an image area with its normalized rectangle', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'image'),
      (s) => s.highlightEdits.removed.isNotEmpty,
    );
    await send(
      const ReaderHighlightRestored(highlightId: 'image'),
      (s) => s.highlights.length == 2,
    );
    final restored = repository.imageAreaHighlights.single;
    expect(restored.imageArea, image.imageArea);
    expect(restored.color, image.color);
    expect(bloc.state.highlights.map((h) => h.id), contains(restored.id));
    expect(bloc.state.highlightEdits.removed, isEmpty);
  });

  test('restore marks its own row busy, then clears it', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEdits.removed.isNotEmpty,
    );
    final gate = Completer<void>();
    repository.addGate = gate.future;
    await send(
      const ReaderHighlightRestored(highlightId: 'text'),
      (s) => s.highlightEdits.busyId == 'text',
    );
    expect(bloc.state.highlightEdits.removed, [text]);
    final done = bloc.stream.firstWhere((s) => s.highlightEdits.busyId == null);
    gate.complete();
    await done.timeout(const Duration(seconds: 3));
    expect(bloc.state.highlightEdits.removed, isEmpty);
  });

  test('restore failure keeps the undo row and can be retried', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEdits.removed.isNotEmpty,
    );
    repository.shouldThrow = true;
    await send(
      const ReaderHighlightRestored(highlightId: 'text'),
      (s) => s.highlightEdits.failedId == 'text',
    );
    expect(bloc.state.highlightEdits.removed, [text]);
    expect(bloc.state.highlightEdits.busyId, isNull);
    repository.shouldThrow = false;
    await send(
      const ReaderHighlightRestored(highlightId: 'text'),
      (s) => s.highlights.length == 2,
    );
    expect(bloc.state.highlightEdits.failedId, isNull);
    expect(bloc.state.highlightEdits.removed, isEmpty);
  });

  test('delete failure leaves no undo row', () async {
    repository.shouldThrow = true;
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEffect?.success == false,
    );
    expect(bloc.state.highlights, [text, image]);
    expect(bloc.state.highlightEdits.removed, isEmpty);
  });

  test('closing Contents purges undo rows but not the deletion', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEdits.removed.isNotEmpty,
    );
    await send(
      const ReaderHighlightUndoDismissed(),
      (s) => s.highlightEdits.removed.isEmpty,
    );
    expect(bloc.state.highlights, [image]);
    expect(repository.highlightsBySourceId[book.id], [image]);
  });

  test('dismissal queued behind a delete still purges after it', () async {
    final purged = bloc.stream.firstWhere(
      (s) => s.highlights.length == 1 && s.highlightEdits.removed.isEmpty,
    );
    bloc
      ..add(const ReaderHighlightDeleteRequested(highlightId: 'text'))
      ..add(const ReaderHighlightUndoDismissed());
    await purged.timeout(const Duration(seconds: 3));
    expect(repository.deletedHighlightIds, ['text']);
  });

  test('multiple deletions undo independently', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEdits.removed.length == 1,
    );
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'image'),
      (s) => s.highlightEdits.removed.length == 2,
    );
    expect(bloc.state.highlights, isEmpty);
    await send(
      const ReaderHighlightRestored(highlightId: 'image'),
      (s) => s.highlights.length == 1,
    );
    expect(bloc.state.highlightEdits.removed, [text]);
    await send(
      const ReaderHighlightRestored(highlightId: 'text'),
      (s) => s.highlights.length == 2,
    );
    expect(bloc.state.highlightEdits.removed, isEmpty);
  });

  test('unknown ids are ignored by restore', () async {
    bloc.add(const ReaderHighlightRestored(highlightId: 'missing'));
    await pumpEventQueue();
    expect(repository.addedHighlights, isEmpty);
    expect(bloc.state.highlightEdits, const ReaderHighlightEdits());
  });

  test('reopening another source drops pending undo rows', () async {
    await send(
      const ReaderHighlightDeleteRequested(highlightId: 'text'),
      (s) => s.highlightEdits.removed.isNotEmpty,
    );
    final other = Book(
      id: 'other',
      title: 'Other',
      filePath: '/other.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
    );
    final books = FakeBookRepository()..seedBook(other);
    final otherBloc = ReaderBloc(
      bookRepository: books,
      highlightRepository: repository,
      initialSource: book,
    );
    addTearDown(otherBloc.close);
    final loaded = otherBloc.stream
        .firstWhere((s) => s.sourceId == other.id)
        .timeout(const Duration(seconds: 3));
    otherBloc.add(ReaderSourceLoadRequested(sourceId: other.id));
    await loaded;
    expect(otherBloc.state.highlightEdits, const ReaderHighlightEdits());
  });
}
