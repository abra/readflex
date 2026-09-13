import 'dart:convert';

import 'package:domain_models/domain_models.dart';

/// Original, offline-only content shared by widget and device tests.
abstract final class ReadingFixture {
  static const bookTitle = 'A Small Book About Reading';
  static const articleTitle = 'Portable Power Explained';
  static const articleUrl = 'https://example.com/reading-fixture';
  static const sentence = 'The power bank keeps devices running.';
  static const phrase = 'power bank';

  static ExtractedArticle get article {
    final blocks = <ArticleBlock>[
      const ArticleHeadingBlock(level: 2, text: 'Portable energy'),
      for (var i = 0; i < 24; i++)
        ArticleParagraphBlock(
          text:
              '$sentence Section $i explains how to store energy safely. '
              'A device can save power by shutting off its display.',
        ),
      const ArticleHeadingBlock(level: 2, text: 'A second chapter'),
      const ArticleParagraphBlock(text: 'Reading continues without a network.'),
    ];
    return ExtractedArticle(
      requestedUrl: articleUrl,
      title: articleTitle,
      author: 'Readflex Tests',
      language: 'en',
      blocks: blocks,
      plainText: blocks.map((block) => block.fallbackText).join('\n'),
      rawJson: jsonEncode({
        'title': articleTitle,
        'language': 'en',
        'blocks': blocks.map((block) => block.toJson()).toList(),
      }),
    );
  }

  static String get fb2 =>
      '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
<description><title-info><genre>nonfiction</genre>
<author><first-name>Readflex</first-name><last-name>Tests</last-name></author>
<book-title>$bookTitle</book-title><lang>en</lang>
</title-info></description><body>
${List.generate(3, (chapter) => '''<section id="chapter-$chapter">
<title><p>Chapter ${chapter + 1}</p></title>
${List.generate(30, (paragraph) => '<p>$sentence Chapter ${chapter + 1}, paragraph ${paragraph + 1}. A device saves power by shutting off its display. Reading is easier when the page stays still.</p>').join('\n')}
</section>''').join('\n')}
</body></FictionBook>''';
}
