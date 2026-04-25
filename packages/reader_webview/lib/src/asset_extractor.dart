import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Extracts reader WebView assets from Flutter's rootBundle to a directory
/// on the filesystem where the HTTP server can serve them.
///
/// Assets bundled in a Flutter package are only accessible via rootBundle —
/// dart:io HttpServer cannot read them. This utility copies them once to
/// a cache directory at app startup.
class AssetExtractor {
  AssetExtractor({required this.targetDirectory});

  final Directory targetDirectory;

  /// All asset paths relative to the package's `assets/` directory.
  /// The rootBundle key includes the `packages/reader_webview/` prefix.
  static const _assetPaths = [
    // Article reader
    'assets/article/reader.html',
    'assets/article/reader.css',
    'assets/article/reader.js',
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

  /// Extracts all reader assets to [targetDirectory].
  ///
  /// On unchanged [version], existing files are skipped. When [version]
  /// differs from the last extracted version, all files are re-written.
  /// Pass `force: true` to unconditionally re-extract.
  Future<void> extractAll({required String version, bool force = false}) async {
    final versionFile = File(p.join(targetDirectory.path, '.asset_version'));
    final shouldForce = force || !await _versionMatches(versionFile, version);

    for (final assetPath in _assetPaths) {
      final bundleKey = 'packages/reader_webview/$assetPath';
      final relativePath = assetPath.replaceFirst('assets/', '');
      final targetPath = p.join(targetDirectory.path, relativePath);
      final targetFile = File(targetPath);

      if (!shouldForce && await targetFile.exists()) continue;

      await Directory(p.dirname(targetPath)).create(recursive: true);

      try {
        final data = await rootBundle.load(bundleKey);
        await targetFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      } catch (e) {
        continue;
      }
    }

    if (shouldForce) {
      await versionFile.parent.create(recursive: true);
      await versionFile.writeAsString(version, flush: true);
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
