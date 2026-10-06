import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The article WebView cannot be pumped without a platform WebView, so the
/// wiring from `ReaderScreen.onExternalLink` down to
/// `ArticleHtmlReaderWebView.onExternalLink` is asserted at source level, the
/// same way the book body is covered by the root routing tests.
void main() {
  test('article body forwards onExternalLink to the article WebView', () {
    final source = _readSource('lib/src/reader_screen_content.dart');
    final articleBody = source.substring(
      source.indexOf('class _ReaderArticleHtmlBody extends StatefulWidget'),
    );

    expect(
      articleBody,
      contains('final ValueChanged<String>? onExternalLink;'),
    );
    expect(articleBody, contains('onExternalLink: widget.onExternalLink,'));
    final construction = source.substring(
      source.indexOf('? _ReaderArticleHtmlBody('),
      source.indexOf(
        'onLoading: () {',
        source.indexOf('? _ReaderArticleHtmlBody('),
      ),
    );
    expect(construction, contains('onExternalLink: widget.onExternalLink,'));
  });

  test('ReaderScreen exposes one onExternalLink callback for both formats', () {
    final screen = _readSource('lib/src/reader_screen.dart');
    expect(screen, contains('final ValueChanged<String>? onExternalLink;'));
    expect(
      RegExp('onExternalLink: onExternalLink,').allMatches(screen).length,
      greaterThanOrEqualTo(1),
    );
  });
}

String _readSource(String packagePath) {
  final candidates = [
    File(packagePath),
    File('packages/features/reader/$packagePath'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Reader source file not found: $packagePath');
}
