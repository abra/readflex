# reader_server

Local HTTP server that serves book files (including article EPUBs) and
static reader assets to the reader WebView. Bound to `127.0.0.1` on a
system-assigned port — **localhost-only**, never exposed to the network.

`flutter_inappwebview` cannot read files bundled via Flutter's rootBundle
or arbitrary paths outside its sandbox directly. Instead, the reader loads
everything over `http://127.0.0.1:<port>/...` from this server.

Created once in composition, lives in `DependenciesContainer`, started on
app launch and stopped on dispose.

## Route families

| Route                                         | Served from                                    |
|-----------------------------------------------|------------------------------------------------|
| `GET /book/<url-encoded-absolute-path>`       | Any path on disk — streams the raw file. Used for books AND article EPUBs (articles are packaged as single-chapter EPUBs at import time). |
| `GET /assets/<path>`                          | `<assetsDirectory>/<path>` (foliate-js etc.)   |

All other methods return `405`, unknown routes return `404`. Asset paths
are validated against `..` traversal and canonicalized to guarantee they
stay within `assetsDirectory`.

Content-Type is inferred from file extension (`.html`, `.epub`, `.pdf`,
`.css`, `.js`, `.woff2`, etc.). Range requests (`bytes=...`) are honoured
on both route families so foliate-js's `RemoteFile` shim can read EPUB
chapters without loading the whole file into memory.

## Public API

| Member                       | Purpose                                           |
|------------------------------|---------------------------------------------------|
| `ReaderServer({assetsDirectory, logger})` | Constructor                          |
| `start()`                    | Bind + listen (system-assigned port)              |
| `stop()`                     | Close the server and release the port             |
| `port`                       | The assigned port (valid only after `start`)      |
| `isRunning`                  | Whether the server is currently listening         |
| `assetsDirectory`            | Where asset files live (exposed so the webview can compute URLs) |

## Dependencies

- `monitoring` — `Logger` for request tracing and errors
- `path`

The `assetsDirectory` is populated by `reader_webview`'s `AssetExtractor`,
which copies foliate-js out of rootBundle on first launch.
