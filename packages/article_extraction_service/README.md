# article_extraction_service

Article extraction backend client. It takes a user-provided article URL and
returns an `ExtractedArticle` domain model that can be persisted by
`article_repository`.

## Public API

| Symbol | Kind | Purpose |
|--------|------|---------|
| `ArticleExtractionService` | abstract class | Contract for extracting readable article content from a URL |
| `TrafilaturaArticleExtractionService` | concrete | HTTP client for the Readflex article-cleaner backend |
| `ArticleExtractionException` | exception | User-facing extraction failure with optional HTTP status |

## Current Behavior

`TrafilaturaArticleExtractionService` first downloads the article HTML on the
client and posts that HTML to `/v1/extract-html`. This preserves the resolved
URL, content type, language/direction hints, and some image metadata from the
original document.

When the local download is blocked or extraction fails in ways the backend can
recover from, it falls back to `/v1/extract`, where the backend fetches the URL
itself. A `422` "could not extract" response is retried once with recall-favoring
settings before surfacing an error.

The service caps downloaded HTML at `defaultMaxDownloadBytes` and applies a
request timeout so article import cannot hang indefinitely.

## Configuration

The app wires this package in `lib/app/composition.dart` using:

- `ARTICLE_CLEANER_BASE_URL`
- `ARTICLE_CLEANER_API_KEY` (optional)

The ngrok skip-warning header is intentionally sent for development tunnels.

## Dependencies

- `domain_models` - `ExtractedArticle`, `ArticleBlock`, language/direction helpers
- `http` - backend and article download requests

## Where It Fits

`routing.dart` passes the service into the import flow callback. The import flow
does not store articles itself; it extracts content, then delegates persistence
to `article_repository`.
