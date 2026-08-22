# reader_server

Local HTTP server that serves book files and static reader assets to the
reader WebView. Bound to `127.0.0.1` on a system-assigned port —
**localhost-only**, never exposed to the network.

`flutter_inappwebview` cannot read files bundled via Flutter's rootBundle
or arbitrary paths outside its sandbox directly. Instead, the reader loads
everything from a token-scoped base URI such as
`http://127.0.0.1:<port>/r/<session-token>/`.

Created once in composition, lives in `DependenciesContainer`, started on
app launch and stopped on dispose.

## Route families

| Route                                         | Served from                                    |
|-----------------------------------------------|------------------------------------------------|
| `GET /r/<token>/book/<encoded-path>`          | Files inside `booksDirectory`, plus explicitly granted file-picker results. |
| `GET /r/<token>/article/<encoded-dir>/<path>` | Files inside `articlesDirectory` and the selected article directory. |
| `GET /r/<token>/assets/<path>`                | Files inside `assetsDirectory` (foliate-js etc.). |

All other methods return `405`, unknown or unauthorized routes return `404`.
Every file is resolved through symlinks and checked against its configured
root before it is opened. Traversal, absolute-path substitution, and symlink
escapes are rejected.

Content-Type is inferred from file extension (`.html`, `.epub`, `.pdf`,
`.css`, `.js`, `.woff2`, etc.). Range requests (`bytes=...`) are honoured
on both route families so foliate-js's `RemoteFile` shim can read EPUB
chapters without loading the whole file into memory.

## Public API

| Member                       | Purpose                                           |
|------------------------------|---------------------------------------------------|
| `ReaderServer({assetsDirectory, booksDirectory, articlesDirectory, logger})` | Constructor |
| `start()`                    | Bind + listen (system-assigned port)              |
| `stop()`                     | Close the server and release the port             |
| `port`                       | The assigned port (valid only after `start`)      |
| `baseUri`                    | Token-scoped URI consumed by reader widgets       |
| `isRunning`                  | Whether the server is currently listening         |
| `assetsDirectory`            | Where extracted reader assets are stored          |
| `grantTemporaryBookAccess()` | Revocable, reference-counted access for an imported external file |

## Dependencies

- `monitoring` — `Logger` for request tracing and errors
- `path`

The `assetsDirectory` is populated by `reader_webview`'s `AssetExtractor`,
which copies foliate-js out of rootBundle on first launch.
