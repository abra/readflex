import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  test(
    'runs the performance audit harness',
    () async {
      const command = String.fromEnvironment(
        'PERF_AUDIT_COMMAND',
        defaultValue: 'all',
      );
      const scale = String.fromEnvironment(
        'PERF_AUDIT_SCALE',
        defaultValue: '20000',
      );

      await _runPerfAudit([command, '--scale', scale]);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _runPerfAudit(List<String> args) async {
  final command = args.isEmpty ? 'all' : args.first;
  final scale = _intArg(args, '--scale', fallback: 20000);

  switch (command) {
    case 'all':
      await _benchDatabaseIndexes(scale: scale);
    case 'db':
      await _benchDatabaseIndexes(scale: scale);
    default:
      stderr.writeln(
        'Usage: flutter test benchmarks/perf_audit_test.dart',
      );
      stderr.writeln('       --dart-define=PERF_AUDIT_COMMAND=[all|db]');
      stderr.writeln('       --dart-define=PERF_AUDIT_SCALE=<rows>');
      exitCode = 64;
  }
}

Future<void> _benchDatabaseIndexes({required int scale}) async {
  // Benchmarks live outside test/ so they do not run in the normal suite.
  // ignore: invalid_use_of_visible_for_testing_member
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    await db.customStatement('PRAGMA journal_mode = MEMORY');
    await db.customStatement('PRAGMA synchronous = OFF');

    await _insertLibraryRows(db, scale);
    await _insertReviewRows(db, scale);

    final currentBooks = await _measureSql(
      db,
      label: 'books_order_current',
      sql: '''
        SELECT id, title, author, cover_image_path, format, file_path,
               total_locations, current_location, current_cfi, reading_progress,
               added_at, last_opened_at, is_finished
        FROM books_table
        ORDER BY last_opened_at DESC, added_at DESC
        LIMIT 100
      ''',
      runs: 12,
    );
    final currentMastered = await _measureSql(
      db,
      label: 'review_mastered_current',
      sql: '''
        SELECT item_id, item_type, source_id, fsrs_state, stability, difficulty,
               retrievability, reps, lapses, last_review_at, next_review_at,
               scheduled_days, elapsed_days
        FROM review_items_table
        WHERE item_type = 'dictionary' AND fsrs_state = 'review'
        LIMIT 100
      ''',
      runs: 12,
    );

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS perf_idx_books_last_opened_added
      ON books_table (last_opened_at DESC, added_at DESC)
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS perf_idx_review_items_type_state
      ON review_items_table (item_type, fsrs_state)
    ''');

    final indexedBooks = await _measureSql(
      db,
      label: 'books_order_indexed',
      sql: currentBooks.sql,
      runs: 12,
    );
    final indexedMastered = await _measureSql(
      db,
      label: 'review_mastered_indexed',
      sql: currentMastered.sql,
      runs: 12,
    );

    _printJson({
      'suite': 'db-indexes',
      'rows': scale,
      'results': [
        currentBooks.toJson(),
        indexedBooks.toJson(),
        currentMastered.toJson(),
        indexedMastered.toJson(),
      ],
    });
  } finally {
    await db.close();
  }
}

Future<void> _insertLibraryRows(AppDatabase db, int count) async {
  await db.transaction(() async {
    for (var i = 0; i < count; i++) {
      final added = DateTime.utc(2026, 1, 1).add(Duration(minutes: i));
      final lastOpened = i.isEven ? added.add(const Duration(days: 1)) : null;
      await db.customStatement(
        '''
        INSERT INTO books_table
          (id, title, author, cover_image_path, format, file_path,
           total_locations, current_location, current_cfi, reading_progress,
           added_at, last_opened_at, is_finished)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'book_$i',
          'Book $i',
          'Author ${i % 100}',
          null,
          i % 11 == 0 ? 'cbz' : 'epub',
          'book.epub',
          0,
          0,
          null,
          (i % 100) / 100.0,
          added.toIso8601String(),
          lastOpened?.toIso8601String(),
          i % 17 == 0 ? 1 : 0,
        ],
      );
    }
  });
}

Future<void> _insertReviewRows(AppDatabase db, int count) async {
  await db.transaction(() async {
    for (var i = 0; i < count; i++) {
      await db.customStatement(
        '''
        INSERT INTO review_items_table
          (item_id, item_type, source_id, fsrs_state, stability, difficulty,
           retrievability, reps, lapses, last_review_at, next_review_at,
           scheduled_days, elapsed_days)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'review_$i',
          i % 3 == 0 ? 'dictionary' : (i % 3 == 1 ? 'highlight' : 'flashcard'),
          'source_${i % 200}',
          i % 5 == 0 ? 'review' : 'new',
          0.0,
          0.0,
          0.0,
          i % 9,
          0,
          null,
          i % 7 == 0 ? null : DateTime.utc(2026, 1, 1).toIso8601String(),
          0,
          0,
        ],
      );
    }
  });
}

Future<_SqlMeasure> _measureSql(
  AppDatabase db, {
  required String label,
  required String sql,
  required int runs,
}) async {
  final planRows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
  final plan = [
    for (final row in planRows)
      row.data.values.map((value) => '$value').join('|'),
  ];

  // Warm up drift/sqlite caches.
  await db.customSelect(sql).get();

  final samples = <int>[];
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    await db.customSelect(sql).get();
    sw.stop();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();

  return _SqlMeasure(
    label: label,
    sql: sql,
    minUs: samples.first,
    medianUs: samples[samples.length ~/ 2],
    maxUs: samples.last,
    plan: plan,
  );
}

int _intArg(List<String> args, String name, {required int fallback}) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return fallback;
  return int.tryParse(args[index + 1]) ?? fallback;
}

void _printJson(Map<String, Object?> value) {
  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(value));
}

class _SqlMeasure {
  const _SqlMeasure({
    required this.label,
    required this.sql,
    required this.minUs,
    required this.medianUs,
    required this.maxUs,
    required this.plan,
  });

  final String label;
  final String sql;
  final int minUs;
  final int medianUs;
  final int maxUs;
  final List<String> plan;

  Map<String, Object?> toJson() => {
    'label': label,
    'minUs': minUs,
    'medianUs': medianUs,
    'maxUs': maxUs,
    'queryPlan': plan,
  };
}
