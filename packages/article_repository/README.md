# article_repository

Persists imported articles and converts them into reader-compatible EPUB files.

## Public API

| Symbol | Purpose |
|--------|---------|
| `ArticleRepository` | Stores, reads, updates, and deletes article sources |
| `EpubBuilder` | Builds the generated article EPUB used by the reader |
| `EpubImage` | In-memory image payload for EPUB generation |
| `EpubTocEntry` | EPUB table-of-contents entry |

Key methods:

- `getArticles({limit, offset})`
- `getArticleById(id)`
- `addExtractedArticle(extracted)`
- `updateArticle(article)`
- `deleteArticle(id)`
- `toReaderBook(article)`
- `updateFromReaderBook(article, readerBook)`

## On-Disk Layout

Each imported article gets its own directory under the app `articles` folder:

```text
articles/<article-id>/
  article.json
  content.html
  article.epub
  cover.*
```

Remote article images referenced by extracted blocks are downloaded when
available, rewritten to local EPUB paths, and embedded in `article.epub`. Missing
images are skipped so article import can still succeed.

## Storage Contract

The repository writes metadata to `local_storage` through `ArticlesDao` and wraps
storage failures in `StorageException`. Deleting an article also removes related
review items, highlights, flashcards, dictionary entries, bookmarks, and the
article directory on disk.

The reader consumes articles through the existing `Book` reader model. Use
`toReaderBook` before opening an article in the reader, then persist reader
position changes back with `updateFromReaderBook`.

## Dependencies

- `domain_models` - article, book, and storage exception models
- `local_storage` - Drift database and DAOs
- `monitoring` - optional cleanup/download logging
- `http` - best-effort image and cover downloads
- `path`
- `uuid`

## Where It Fits

`article_extraction_service` extracts readable content. `article_repository`
owns persistence and EPUB generation. Feature packages should depend on this
repository contract rather than accessing article storage directly.
