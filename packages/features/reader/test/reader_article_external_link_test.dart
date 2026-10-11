import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The article WebView cannot be pumped without a platform WebView, so the
/// wiring from the link sheet down to `ArticleHtmlReaderWebView.onExternalLink`
/// is asserted at source level; `reader_external_link_prompt_test.dart` covers
/// the sheet between a reported link and `ReaderScreen.onOpenExternalLink`.
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

  test('ReaderScreen exposes one onOpenExternalLink callback for both '
      'formats', () {
    final screen = _readSource('lib/src/reader_screen.dart');
    expect(screen, contains('final ValueChanged<String>? onOpenExternalLink;'));
    expect(screen, contains('onOpenExternalLink: onOpenExternalLink,'));
    expect(screen, isNot(contains('onExternalLink: onExternalLink,')));
  });

  test('page links reach the host only through the link sheet', () {
    final source = _readSource('lib/src/reader_screen_content.dart');
    final view = source.substring(
      source.indexOf('class _ReaderView extends StatelessWidget'),
      source.indexOf('class _ReaderScaffold extends StatelessWidget'),
    );
    expect(view, contains('ReaderExternalLinkPrompt('));
    expect(view, contains('onOpen: onOpenExternalLink,'));
    expect(view, contains('builder: (context, onExternalLink) =>'));
    expect(view, contains('onExternalLink: onExternalLink,'));
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
