# article_repository

Persists imported articles, their local assets, and reader-compatible article
files.

## Public API

| Symbol | Purpose |
|--------|---------|
| `ArticleRepository` | Stores, reads, updates, and deletes article sources |
| `EpubBuilder` | Builds the generated article EPUB compatibility adapter |
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
available, rewritten to local paths, and embedded in `article.epub`. Missing
images are skipped so article import can still succeed.

`content.html` is the primary article reading file. Text blocks are marked with
stable block ids and sentence anchors so the vertical HTML reader can restore
position without depending on paginated EPUB layout. `article.epub` remains a
compatibility artifact produced from the same extracted article data.

## Storage Contract

The repository writes metadata to `local_storage` through `ArticlesDao` and wraps
storage failures in `StorageException`. Deleting an article also removes related
review items, highlights, flashcards, dictionary entries, bookmarks, and the
article directory on disk.

The reader still opens articles through the existing `Book` reader model so the
rest of the app can share source progress, title, cover, and path handling. Use
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
owns persistence, local asset rewriting, HTML generation, and EPUB compatibility
generation. Feature packages should depend on this repository contract rather
than accessing article storage directly.
