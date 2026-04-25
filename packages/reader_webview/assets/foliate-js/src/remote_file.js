// A `File`-shaped wrapper that fetches its bytes from an HTTP server using
// `Range:` requests instead of downloading the whole resource up front.
//
// Why we need this: foliate-js opens books through a `File`-like object. The
// out-of-the-box wrapper does `fetch(url).then(res => res.blob())`, which
// pulls the entire file (an EPUB can be 50+ MB) into the WebView before any
// rendering starts. zip.js — used by foliate-js for EPUB/CBZ — only needs
// the central directory and the currently-rendered chapter, so a smarter
// loader makes that available without buffering the whole thing.
//
// The class only implements the surface foliate-js actually touches:
//   * `size`, `name`, `type` properties (read once via a HEAD request);
//   * `slice(start, end)` returning an object with `arrayBuffer()` /
//     `text()` / `size` — that's exactly what zip.js' BlobReader calls.
//
// Multi-range responses, streams, and the rest of the Blob API stay
// unimplemented because no consumer in our pipeline asks for them.
//
// Optimisations layered on top of plain Range fetches:
//   * LRU chunk cache — zip.js often re-reads the same regions (table of
//     contents, neighbour bytes); cached chunks skip the round-trip.
//   * Over-fetching — when a small slice is requested, fetch a larger
//     surrounding chunk so subsequent neighbour reads hit the cache.
//   * In-flight de-duplication — concurrent requests for an identical
//     range share a single HTTP fetch.

/// Minimum bytes pulled per HTTP request. Keeps zip.js' chatter to a
/// reasonable level while staying small enough to avoid pulling huge
/// regions for a single 4-byte magic-number probe.
const MIN_CHUNK_SIZE = 64 * 1024;

/// Maximum number of cached chunks (LRU). 128 chunks × 64 KB = ~8 MB
/// upper bound on the cache when chunks are at the minimum size.
const MAX_CACHE_ITEMS = 128;

class _DeferredBlob {
  constructor(promise, size, type) {
    this._promise = promise;
    this.size = size;
    this.type = type || '';
  }

  async arrayBuffer() {
    return this._promise;
  }

  async text() {
    const buffer = await this._promise;
    return new TextDecoder().decode(buffer);
  }
}

export class RemoteFile {
  constructor(url, { name } = {}) {
    this.url = url;
    this.name = name || decodeURIComponent(url.split('/').pop() || 'remote');
    this.size = 0;
    this.type = '';
    // Marks the object so feature-detection code in foliate-js (`file.isDirectory`)
    // doesn't accidentally treat us as a directory.
    this.isDirectory = false;
    this._opened = false;

    /// Map<chunkStart, ArrayBuffer> — the entire chunk that was actually
    /// fetched. Recently-used chunks are kept at the head of `_lruOrder`.
    this._cache = new Map();
    this._lruOrder = [];

    /// Map<"start-end", Promise<ArrayBuffer>> — in-flight fetches keyed by
    /// the byte range they cover. Concurrent slice() calls for the same
    /// region share the promise instead of issuing duplicate requests.
    this._inFlight = new Map();
  }

  /// Issues a HEAD to learn the total size + content-type. Must be awaited
  /// before any `slice()` calls, otherwise consumers will see size === 0.
  async open() {
    if (this._opened) return this;
    try {
      const response = await fetch(this.url, { method: 'HEAD' });
      if (response.ok) {
        const contentLength = response.headers.get('content-length');
        this.size = contentLength ? Number(contentLength) : 0;
        this.type = response.headers.get('content-type') || '';
        this._opened = true;
        return this;
      }
    } catch (_) {
      // Some platforms reject HEAD outright; fall through to Range probe.
    }
    return this._openWithRange();
  }

