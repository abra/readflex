import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'pronunciation/pronunciation.dart';
import 'translation_service.dart';

/// Production [TranslationService] backed by bundled Wiktionary SQLite
/// dictionaries for pronunciation lookups. Translation of arbitrary text is
/// still a stub (echoes input) — ML Kit / AI backends slot in here later
/// without changing the contract callers depend on.
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
  static const _assetPrefix = 'packages/translation_service/assets/phonetic';

  /// Subdirectory under app documents where dictionaries are mirrored.
  static const _storageSubdir = 'phonetic';

  final DirectoryProvider _directoryProvider;
  final AssetLoader _assetLoader;
  final DatabaseOpener _databaseOpener;
  final Map<String, Database> _handles = {};

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  }) async {
    // TODO: wire ML Kit (offline neural translation) and, when available,
    // AI backend (remote, AI-enriched). Until then echo the input so the
    // surrounding UI path is observable during development.
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
    _handles.clear();
  }

  Future<Database?> _openLanguage(String lang) async {
    final cached = _handles[lang];
    if (cached != null) return cached;
    if (!bundledLanguages.contains(lang)) return null;

    final path = await _ensureExtracted(lang);
    if (path == null) return null;

    final db = await _databaseOpener(path);
    _handles[lang] = db;
    return db;
  }

  /// Copies the asset to app documents on first access. Returns the on-disk
  /// path, or `null` if the bundled asset couldn't be loaded (shouldn't
  /// happen for a declared language).
  Future<String?> _ensureExtracted(String lang) async {
    final baseDir = await _directoryProvider();
    final targetDir = Directory(p.join(baseDir.path, _storageSubdir));
    await targetDir.create(recursive: true);
    final targetPath = p.join(targetDir.path, '$lang.db');
    final targetFile = File(targetPath);

    if (await targetFile.exists()) return targetPath;

    final bundleKey = '$_assetPrefix/$lang.db';
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

  static Future<Database> _defaultOpen(String path) =>
      openDatabase(path, readOnly: true);
}

/// Injection points for platform plumbing — kept narrow so tests can swap
/// them without depending on the full sqflite / rootBundle / path_provider
/// surface.
typedef DirectoryProvider = Future<Directory> Function();
typedef AssetLoader = Future<ByteData> Function(String key);
typedef DatabaseOpener = Future<Database> Function(String path);
