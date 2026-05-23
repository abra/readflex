import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_service/translation_service.dart';

/// Builds a throw-away SQLite database matching the bundled phonetic schema.
Future<Uint8List> _buildPronunciationFixture() async {
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

/// Builds a throw-away SQLite database matching the bundled pair-pack schema.
Future<Uint8List> _buildTranslationFixture() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'translation_fixture_',
  );
  final dbPath = p.join(tempDir.path, 'fixture.sqlite');
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  await db.execute('''
    CREATE TABLE entries (
      id INTEGER PRIMARY KEY,
      source_text TEXT NOT NULL,
      normalized_source_text TEXT NOT NULL,
      source_language_code TEXT NOT NULL,
      UNIQUE (source_language_code, normalized_source_text)
    );
  ''');
  await db.execute('''
    CREATE TABLE translations (
      id INTEGER PRIMARY KEY,
      entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
      target_language_code TEXT NOT NULL,
      translated_text TEXT NOT NULL,
      normalized_translated_text TEXT NOT NULL,
      source TEXT NOT NULL,
      confidence REAL,
      quality_status TEXT NOT NULL,
      part_of_speech TEXT,
      sense TEXT,
      romanization TEXT,
      transcription TEXT,
      tags_json TEXT NOT NULL,
      examples_json TEXT NOT NULL,
      metadata_json TEXT NOT NULL,
      dedupe_key TEXT NOT NULL,
      UNIQUE (entry_id, target_language_code, source, dedupe_key)
    );
  ''');
  await db.insert('entries', {
    'id': 1,
    'source_text': 'hello',
    'normalized_source_text': 'hello',
    'source_language_code': 'en',
  });
  await db.insert('translations', {
    'entry_id': 1,
    'target_language_code': 'ru',
    'translated_text': 'приве́т',
    'normalized_translated_text': 'привет',
    'source': 'kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Hello there."]',
    'metadata_json': '{}',
    'dedupe_key': 'ru:привет',
  });
  await db.insert('translations', {
    'entry_id': 1,
    'target_language_code': 'ru',
    'translated_text': 'здра́вствуй',
    'normalized_translated_text': 'здравствуй',
    'source': 'kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Hello there."]',
    'metadata_json': '{}',
    'dedupe_key': 'ru:здравствуй',
  });
  await db.insert('entries', {
    'id': 2,
    'source_text': 'привет',
    'normalized_source_text': 'привет',
    'source_language_code': 'ru',
  });
  await db.insert('translations', {
    'entry_id': 2,
    'target_language_code': 'en',
    'translated_text': 'hello',
    'normalized_translated_text': 'hello',
    'source': 'reverse_kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Привет всем."]',
    'metadata_json': '{"reversed":true}',
    'dedupe_key': 'en:hello',
  });
  await db.insert('translations', {
    'entry_id': 2,
    'target_language_code': 'en',
    'translated_text': 'hi',
    'normalized_translated_text': 'hi',
    'source': 'reverse_kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Привет всем."]',
    'metadata_json': '{"reversed":true}',
    'dedupe_key': 'en:hi',
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
    late Uint8List pronunciationFixtureBytes;
    late Uint8List translationFixtureBytes;
    late Directory docsDir;

    setUpAll(() async {
      pronunciationFixtureBytes = await _buildPronunciationFixture();
      translationFixtureBytes = await _buildTranslationFixture();
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
      assetLoader: (key) async => ByteData.sublistView(
        key.contains('/translation/')
            ? translationFixtureBytes
            : pronunciationFixtureBytes,
      ),
      databaseOpener: (path) => databaseFactoryFfi.openDatabase(path),
    );

    group('translate', () {
      test('returns an exact bundled translation when installed', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final result = await service.translate(
          'Hello',
          fromLang: 'en',
          toLang: 'ru',
        );
        expect(result.originalText, 'Hello');
        expect(result.translatedText, 'привет, здравствуй');
        expect(result.source, TranslationSource.platform);
        expect(result.context, 'greeting');
        expect(result.usageExamples, ['Hello there.']);
      });

      test(
        'returns an exact bundled reverse translation when installed',
        () async {
          final service = buildSubject();
          addTearDown(service.dispose);

          final result = await service.translate(
            'Привет',
            fromLang: 'ru',
            toLang: 'en',
          );
          expect(result.originalText, 'Привет');
          expect(result.translatedText, 'hi, hello');
          expect(result.source, TranslationSource.platform);
        },
      );

      test('returns the stub echo when the pair or text is missing', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final missingText = await service.translate(
          'missing',
          fromLang: 'en',
          toLang: 'ru',
        );
        expect(missingText.translatedText, '[ru] missing');

        final missingPair = await service.translate(
          'hello',
          fromLang: 'en',
          toLang: 'it',
        );
        expect(missingPair.translatedText, '[it] hello');
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
              return ByteData.sublistView(pronunciationFixtureBytes);
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