  async _openWithRange() {
    const response = await fetch(this.url, {
      headers: { Range: 'bytes=0-0' },
    });
    if (!response.ok) {
      throw new Error(`RemoteFile: HEAD/Range probe failed: ${response.status}`);
    }
    const contentRange = response.headers.get('content-range');
    if (contentRange) {
      // Format: "bytes 0-0/12345"
      const total = contentRange.split('/')[1];
      this.size = total ? Number(total) : 0;
    }
    this.type = response.headers.get('content-type') || '';
    this._opened = true;
    return this;
  }

  /// Returns a thenable Blob-shaped object covering bytes `[start, end)`.
  /// foliate-js / zip.js calls this many times during rendering — backed by
  /// an LRU chunk cache + over-fetching to keep round-trips down.
  slice(start = 0, end = this.size, contentType = this.type) {
    if (start < 0) start = 0;
    if (end > this.size) end = this.size;
    if (end <= start) {
      return new _DeferredBlob(
        Promise.resolve(new ArrayBuffer(0)),
        0,
        contentType,
      );
    }
    const size = end - start;
    return new _DeferredBlob(this._readRange(start, end), size, contentType);
  }

  async _readRange(start, end) {
    // Cache hit: an existing chunk fully covers the requested range.
    const cached = this._findCovering(start, end);
    if (cached) {
      const { chunkStart, buffer } = cached;
      this._touchLru(chunkStart);
      return buffer.slice(start - chunkStart, end - chunkStart);
    }

    // Cache miss: fetch a chunk at least MIN_CHUNK_SIZE wide that includes
    // the requested range. The chunk's lower bound is rounded down so
    // adjacent reads land in the same cache slot.
    const chunkStart = Math.max(
      0,
      Math.floor(start / MIN_CHUNK_SIZE) * MIN_CHUNK_SIZE,
    );
    const chunkEnd = Math.min(
      this.size,
      Math.max(end, chunkStart + MIN_CHUNK_SIZE),
    );
    const chunkBuffer = await this._fetchChunk(chunkStart, chunkEnd);

    return chunkBuffer.slice(start - chunkStart, end - chunkStart);
  }

  _findCovering(start, end) {
    for (const [chunkStart, buffer] of this._cache) {
      if (start >= chunkStart && end <= chunkStart + buffer.byteLength) {
        return { chunkStart, buffer };
      }
    }
    return null;
  }

  async _fetchChunk(chunkStart, chunkEnd) {
    const key = `${chunkStart}-${chunkEnd}`;
    const pending = this._inFlight.get(key);
    if (pending) return pending;

    const promise = this._fetchRange(chunkStart, chunkEnd).then(buffer => {
      this._cache.set(chunkStart, buffer);
      this._touchLru(chunkStart);
      this._evictIfNeeded();
      return buffer;
    });
    this._inFlight.set(key, promise);
    try {
      return await promise;
    } finally {
      this._inFlight.delete(key);
    }
  }

  async _fetchRange(start, end) {
    const inclusiveEnd = end - 1;
    const response = await fetch(this.url, {
      headers: { Range: `bytes=${start}-${inclusiveEnd}` },
    });
    if (!(response.status === 200 || response.status === 206)) {
      throw new Error(
        `RemoteFile: range ${start}-${inclusiveEnd} failed: ${response.status}`,
      );
    }
    return response.arrayBuffer();
  }

  _touchLru(chunkStart) {
    const index = this._lruOrder.indexOf(chunkStart);
    if (index !== -1) this._lruOrder.splice(index, 1);
    this._lruOrder.unshift(chunkStart);
  }

  _evictIfNeeded() {
    while (this._lruOrder.length > MAX_CACHE_ITEMS) {
      const evict = this._lruOrder.pop();
      if (evict !== undefined) this._cache.delete(evict);
    }
  }

  /// Fallback when something asks for the whole buffer up front.
  async arrayBuffer() {
    return this.slice(0, this.size).arrayBuffer();
  }

  async text() {
    return this.slice(0, this.size).text();
  }
}
