# article_parser

Fetches an article URL and extracts readable content on-device. Used by the
import flow to save "reader mode" articles into the library.

The current implementation (`ReadabilityArticleParser`) downloads the HTML via
`package:http` and runs `readability_dart` locally — no dedicated backend is
involved. The interface is kept abstract so a future server-side parser can
be dropped in without touching callers.

## Public API

| Symbol                      | Type           | Purpose                                                    |
|-----------------------------|----------------|------------------------------------------------------------|
| `ArticleParser`             | abstract class | Contract: `parse(url)` returns a `ParsedArticle`           |
| `ReadabilityArticleParser`  | concrete       | Fetches HTML + runs readability_dart locally               |
| `NoopArticleParser`         | concrete       | Returns a stub article, used in tests                      |
| `ParsedArticle`             | data class     | Title, cleaned HTML, byline, cover, word count, etc.       |
| `ArticleParserException`    | exception      | Carries an `ArticleParserFailure` reason and optional code |
| `ArticleParserFailure`      | enum           | `invalidUrl`, `network`, `httpStatus`, `noContent`         |

## Usage

```dart
final parser = context.dependencies.articleParser;

try {
  final article = await parser.parse('https://example.com/post');
  // save article.cleanedHtml + metadata via ArticleRepository
} on ArticleParserException catch (e) {
  switch (e.reason) {
    case ArticleParserFailure.invalidUrl:   // show "Invalid URL"
    case ArticleParserFailure.network:      // show offline banner
    case ArticleParserFailure.httpStatus:   // show e.statusCode
    case ArticleParserFailure.noContent:    // show "No readable content"
  }
}
```

Callers map `ArticleParserFailure` to user-facing messages; the exception's
`message` field is for logs only.

## Where it fits

Registered on `DependenciesContainer.articleParser` in
`lib/app/composition.dart` and consumed by the import flow. Response bodies
are decoded by content-type charset (UTF-8 / Latin-1, with UTF-8 fallback).
