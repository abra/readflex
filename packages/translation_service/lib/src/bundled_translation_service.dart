import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'on_device_translation_client.dart';
import 'pronunciation/pronunciation.dart';
import 'remote_translation_client.dart';
import 'translation_service.dart';

/// Production [TranslationService] with layered translation sources.
///
/// Exact word/phrase translations are served from bundled SQLite pair packs
/// when installed. Misses can then go to an optional online enricher
/// ([RemoteTranslationClient]) and/or a future on-device adapter
/// ([OnDeviceTranslationClient]). The final development echo remains opt-in
/// so unsupported pairs are visible during local development instead of
/// failing silently.
///
/// On first use each bundled `.db` file is copied once from the asset bundle
/// to the app documents directory. Subsequent lookups reuse lazily-opened
/// read-only [Database] handles. Missing assets return null instead of
/// throwing — "dictionary not installed" looks the same as "word not found"
/// to callers.
///
/// Threading: [sqflite] executes queries on a background isolate; remote and
/// optional adapters own their async work, so callers can invoke this
/// service from UI isolate code.
class BundledTranslationService implements TranslationService {
  BundledTranslationService({
    DirectoryProvider? directoryProvider,
    AssetLoader? assetLoader,
    DatabaseOpener? databaseOpener,
    OnDeviceTranslationClient? onDeviceTranslationClient,
    RemoteTranslationClient? remoteTranslationClient,
    bool preferRemoteTranslation = false,
    bool enableDevelopmentEchoFallback = true,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _assetLoader = assetLoader ?? rootBundle.load,
       _databaseOpener = databaseOpener ?? _defaultOpen,
       _onDeviceTranslationClient = onDeviceTranslationClient,
       _remoteTranslationClient = remoteTranslationClient,
       _preferRemoteTranslation = preferRemoteTranslation,
       _enableDevelopmentEchoFallback = enableDevelopmentEchoFallback;

  /// No phonetic SQLite databases ship in the app bundle.
  static const bundledLanguages = <String>{};

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
  final OnDeviceTranslationClient? _onDeviceTranslationClient;
  final RemoteTranslationClient? _remoteTranslationClient;
  final bool _preferRemoteTranslation;
  final bool _enableDevelopmentEchoFallback;
  final Map<String, Database> _handles = {};
  final Map<String, Database> _translationHandles = {};
  final Set<String> _missingTranslationPairs = {};

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    final bundledResult = await _lookupTranslation(
      text: text,
      fromLang: fromLang,
      toLang: toLang,
    );
    if (bundledResult != null) return bundledResult;

    if (_preferRemoteTranslation) {
      final remoteResult = await _lookupRemoteTranslation(
        text: text,
        fromLang: fromLang,
        toLang: toLang,
        contextText: contextText,
      );
      if (remoteResult != null) return remoteResult;
    }

    final onDeviceResult = await _lookupOnDeviceTranslation(
      text: text,
      fromLang: fromLang,
      toLang: toLang,
      contextText: contextText,
    );
    if (onDeviceResult != null) return onDeviceResult;

    if (!_preferRemoteTranslation) {
      final remoteResult = await _lookupRemoteTranslation(
        text: text,
        fromLang: fromLang,
        toLang: toLang,
        contextText: contextText,
      );
      if (remoteResult != null) return remoteResult;
    }

    if (_enableDevelopmentEchoFallback) {
      return TranslationResult(
        originalText: text,
        translatedText: '[$toLang] $text',
        source: TranslationSource.platform,
      );
    }

    throw const TranslationException('Translation is unavailable');
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
    await _onDeviceTranslationClient?.dispose();
    await _remoteTranslationClient?.dispose();
    _handles.clear();
    _translationHandles.clear();
  }

  Future<TranslationResult?> _lookupRemoteTranslation({
    required String text,
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    final client = _remoteTranslationClient;
    if (client == null) return null;
    try {
      return await client.translate(
        text,
        fromLang: fromLang,
        toLang: toLang,
        contextText: contextText,
      );
    } catch (_) {
      return null;
    }
  }

  Future<TranslationResult?> _lookupOnDeviceTranslation({
    required String text,
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    final client = _onDeviceTranslationClient;
    if (client == null) return null;
    try {
      final translatedText = await client.translate(
        text,
        fromLang: fromLang,
        toLang: toLang,
        contextText: contextText,
      );
      if (translatedText == null || translatedText.trim().isEmpty) {
        return null;
      }
      return TranslationResult(
        originalText: text,
        translatedText: translatedText.trim(),
        source: TranslationSource.platform,
      );
    } catch (_) {
      return null;
    }
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
