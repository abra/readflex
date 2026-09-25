import 'dart:convert';
import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:local_storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:library_feature/src/library_bloc.dart';

import '../test/support/library_workload.dart';

void main() {
  test('measures SQLite article metadata versus full body loading', () async {
    // Benchmark tests live outside test/; never open the user's database.
    // ignore: invalid_use_of_visible_for_testing_member
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final directory = await Directory.systemTemp.createTemp(
      'library_benchmark_',
    );
    final repository = ArticleRepository(
      database: db,
      articlesDirectory: directory,
    );
    addTearDown(() async {
      repository.dispose();
      await db.close();
      await directory.delete(recursive: true);
    });
    const count = 1000;
    final body = 'article content ' * 1024;
    await db.batch(
      (batch) => batch.insertAll(db.articlesTable, [
        for (var i = 0; i < count; i++)
          ArticlesTableCompanion.insert(
            id: '$i',
            title: 'Article $i',
            url: 'https://example.com/$i',
            contentPath: 'article.json',
            addedAt: '2026-09-25T00:00:00.000Z',
            plainText: Value(body),
          ),
      ]),
    );
    final metadataUs = <int>[];
    final fullUs = <int>[];
    for (var run = 0; run < 6; run++) {
      final timer = Stopwatch()..start();
      final metadata = await repository.getLibrarySources();
      timer.stop();
      if (run > 0) metadataUs.add(timer.elapsedMicroseconds);
      expect(metadata.length, count);
      timer.reset();
      timer.start();
      final full = await repository.getArticles();
      timer.stop();
      if (run > 0) fullUs.add(timer.elapsedMicroseconds);
      expect(full.map(LibrarySource.fromArticle), metadata);
    }
    metadataUs.sort();
    fullUs.sort();
    final report = {
      'mode': 'flutter-test JIT, SQLite in memory, not device frames',
      'articles': count,
      'bodyCharacters': body.length * count,
      'metadataMedianUs': metadataUs[metadataUs.length ~/ 2],
      'fullMedianUs': fullUs[fullUs.length ~/ 2],
      'metadataSamplesUs': metadataUs,
      'fullSamplesUs': fullUs,
    };
    final output = File('.local/performance/library-sqlite.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    // ignore: avoid_print
    print(jsonEncode(report));
  });

  test(
    'measures library derivation and cached reads by collection size',
    () async {
      final measurements = <Map<String, Object>>[];
      for (final count in [1000, 5000, 20000]) {
        final books = libraryWorkload(count);
        final samples = <int>[];
        var cachedReadsUs = 0;
        for (var run = 0; run < 6; run++) {
          final timer = Stopwatch()..start();
          final state = LibraryState(
            sources: books.map(LibrarySource.fromBook).toList(),
          );
          expect(state.visibleItems, hasLength(count));
          final search = state.copyWith(searchQuery: 'Author 23');
          expect(search.visibleItems, hasLength(count ~/ 100));
          timer.stop();
          if (run > 0) samples.add(timer.elapsedMicroseconds);
          final visible = state.visibleItems;
          timer.reset();
          timer.start();
          for (var read = 0; read < 10000; read++) {
            expect(identical(state.visibleItems, visible), isTrue);
          }
          timer.stop();
          cachedReadsUs = timer.elapsedMicroseconds;
        }
        samples.sort();
        measurements.add({
          'sources': count,
          'medianDeriveAndFilterUs': samples[samples.length ~/ 2],
          'samplesUs': samples,
          'cached10000ReadsUs': cachedReadsUs,
        });
      }
      final report = {
        'suite': 'library-derivation',
        'runtime': Platform.version,
        'mode':
            'flutter-test JIT, in-memory models, not SQLite or device frames',
        'measurements': measurements,
      };
      final output = File('.local/performance/library.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      // ignore: avoid_print
      print(jsonEncode(report));
    },
  );
}
