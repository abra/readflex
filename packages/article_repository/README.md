# article_repository

Domain repository for articles. Wraps `ArticlesDao` from `local_storage` and
owns on-disk storage of article content, cover images, and body images.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `articlesDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## On-disk layout

Each article lives in its own directory under the `articlesDirectory` passed
at construction. The DB row stores only filenames (`content.html`, `cover.png`)
so the data survives iOS Documents-UUID changes.

```
articles/<uuid>/
  content.html       — cleaned HTML from readability
  cover.<ext>        — cover image (if available)
  images/<hash>.ext  — downloaded body images
```

On import, referenced `<img src>` URLs are downloaded into `images/` and
rewritten to relative `images/<hash>.<ext>` paths in the HTML. Best-effort:
images that fail to download keep their original URL.

## Public API

| Method                                | Purpose                                        |
|---------------------------------------|------------------------------------------------|
| `getArticles({limit, offset})`        | List articles ordered by added date            |
| `getArticleById(id)`                  | Lookup by id, returns null if missing          |
| `readContent(article)`                | Read HTML body from disk                       |
| `addArticle({title, url, content, ...})` | Create article, download images + cover     |
| `updateArticle(article)`              | Update metadata (not content)                  |
| `deleteArticle(id)`                   | Delete row + remove per-article directory      |

## Dependencies

- `domain_models` — `Article`, `StorageException`
- `local_storage` — `AppDatabase`, `ArticlesDao`
- `http` — image and cover downloads
- `path`, `uuid`

## Related packages

- `article_parser` produces the cleaned HTML passed to `addArticle`.
- `reader_server` serves `content.html` and `images/<filename>` to the
  reader WebView over localhost.
