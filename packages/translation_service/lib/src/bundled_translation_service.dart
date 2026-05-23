import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'pronunciation/pronunciation.dart';
import 'translation_service.dart';

/// Production [TranslationService] backed by bundled SQLite dictionaries.
/// Exact word/phrase translations are served from bundled pair packs when
/// installed; unsupported pairs and missing rows still fall back to the
/// development echo so the surrounding UI path remains observable.
///
/// On first use each language's bundled `.db` file is copied once from the
/// asset bundle to the app documents directory. Subsequent lookups reuse a
/// lazily-opened read-only [Database] handle per language. Missing languages
/// produce an empty result instead of throwing — "dictionary not installed"
/// looks the same as "word not found" to callers.
///
/// Threading: [sqflite] executes queries on a background isolate, so the
/// service is safe to call from UI isolate code.
class BundledTranslationService implements TranslationService {
  BundledTranslationService({
    DirectoryProvider? directoryProvider,
    AssetLoader? assetLoader,
    DatabaseOpener? databaseOpener,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _assetLoader = assetLoader ?? rootBundle.load,
       _databaseOpener = databaseOpener ?? _defaultOpen;

  /// Languages whose `.db` ships inside `assets/phonetic/`. Each entry must
  /// match a file declared in pubspec.yaml.
  static const bundledLanguages = {'en'};

  /// Rootbundle prefix Flutter applies to assets declared inside a package's
  /// pubspec at build time.
  static const _phoneticAssetPrefix =
      'packages/translation_service/assets/phonetic';
  static const _translationAssetPrefix =
      'packages/translation_service/assets/translation';

  /// Subdirectories under app documents where bundled SQLite files are copied.
  static const _phoneticStorageSubdir = 'phonetic';
  static const _translationStorageSubdir = 'translation';

  final DirectoryProvider _directoryProvider;
  final AssetLoader _assetLoader;
  final DatabaseOpener _databaseOpener;
  final Map<String, Database> _handles = {};
  final Map<String, Database> _translationHandles = {};
  final Set<String> _missingTranslationPairs = {};

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  }) async {
    final bundledResult = await _lookupTranslation(
      text: text,
      fromLang: fromLang,
      toLang: toLang,
    );
    if (bundledResult != null) return bundledResult;

    // TODO: wire ML Kit (offline neural translation) and, when available,
    // AI backend (remote, AI-enriched). Until then echo misses so unsupported
    // pairs remain visible during development instead of failing silently.
    return TranslationResult(
      originalText: text,
      translatedText: '[$toLang] $text',
      source: TranslationSource.platform,
    );
  }

