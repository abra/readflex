import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:monitoring/monitoring.dart';
import 'package:vellum/testing.dart';
import 'package:vellum/vellum.dart' show ImageDimensions, probeImageDimensions;

const pdfFixtures = '../../vellum/test/fixtures/pdf';

void main() {
  late Directory tempDir;
  late _RecordingBookRepository books;
  late _CollectingLogObserver logs;
  late Logger logger;

  setUpAll(preparePdfEngineForTests);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('book_import_');
    books = _RecordingBookRepository();
    logs = _CollectingLogObserver();
    logger = Logger(observers: [logs]);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<File> writeComic(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  test(
    'imports a comic through the native engine, without a WebView',
    () async {
      final source = await writeComic(
        'Saga v01.cbz',
        buildComicArchive([
          (name: '002.png', width: 300, height: 450),
          (name: '001.png', width: 1200, height: 1800),
        ]),
      );
      final progress = <double>[];

      final book = await importBookFile(
        sourceFile: source,
        bookRepository: books,
        logger: logger,
        onProgress: progress.add,
      );

      expect(book, isNotNull);
      final added = books.added.single;
      expect(added.sourceFile.path, source.path);
      expect(added.title, 'Saga v01');
      expect(added.format, BookFormat.cbz);
      expect(added.author, isNull);
      expect(added.coverMimeType, 'image/jpeg');
      expect(
        probeImageDimensions(added.coverData!),
        const ImageDimensions(480, 720),
        reason: 'the first page in reading order, scaled to the library size',
      );
      expect(progress, [1.0], reason: 'addBook drives the progress bar');
      expect(logs.messages, isEmpty);
    },
  );

  test('imports a PDF through the native engine with its cover', () async {
    final source = await writeComic(
      'paper.pdf',
      await File('$pdfFixtures/text_outline.pdf').readAsBytes(),
    );

    final book = await importBookFile(
      sourceFile: source,
      bookRepository: books,
      logger: logger,
    );

    expect(book, isNotNull);
    final added = books.added.single;
    expect(added.title, 'Vellum Fixture', reason: 'the Info dictionary');
    expect(added.author, 'Fixture Author');
    expect(added.format, BookFormat.pdf);
    expect(added.coverMimeType, 'image/jpeg');
    expect(
      probeImageDimensions(added.coverData!),
      const ImageDimensions(480, 621),
    );
  });

  test('an encrypted PDF is refused with the engine\'s reason', () async {
    final source = await writeComic(
      'locked.pdf',
      await File('$pdfFixtures/locked.pdf').readAsBytes(),
    );
    await expectLater(
      importBookFile(
        sourceFile: source,
        bookRepository: books,
        logger: logger,
      ),
      throwsA(
        isA<BookImportException>().having(
          (e) => e.message,
          'message',
          contains('password'),
        ),
      ),
    );
    expect(books.added, isEmpty);
  });

  test('a file the engine rejects fails with the engine\'s reason', () async {
    final source = await writeComic('notes.cbz', 'not a zip'.codeUnits);

    await expectLater(
      importBookFile(
        sourceFile: source,
        bookRepository: books,
        logger: logger,
      ),
      throwsA(
        isA<BookImportException>().having(
          (e) => e.message,
          'message',
          isNotEmpty,
        ),
      ),
    );
    expect(books.added, isEmpty);
    expect(logs.messages.single.message, 'Book import failed');
  });

  test('imports an EPUB through the native engine', () async {
    final fixture = Directory('../../vellum/test/fixtures/epub/epub3');
    final zip = ZipBuilder();
    for (final entity in fixture.listSync(recursive: true)) {
      if (entity is File) {
        final path = entity.path.substring(fixture.path.length + 1);
        final bytes = path == 'OEBPS/images/cover.png'
            ? encodeSolidPng(600, 900)
            : entity.readAsBytesSync();
        zip.add(path, bytes, deflate: path != 'mimetype');
      }
    }
    final source = await writeComic('novel.epub', zip.build());

    final book = await importBookFile(
      sourceFile: source,
      bookRepository: books,
      logger: logger,
    );

    expect(book, isNotNull);
    final added = books.added.single;
    expect(added.title, 'The Fixture Book');
    expect(added.author, 'Ada Lovelace, Grace Hopper');
    expect(added.format, BookFormat.epub);
    expect(added.coverMimeType, 'image/jpeg');
    expect(
      probeImageDimensions(added.coverData!),
      const ImageDimensions(480, 720),
    );
    expect(logs.messages, isEmpty);
  });

  test('imports an FB2 through the native engine', () async {
    final source = await writeComic(
      'story.fb2',
      await File('../../vellum/test/fixtures/fb2/rich.fb2').readAsBytes(),
    );

    final book = await importBookFile(
      sourceFile: source,
      bookRepository: books,
      logger: logger,
    );

    expect(book, isNotNull);
    final added = books.added.single;
    expect(added.title, 'Книга с пробелами');
    expect(added.author, 'Иван Петрович Сидоров, anon42, Only');
    expect(added.format, BookFormat.fb2);
    expect(added.coverData, isNull, reason: 'the fixture cover is a stub');
  });

  test('imports MOBI and AZW3 through the native engine', () async {
    for (final (name, format) in [
      ('six.mobi', BookFormat.mobi),
      ('eight.azw3', BookFormat.azw3),
    ]) {
      books = _RecordingBookRepository();
      final source = await writeComic(
        name,
        await File('../../vellum/test/fixtures/mobi/$name').readAsBytes(),
      );

      final book = await importBookFile(
        sourceFile: source,
        bookRepository: books,
        logger: logger,
      );

      expect(book, isNotNull, reason: name);
      final added = books.added.single;
      expect(added.format, format);
      expect(
        added.title,
        format == BookFormat.mobi ? 'Built MOBI <Updated>' : 'Built KF8',
      );
      expect(
        added.author,
        format == BookFormat.mobi ? 'Ada & Grace, Alan' : 'Someone',
      );
    }
  });

  test('a file with an unknown extension is read as an EPUB', () async {
    final source = await writeComic('notes.txt', utf8.encode('plain text'));

    await expectLater(
      importBookFile(
        sourceFile: source,
        bookRepository: books,
        logger: logger,
      ),
      throwsA(
        isA<BookImportException>().having(
          (e) => e.message,
          'message',
          'Not a ZIP archive',
        ),
      ),
    );
    expect(books.added, isEmpty);
  });

  test('a repository failure is logged and answered with null', () async {
    final source = await writeComic(
      'issue.cbz',
      buildComicArchive(portraitPages(2)),
    );
    books.failure = StorageException(cause: Exception('disk full'));

    final book = await importBookFile(
      sourceFile: source,
      bookRepository: books,
      logger: logger,
    );

    expect(book, isNull);
    expect(logs.messages.single.message, 'Book import failed');
    expect(logs.messages.single.error, books.failure);
  });
}

typedef _AddedBook = ({
  File sourceFile,
  String title,
  BookFormat format,
  String? author,
  Uint8List? coverData,
  String? coverMimeType,
});

class _RecordingBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final added = <_AddedBook>[];
  Object? failure;

  @override
  Future<Book> addBook({
    required File sourceFile,
    required String title,
    required BookFormat format,
    String? author,
    Uint8List? coverData,
    String? coverMimeType,
    void Function(double progress)? onProgress,
  }) async {
    if (failure case final failure?) throw failure;
    added.add((
      sourceFile: sourceFile,
      title: title,
      format: format,
      author: author,
      coverData: coverData,
      coverMimeType: coverMimeType,
    ));
    onProgress?.call(1);
    return Book(
      id: 'book-${added.length}',
      title: title,
      filePath: sourceFile.path,
      format: format,
      addedAt: DateTime(2026, 1, 1),
      author: author,
    );
  }
}

final class _CollectingLogObserver with LogObserver {
  final messages = <LogMessage>[];

  @override
  void onLog(LogMessage logMessage) {
    messages.add(logMessage);
  }
}
