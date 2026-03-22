import 'package:article_parser/article_parser.dart';

class FakeArticleParser implements ArticleParser {
  bool shouldThrow = false;

  @override
  Future<ParsedArticle> parse(String url) async {
    if (shouldThrow) throw Exception('parse failed');
    return ParsedArticle(
      title: 'Parsed Title',
      cleanedHtml: '<p>Clean content</p>',
      siteName: 'example.com',
      estimatedWordCount: 500,
    );
  }
}
