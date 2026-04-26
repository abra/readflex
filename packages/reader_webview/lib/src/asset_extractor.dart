import 'dart:io';

import 'package:flutter/services.dart';
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;

/// Extracts reader WebView assets from Flutter's rootBundle to a directory
/// on the filesystem where the HTTP server can serve them.
///
/// Assets bundled in a Flutter package are only accessible via rootBundle —
/// dart:io HttpServer cannot read them. This utility copies them once to
/// a cache directory at app startup.
class AssetExtractor {
  AssetExtractor({required this.targetDirectory, this.logger});

  final Directory targetDirectory;

  /// Optional logger. When set, every asset that fails to load from the
  /// rootBundle is reported as a warning so a corrupted release bundle
  /// or missing asset doesn't silently degrade the reader to a blank
  /// screen.
  final Logger? logger;

  /// All asset paths relative to the package's `assets/` directory.
  /// The rootBundle key includes the `packages/reader_webview/` prefix.
  static const _assetPaths = [
    // foliate-js entry
    'assets/foliate-js/index.html',
    // foliate-js core
    'assets/foliate-js/src/book.js',
    'assets/foliate-js/src/view.js',
    'assets/foliate-js/src/epub.js',
    'assets/foliate-js/src/epubcfi.js',
    'assets/foliate-js/src/overlayer.js',
    'assets/foliate-js/src/footnotes.js',
    'assets/foliate-js/src/progress.js',
    'assets/foliate-js/src/text-walker.js',
    'assets/foliate-js/src/translator.js',
    'assets/foliate-js/src/paginator.js',
    'assets/foliate-js/src/tts.js',
    'assets/foliate-js/src/search.js',
    'assets/foliate-js/src/dict.js',
    'assets/foliate-js/src/fixed-layout.js',
    'assets/foliate-js/src/remote_file.js',
    'assets/foliate-js/src/readflex_gestures.js',
    // foliate-js format handlers
    'assets/foliate-js/src/pdf.js',
    'assets/foliate-js/src/fb2.js',
    'assets/foliate-js/src/mobi.js',
    'assets/foliate-js/src/comic-book.js',
    // foliate-js vendor
    'assets/foliate-js/src/vendor/zip.js',
    'assets/foliate-js/src/vendor/fflate.js',
    'assets/foliate-js/src/vendor/pdfjs/pdf.js',
    'assets/foliate-js/src/vendor/pdfjs/pdf.worker.js',
    // foliate-js legacy bundle
    'assets/foliate-js/dist/bundle.js',
  ];

  /// Reading-typography fonts copied from `component_library` so foliate-js
  /// can load them via `@font-face` over the local HTTP server. Flutter's
  /// own font registry is invisible to the WebView — without these on disk,
  /// `font-family: SourceSerif4 / Geist` falls back to the platform default
  /// (Times on iOS, Roboto on Android), making the reader font preset a
  /// no-op.
  static const _fontBundleKeys = [
    'packages/component_library/fonts/Geist-Variable.ttf',
    'packages/component_library/fonts/SourceSerif4-Variable.ttf',
    'packages/component_library/fonts/SourceSerif4-Italic-Variable.ttf',
  ];

  /// Extracts all reader assets to [targetDirectory].
  ///
  /// On unchanged [version], existing files are skipped. When [version]
  /// differs from the last extracted version, all files are re-written.
  /// Pass `force: true` to unconditionally re-extract.
  Future<void> extractAll({required String version, bool force = false}) async {
    final versionFile = File(p.join(targetDirectory.path, '.asset_version'));
    final shouldForce = force || !await _versionMatches(versionFile, version);

    for (final assetPath in _assetPaths) {
      await _extractOne(
        bundleKey: 'packages/reader_webview/$assetPath',
        relativeTargetPath: assetPath.replaceFirst('assets/', ''),
        force: shouldForce,
      );
    }

    for (final bundleKey in _fontBundleKeys) {
      await _extractOne(
        bundleKey: bundleKey,
        relativeTargetPath: p.join('fonts', p.basename(bundleKey)),
        force: shouldForce,
      );
    }

    if (shouldForce) {
      await versionFile.parent.create(recursive: true);
      await versionFile.writeAsString(version, flush: true);
    }
  }

  Future<void> _extractOne({
    required String bundleKey,
    required String relativeTargetPath,
    required bool force,
  }) async {
    final targetPath = p.join(targetDirectory.path, relativeTargetPath);
    final targetFile = File(targetPath);
    if (!force && await targetFile.exists()) return;

    await Directory(p.dirname(targetPath)).create(recursive: true);

    try {
      final data = await rootBundle.load(bundleKey);
      await targetFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    } catch (e, st) {
      // Continue extracting the rest — a single missing file is
      // recoverable for most foliate-js features (e.g. a vendor lib
      // for a format the user doesn't open). But we surface it so a
      // corrupt release bundle is visible in logs.
      logger?.warn(
        'AssetExtractor failed to load $bundleKey',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> _versionMatches(File versionFile, String version) async {
    if (!await versionFile.exists()) return false;
    try {
      return (await versionFile.readAsString()) == version;
    } catch (_) {
      return false;
    }
  }
}