  @override
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  }) async {
    final db = await _openLanguage(lang);
    if (db == null) return const [];

    final rows = await db.query(
      'pronunciation',
      columns: ['system', 'value', 'tags'],
      where: 'word = ? AND lang = ?',
      whereArgs: [word.toLowerCase(), lang],
    );
    return rows.map(_rowToDomain).toList();
  }

  @override
  Future<void> dispose() async {
    for (final db in _handles.values) {
      await db.close();
    }
    for (final db in _translationHandles.values) {
      await db.close();
    }
    _handles.clear();
    _translationHandles.clear();
  }

  Future<TranslationResult?> _lookupTranslation({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    final sourceLanguageCode = fromLang.toLowerCase();
    final targetLanguageCode = toLang.toLowerCase();
    final normalizedText = _normalize(text);
    if (normalizedText.isEmpty) return null;

    final db = await _openTranslationPair(
      sourceLanguageCode,
      targetLanguageCode,
    );
    if (db == null) return null;

    final rows = await db.rawQuery(
      '''
      SELECT
        t.translated_text,
        t.sense,
        t.examples_json
      FROM entries e
      JOIN translations t ON t.entry_id = e.id
      WHERE e.source_language_code = ?
        AND e.normalized_source_text = ?
        AND t.target_language_code = ?
      ORDER BY
        CASE t.quality_status WHEN 'native' THEN 0 ELSE 1 END,
        CASE
          WHEN t.source = 'kaikki_native' THEN 0
          WHEN t.source = 'deepseek_translate' THEN 1
          WHEN t.source = 'reverse_kaikki_native' THEN 2
          ELSE 3
        END,
        CASE
          WHEN t.metadata_json LIKE '%"reversed":true%'
            THEN LENGTH(t.translated_text)
          ELSE t.id
        END,
        t.confidence DESC,
        t.id ASC
      LIMIT 3
      ''',
      [sourceLanguageCode, normalizedText, targetLanguageCode],
    );
    if (rows.isEmpty) return null;

    final translations = <String>[];
    for (final row in rows) {
      final value = row['translated_text'];
      if (value is! String) continue;
      final translatedText = _stripCombiningMarks(value).trim();
      if (translatedText.isNotEmpty && !translations.contains(translatedText)) {
        translations.add(translatedText);
      }
    }
    if (translations.isEmpty) {
      return null;
    }

    return TranslationResult(
      originalText: text,
      translatedText: translations.join(', '),
      source: TranslationSource.platform,
      context: rows.first['sense'] as String?,
      usageExamples: _decodeStringList(rows.first['examples_json']),
    );
  }

  Future<Database?> _openLanguage(String lang) async {
    final cached = _handles[lang];
    if (cached != null) return cached;
    if (!bundledLanguages.contains(lang)) return null;

    final path = await _ensureExtracted(
      bundleKey: '$_phoneticAssetPrefix/$lang.db',
      storageSubdir: _phoneticStorageSubdir,
      targetFileName: '$lang.db',
    );
    if (path == null) return null;

    final db = await _databaseOpener(path);
    _handles[lang] = db;
    return db;
  }

  Future<Database?> _openTranslationPair(
    String sourceLanguageCode,
    String targetLanguageCode,
  ) async {
    final pair = '${sourceLanguageCode}_$targetLanguageCode';
    final cached = _translationHandles[pair];
    if (cached != null) return cached;
    if (_missingTranslationPairs.contains(pair)) return null;

    final path = await _ensureExtracted(
      bundleKey: '$_translationAssetPrefix/$pair.sqlite',
      storageSubdir: _translationStorageSubdir,
      targetFileName: '$pair.sqlite',
    );
    if (path == null) {
      _missingTranslationPairs.add(pair);
      return null;
    }

    final db = await _databaseOpener(path);
    _translationHandles[pair] = db;
    return db;
  }

  /// Copies a bundled SQLite asset to app documents on first access. Returns
  /// the on-disk path, or `null` if the declared asset could not be loaded.
  Future<String?> _ensureExtracted({
    required String bundleKey,
    required String storageSubdir,
    required String targetFileName,
  }) async {
    final baseDir = await _directoryProvider();
    final targetDir = Directory(p.join(baseDir.path, storageSubdir));
    await targetDir.create(recursive: true);
    final targetPath = p.join(targetDir.path, targetFileName);
    final targetFile = File(targetPath);

    if (await targetFile.exists()) return targetPath;

    try {
      final data = await _assetLoader(bundleKey);
      await targetFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  static Pronunciation _rowToDomain(Map<String, Object?> row) {
    final tagsJson = row['tags'] as String?;
    List<String>? tags;
    if (tagsJson != null) {
      try {
        tags = (jsonDecode(tagsJson) as List).cast<String>();
      } catch (_) {
        tags = null;
      }
    }
    return Pronunciation(
      system: row['system']! as String,
      value: row['value']! as String,
      tags: tags,
    );
  }

  static List<String> _decodeStringList(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String _normalize(String value) {
    return _stripCombiningMarks(value).toLowerCase().trim();
  }

  static String _stripCombiningMarks(String value) =>
      value.replaceAll(RegExp(r'[\u0300-\u036f]'), '');

  static Future<Database> _defaultOpen(String path) =>
      openDatabase(path, readOnly: true);
}

/// Injection points for platform plumbing — kept narrow so tests can swap
/// them without depending on the full sqflite / rootBundle / path_provider
/// surface.
typedef DirectoryProvider = Future<Directory> Function();
typedef AssetLoader = Future<ByteData> Function(String key);
typedef DatabaseOpener = Future<Database> Function(String path);
