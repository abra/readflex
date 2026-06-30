# article_repository

Persists imported articles, their local assets, and reader-compatible article
files.

## Public API

| Symbol | Purpose |
|--------|---------|
| `ArticleRepository` | Stores, reads, updates, and deletes article sources |

Key methods:

- `getArticles({limit, offset})`
- `getArticleById(id)`
- `addExtractedArticle(extracted)`
- `updateArticle(article)`
- `deleteArticle(id)`

## On-Disk Layout

Each imported article gets its own directory under the app `articles` folder:

```text
articles/<article-id>/
  article.json
  content.html
  images/*
  cover.*
```

Remote article images referenced by extracted blocks are downloaded when
available, rewritten to local paths, and stored next to `content.html`. Missing
images are skipped so article import can still succeed.

`content.html` is the primary article reading file. Text blocks are marked with
stable block ids and sentence anchors so the vertical HTML reader can restore
position without depending on paginated EPUB layout.

## Storage Contract

The repository writes metadata to `local_storage` through `ArticlesDao` and wraps
storage failures in `StorageException`. Deleting an article also removes related
review items, highlights, flashcards, dictionary entries, bookmarks, and the
article directory on disk.

The reader opens saved articles from `Article.contentHtmlPath` and persists
article progress by updating the original `Article` row. `article_repository`
does not adapt articles into books.

## Dependencies

- `domain_models` - article, book, and storage exception models
- `local_storage` - Drift database and DAOs
- `monitoring` - optional cleanup/download logging
- `http` - best-effort image and cover downloads
- `path`
- `uuid`

## Where It Fits

`article_extraction_service` extracts readable content. `article_repository`
owns persistence, local asset rewriting, and HTML generation. Feature packages
should depend on this repository contract rather than accessing article storage
directly.
