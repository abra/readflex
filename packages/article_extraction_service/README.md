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

`TrafilaturaArticleExtractionService` uses a server-first hybrid strategy. It
first posts the URL to `/v1/extract`, where the article-cleaner backend fetches
and parses the page. A `422` response with `detail.code: "extract_failed"` is
retried once with recall-favoring settings before fallback is considered.

If the backend reports a recoverable fetch or extraction failure with
`detail.code` equal to `fetch_failed`, `extract_failed`, or `unsafe_redirect`,
the service downloads the article HTML on the client and posts that HTML to
`/v1/extract-html`. This fallback preserves the resolved URL, content type,
language/direction hints, and some image metadata from the original document.

Cleaner authentication, validation, timeout, and connection failures are not
retried through client HTML because they do not indicate that another fetch path
would succeed. Client-side fallback downloads are capped at
`defaultMaxDownloadBytes` and use the same request timeout so article import
cannot hang indefinitely.

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
