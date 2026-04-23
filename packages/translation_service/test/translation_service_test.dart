import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_service/translation_service.dart';

/// Builds a throw-away SQLite database matching the bundled `<lang>.db`
/// schema and seeds it with a few known entries. The file it returns is
/// what the fake `AssetLoader` below feeds back to the service — we never
/// touch the real 18 MB asset in unit tests.
Future<Uint8List> _buildFixture() async {
  final tempDir = await Directory.systemTemp.createTemp('phonetic_fixture_');
  final dbPath = p.join(tempDir.path, 'fixture.db');
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  await db.execute('''
    CREATE TABLE pronunciation (
      word TEXT NOT NULL,
      lang TEXT NOT NULL,
      system TEXT NOT NULL,
      value TEXT NOT NULL,
      tags TEXT,
      PRIMARY KEY (word, lang, system, value)
    );
  ''');
  await db.execute(
    'CREATE INDEX idx_word_lang ON pronunciation(word, lang);',
  );
  await db.insert('pronunciation', {
    'word': 'hello',
    'lang': 'en',
    'system': 'ipa',
    'value': '/həˈloʊ/',
    'tags': '["US"]',
  });
  await db.insert('pronunciation', {
    'word': 'hello',
    'lang': 'en',
    'system': 'ipa',
    'value': '/həˈləʊ/',
    'tags': '["Received-Pronunciation"]',
  });
  await db.insert('pronunciation', {
    'word': 'dictionary',
    'lang': 'en',
    'system': 'ipa',
    'value': '/ˈdɪkʃənəɹi/',
    'tags': null,
  });
  await db.close();

  final bytes = await File(dbPath).readAsBytes();
  await tempDir.delete(recursive: true);
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('NoopTranslationService', () {
    const service = NoopTranslationService();

    test('translate returns platform source with formatted text', () async {
      final result = await service.translate(
        'hello',
        fromLang: 'en',
        toLang: 'ru',
      );
      expect(result.originalText, 'hello');
      expect(result.translatedText, '[ru] hello');
      expect(result.source, TranslationSource.platform);
      expect(result.usageExamples, isEmpty);
    });

    test('lookupPronunciation returns an empty list', () async {
      final result = await service.lookupPronunciation(
        word: 'hello',
        lang: 'en',
      );
      expect(result, isEmpty);
    });
  });

  group('BundledTranslationService', () {
    late Uint8List fixtureBytes;
    late Directory docsDir;

    setUpAll(() async {
      fixtureBytes = await _buildFixture();
    });

    setUp(() async {
      docsDir = await Directory.systemTemp.createTemp('phonetic_docs_');
    });

    tearDown(() async {
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    });

    BundledTranslationService buildSubject() => BundledTranslationService(
      directoryProvider: () async => docsDir,
      assetLoader: (key) async => ByteData.sublistView(fixtureBytes),
      databaseOpener: (path) => databaseFactoryFfi.openDatabase(path),
    );

    group('translate', () {
      test('returns the stub echo for arbitrary text', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final result = await service.translate(
          'hello',
          fromLang: 'en',
          toLang: 'ru',
        );
        expect(result.originalText, 'hello');
        expect(result.translatedText, '[ru] hello');
        expect(result.source, TranslationSource.platform);
      });
    });

    group('lookupPronunciation', () {
      test('returns every variant for a known word', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final results = await service.lookupPronunciation(
          word: 'hello',
          lang: 'en',
        );

        expect(results, hasLength(2));
        expect(
          results.map((p) => p.value),
          containsAll(['/həˈloʊ/', '/həˈləʊ/']),
        );
        expect(
          results.firstWhere((p) => p.tags?.contains('US') ?? false).value,
          '/həˈloʊ/',
        );
      });

      test('lowercases the input before looking up', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final results = await service.lookupPronunciation(
          word: 'Hello',
          lang: 'en',
        );

        expect(results, hasLength(2));
      });

      test('parses tags when present and leaves tags null otherwise', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final results = await service.lookupPronunciation(
          word: 'dictionary',
          lang: 'en',
        );

        expect(results, hasLength(1));
        expect(results.single.tags, isNull);
      });

      test('returns an empty list for an unknown word', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final results = await service.lookupPronunciation(
          word: 'nonexistent',
          lang: 'en',
        );

        expect(results, isEmpty);
      });

      test('returns an empty list for a language not in the bundle', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final results = await service.lookupPronunciation(
          word: 'hello',
          lang: 'zz',
        );

        expect(results, isEmpty);
      });

      test(
        'extracts the asset once — subsequent lookups reuse the file',
        () async {
          var assetLoads = 0;
          final service = BundledTranslationService(
            directoryProvider: () async => docsDir,
            assetLoader: (key) async {
              assetLoads += 1;
              return ByteData.sublistView(fixtureBytes);
            },
            databaseOpener: (path) => databaseFactoryFfi.openDatabase(path),
          );
          addTearDown(service.dispose);

          await service.lookupPronunciation(word: 'hello', lang: 'en');
          await service.lookupPronunciation(word: 'dictionary', lang: 'en');

          expect(assetLoads, 1);
        },
      );
    });
  });
}
