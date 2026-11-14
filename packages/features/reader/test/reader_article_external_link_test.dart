import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wiring checked at source level; the article body's own link taps
/// are pumped in `reader_screen_article_test.dart`, and the sheet between
/// a reported link and `ReaderScreen.onOpenExternalLink` in
/// `reader_external_link_prompt_test.dart`.
void main() {
  test('article body forwards onExternalLink to the reader view', () {
    final source = _readSource('lib/src/reader_screen_content.dart');
    final start = source.indexOf('_PageKind.article => ReaderArticleBody(');
    final construction = source.substring(
      start,
      source.indexOf('_PageKind.pdf =>', start),
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
      source.indexOf('class ReaderView extends StatelessWidget'),
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
