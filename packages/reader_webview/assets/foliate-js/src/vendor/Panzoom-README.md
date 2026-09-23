# Panzoom

- Upstream: https://github.com/timmywil/panzoom
- Version: 4.6.2, pinned in `packages/reader_webview/package-lock.json`.
- `panzoom.js`: unmodified npm `@panzoom/panzoom/dist/panzoom.es.js`.
- `Panzoom-LICENSE`: unmodified npm `@panzoom/panzoom/MIT-License.txt`.

The comic renderer loads the bundled module offline, only for comic archives.
Gesture arbitration and iframe coordinates belong to `readflex_comic_zoom.js`;
focal zoom, transforms and pan bounds use the upstream library.

To update, review upstream changes, update the exact npm dependency and lockfile,
copy the module and license, bump `AssetExtractor.assetRevision`, then run the
Chromium/WebKit comic gesture tests and native Android/iOS verification.
