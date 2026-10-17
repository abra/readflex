import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('readflex_connection_');
  });

  tearDown(() => directory.delete(recursive: true));

  test('the app database writes ahead with NORMAL sync', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase(
        File(p.join(directory.path, 'readflex.db')),
        setup: configureAppDatabaseConnection,
      ),
    );
    addTearDown(database.close);

    Future<Object?> pragma(String name) => database
        .customSelect('PRAGMA $name')
        .map((row) => row.data.values.single)
        .getSingle();

    expect(await pragma('journal_mode'), 'wal');
    // 1 is NORMAL; the SQLite default is FULL (2).
    expect(await pragma('synchronous'), 1);

    // Migrations and writes run in this mode.
    await database.customStatement(
      "INSERT INTO books_table (id, title, format, file_path, added_at) "
      "VALUES ('b', 'Book', 'epub', 'b.epub', '2026-01-01')",
    );
    expect((await database.booksDao.bookById('b'))?.title, 'Book');
  });
}
