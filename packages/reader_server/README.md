# reader_server

Local HTTP server that serves book files, article HTML, and static reader
assets to the reader WebView. Bound to `127.0.0.1` on a system-assigned
port — **localhost-only**, never exposed to the network.

`flutter_inappwebview` cannot read files bundled via Flutter's rootBundle
or arbitrary paths outside its sandbox directly. Instead, the reader loads
everything over `http://127.0.0.1:<port>/...` from this server.

Created once in composition, lives in `DependenciesContainer`, started on
app launch and stopped on dispose.

## Route families

| Route                                         | Served from                                  |
|-----------------------------------------------|----------------------------------------------|
| `GET /book/<url-encoded-absolute-path>`       | Any path on disk — streams the raw file      |
| `GET /article/<id>`                           | `<articlesDirectory>/<id>/content.html`      |
| `GET /article/<id>/images/<filename>`         | `<articlesDirectory>/<id>/images/<filename>` |
| `GET /assets/<path>`                          | `<assetsDirectory>/<path>` (foliate-js, etc.)|

All other methods return `405`, unknown routes return `404`. Article IDs and
asset paths are validated against `..` traversal; asset paths are additionally
canonicalized to guarantee they stay within `assetsDirectory`.

Content-Type is inferred from file extension (`.html`, `.epub`, `.pdf`,
`.css`, `.js`, `.woff2`, etc.).

## Public API

| Member                       | Purpose                                           |
|------------------------------|---------------------------------------------------|
| `ReaderServer({articlesDirectory, assetsDirectory, logger})` | Constructor             |
| `start()`                    | Bind + listen (system-assigned port)              |
| `stop()`                     | Close the server and release the port             |
| `port`                       | The assigned port (valid only after `start`)      |
| `isRunning`                  | Whether the server is currently listening         |
| `assetsDirectory`            | Where asset files live (exposed so the webview can compute URLs) |

## Dependencies

- `monitoring` — `Logger` for request tracing and errors
- `path`

The `assetsDirectory` is populated by `reader_webview`'s `AssetExtractor`,
which copies foliate-js and article-shell files out of rootBundle on first
launch.
