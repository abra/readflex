import 'dart:io';
import 'dart:typed_data';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase database;
  late Directory directory;
  late Directory booksDirectory;
  late File source;
  late Logger logger;
  late _RecordingObserver logs;
  late BookRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('book-import-progress-');
    booksDirectory = Directory(p.join(directory.path, 'books'));
    source = await File(p.join(directory.path, 'source.epub')).writeAsBytes(
      Uint8List.fromList(List.generate(256 * 1024, (index) => index % 251)),
    );
    logs = _RecordingObserver();
    logger = Logger(observers: [logs]);
    repository = BookRepository(
      database: database,
      booksDirectory: booksDirectory,
      logger: logger,
    );
  });

  tearDown(() async {
    await logger.destroy();
    await database.close();
    await directory.delete(recursive: true);
  });

  for (final phase in ['start', 'copy', 'finishing', 'completion']) {
    test(
      'a throwing $phase observer cannot invalidate a persisted import',
      () async {
        final observerError = StateError('Progress observer failed at $phase');
        final values = <double>[];
        var failed = false;
        var callsAfterFailure = 0;
        final book = await repository.addBook(
          sourceFile: source,
          title: 'Observed import',
          format: BookFormat.epub,
          onProgress: (value) {
            if (failed) callsAfterFailure++;
            values.add(value);
            final shouldFail = switch (phase) {
              'start' => value == 0,
              'copy' => value > 0 && value < .95,
              'finishing' => value == .98,
              _ => value == 1,
            };
            if (shouldFail) {
              failed = true;
              throw observerError;
            }
          },
        );

        expect(
          failed,
          isTrue,
          reason: 'The intended observer phase must execute',
        );
        expect(callsAfterFailure, 0, reason: 'A failed observer is disabled');
        expect(values.first, 0);
        expect(await repository.getBookById(book.id), book);
        expect((await repository.getBooks()).single, book);
        expect(
          await File(book.filePath).readAsBytes(),
          await source.readAsBytes(),
        );
        expect(await source.exists(), isTrue);
        final warning = logs.messages.single;
        expect(warning.level, LogLevel.warn);
        expect(warning.message, contains('progress observer failed'));
        expect(warning.error, same(observerError));
        expect(warning.stackTrace, isNotNull);
      },
    );
  }

  test('an observer failure cannot replace the real copy failure', () async {
    final missing = File(p.join(directory.path, 'missing.epub'));
    Object? failure;
    try {
      await repository.addBook(
        sourceFile: missing,
        title: 'Missing source',
        format: BookFormat.epub,
        onProgress: (_) => throw StateError('Observer failed before copy'),
      );
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<StorageException>());
    expect((failure! as StorageException).cause, isA<FileSystemException>());
    expect(await repository.getBooks(), isEmpty);
    expect(await booksDirectory.list().toList(), isEmpty);
    expect(logs.messages, hasLength(1));
  });

  test(
    'a database insert failure cleans files without announcing completion',
    () async {
      await database.customStatement('''
      CREATE TRIGGER refuse_book_import BEFORE INSERT ON books_table
      BEGIN
        SELECT RAISE(ABORT, 'Refused import in test');
      END
    ''');
      final values = <double>[];

      await expectLater(
        repository.addBook(
          sourceFile: source,
          title: 'Refused insert',
          format: BookFormat.epub,
          onProgress: values.add,
        ),
        throwsA(
          isA<StorageException>().having(
            (error) => error.cause.toString(),
            'original insert error',
            contains('Refused import in test'),
          ),
        ),
      );

      expect(values, contains(.98));
      expect(values, isNot(contains(1.0)));
      expect(await repository.getBooks(), isEmpty);
      expect(await booksDirectory.list().toList(), isEmpty);
      expect(await source.exists(), isTrue);
      expect(logs.messages, isEmpty);
    },
  );

  test(
    'progress diagnostics cannot invalidate the import when logging fails',
    () async {
      logger.addObserver(_ThrowingObserver());
      final book = await repository.addBook(
        sourceFile: source,
        title: 'Failed diagnostics',
        format: BookFormat.epub,
        onProgress: (value) {
          if (value == 1) throw StateError('Observer failed after commit');
        },
      );

      expect(await repository.getBookById(book.id), book);
      expect(
        await File(book.filePath).readAsBytes(),
        await source.readAsBytes(),
      );
      expect(logs.messages, hasLength(1));
    },
  );
}

final class _RecordingObserver with LogObserver {
  final messages = <LogMessage>[];

  @override
  void onLog(LogMessage message) => messages.add(message);
}

final class _ThrowingObserver with LogObserver {
  @override
  void onLog(LogMessage message) => throw StateError('Diagnostics unavailable');
}
