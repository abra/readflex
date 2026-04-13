import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Metadata extracted from a book file by foliate-js.
class BookMetadata {
  const BookMetadata({
    required this.title,
    this.author,
    this.description,
    this.coverData,
    this.coverMimeType,
  });

  final String title;
  final String? author;
  final String? description;

  /// Raw cover image bytes (decoded from base64).
  final Uint8List? coverData;

  /// MIME type of the cover (e.g. 'image/jpeg').
  final String? coverMimeType;
}

/// Extracts metadata (title, author, cover) from any book format
/// supported by foliate-js using a [HeadlessInAppWebView].
///
/// Usage:
/// ```dart
/// final extractor = BookMetadataExtractor(serverPort: server.port);
/// final metadata = await extractor.extract('/path/to/book.epub');
/// ```
class BookMetadataExtractor {
  BookMetadataExtractor({required this.serverPort});

  /// Port of the local [ReaderServer].
  final int serverPort;

  /// Extracts metadata from the book at [filePath].
  ///
  /// Loads the book in a headless WebView with foliate-js in import mode.
  /// foliate-js detects the format, parses metadata, and sends it back
  /// via the `onMetadata` JS handler.
  ///
  /// Throws [TimeoutException] if extraction takes longer than [timeout].
  Future<BookMetadata> extract(
    String filePath, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<BookMetadata>();
    HeadlessInAppWebView? headless;

    try {
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_buildUrl(filePath))),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          supportZoom: false,
        ),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'onMetadata',
            callback: (args) {
              if (completer.isCompleted) return;
              final data = args.first as Map<String, dynamic>;
              completer.complete(parseMetadata(data));
            },
          );
        },
        onConsoleMessage: (controller, message) {
          // ignore: avoid_print
          print('BookMetadataExtractor JS: ${message.message}');
        },
      );

      await headless.run();

      return await completer.future.timeout(timeout);
    } on TimeoutException {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Book metadata extraction timed out', timeout),
        );
      }
      rethrow;
    } finally {
      await headless?.dispose();
    }
  }

  String _buildUrl(String filePath) {
    final bookUrl = Uri.encodeComponent(filePath);
    final params = {
      'importing': 'true',
      'url': Uri.encodeComponent(
        jsonEncode(
          'http://127.0.0.1:$serverPort/book/$bookUrl',
        ),
      ),
      'initialCfi': Uri.encodeComponent(jsonEncode(null)),
      // foliate-js accesses style.allowScript in the Loader constructor
      // (epub.js) before the `if (importing) return` early exit. Pass a
      // minimal object so JSON.parse doesn't yield null.
      'style': Uri.encodeComponent(jsonEncode(const {'allowScript': false})),
      'readingRules': Uri.encodeComponent(
        jsonEncode(const {
          'convertChineseMode': 'none',
          'bionicReadingMode': false,
        }),
      ),
    };
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'http://127.0.0.1:$serverPort/assets/foliate-js/index.html?$query';
  }

  /// Parses raw JS metadata map into a [BookMetadata].
  @visibleForTesting
  static BookMetadata parseMetadata(Map<String, dynamic> data) {
    // foliate-js returns author as a String, a List of strings, or a
    // List of Maps (`{name: "...", sortAs: "..."}`).
    final rawAuthor = data['author'];
    final author = switch (rawAuthor) {
      String s => s,
      List list => list.map(_authorElementToString).join(', '),
      _ => null,
    };

    // Cover arrives as a data URL: "data:image/jpeg;base64,..."
    final coverDataUrl = data['cover'] as String?;
    Uint8List? coverBytes;
    String? coverMime;

    if (coverDataUrl != null && coverDataUrl.startsWith('data:')) {
      final commaIndex = coverDataUrl.indexOf(',');
      if (commaIndex > 0) {
        final header = coverDataUrl.substring(5, commaIndex);
        coverMime = header.replaceAll(';base64', '');
        coverBytes = base64Decode(coverDataUrl.substring(commaIndex + 1));
      }
    }

    return BookMetadata(
      title: (data['title'] as String?) ?? 'Unknown',
      author: author,
      description: data['description'] as String?,
      coverData: coverBytes,
      coverMimeType: coverMime,
    );
  }

  /// Extracts a display name from an author list element.
  ///
  /// foliate-js may return `{name: "...", sortAs: "..."}` maps or plain
  /// strings. We need the human-readable `name` field from maps.
  static String _authorElementToString(dynamic element) {
    if (element is Map) {
      return (element['name'] as String?) ?? element.toString();
    }
    return element.toString();
  }
}
