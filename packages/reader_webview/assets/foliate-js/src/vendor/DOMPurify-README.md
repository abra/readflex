# DOMPurify

- Upstream: https://github.com/cure53/DOMPurify
- Version: 3.4.14, pinned in `packages/reader_webview/package-lock.json`.
- `purify.js`: unmodified npm `dompurify/dist/purify.es.mjs`.
- `DOMPurify-LICENSE`: unmodified npm `dompurify/LICENSE` (Apache-2.0).

The runtime imports the bundled module; it does not load a CDN or require npm
on user devices. The license is bundled alongside the module.

To update, select a reviewed upstream version, update the exact npm dependency
and lockfile, copy the upstream module/license, bump `AssetExtractor.assetRevision`,
then run both browser suites and `make verify`. Keep application policy in
`readflex_content_security.js`, not in the vendored library.
