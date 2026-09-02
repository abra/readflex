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
`detail.code` equal to `fetch_failed` or `extract_failed`, the service may
download the article HTML on the client and post that HTML to
`/v1/extract-html`. An unsafe redirect is a terminal security failure, not a
fallback signal. The fallback preserves the resolved URL, content type,
language/direction hints, and some image metadata from the original document.

Cleaner authentication, validation, timeout, and connection failures are not
retried through client HTML because they do not indicate that another fetch path
would succeed. Before connecting, the fallback rejects URL credentials,
non-HTTP(S) schemes, private/local IP addresses, and hosts with unsafe or mixed
DNS results. Redirects are followed manually and every hop is revalidated.
The fallback uses a content-only client that connects to the exact validated
address, so a DNS change between validation and connection cannot redirect the
request to a private network. The cleaner backend keeps its own client and is
not subject to this user-content policy. Downloads are capped at
`defaultMaxDownloadBytes`; one absolute deadline covers DNS, redirects,
connection, and body streaming, and an expired or oversized stream is
cancelled.

## Configuration

The app wires this package in `lib/app/composition.dart` using:

- `ARTICLE_CLEANER_BASE_URL`
- `READFLEX_API_KEY` (optional and development-only)

`ARTICLE_CLEANER_API_KEY` remains accepted as a legacy development alias.
Static API credentials are rejected in staging and production builds; those
environments require the future short-lived backend credential flow.

The ngrok skip-warning header is intentionally sent for development tunnels.

## Dependencies

- `domain_models` - `ExtractedArticle`, `ArticleBlock`, language/direction helpers
- `http` - backend and article download requests
- `remote_content_policy` - URL, DNS, and redirect safety policy

## Where It Fits

`routing.dart` passes the service into the import flow callback. The import flow
does not store articles itself; it extracts content, then delegates persistence
to `article_repository`.
