const PREFETCH_BYTES = 8 * 1024 * 1024

export const makeComicBook = ({ entries, loadBlob, getSize }, file) => {
    const cache = new Map()
    let destroyed = false
    let windowRevision = 0
    const load = (name, speculative = false) => {
        if (destroyed) return Promise.reject(new DOMException('Comic closed', 'AbortError'))
        const existing = cache.get(name)
        if (existing) {
            existing.demand ||= !speculative
            return existing.promise
        }
        const entry = { urls: [], bytes: 0, demand: !speculative }
        cache.set(name, entry)
        entry.promise = (async () => {
            try {
                const blob = await loadBlob(name)
                if (destroyed || cache.get(name) !== entry)
                    throw new DOMException('Comic page released', 'AbortError')
                entry.bytes = blob.size
                const src = URL.createObjectURL(blob)
                entry.urls.push(src)
                const page = URL.createObjectURL(
                    new Blob([`<img src="${src}">`], { type: 'text/html' }))
                entry.urls.push(page)
                return page
            } catch (error) {
                if (cache.get(name) === entry) unload(name)
                throw error
            }
        })()
        return entry.promise
    }
    const unload = name => {
        cache.get(name)?.urls.forEach(url => URL.revokeObjectURL(url))
        cache.delete(name)
    }

    const exts = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.jxl', '.avif']
    const files = entries
        .map(entry => entry.filename)
        .filter(name => exts.some(ext => name.endsWith(ext)))
        .sort()
    if (!files.length) throw new Error('No supported image files in archive')

    const book = {}
    book.getCover = () => loadBlob(files[0])
    // Strip the archive extension from the fallback title — `file.name` is
    // the original filename incl. `.cbz`/`.cbr`/`.cb7`/`.cbt`, and the
    // user sees this in library/chrome. Pass the URL pathname through
    // unchanged when no real filename is available.
    book.metadata = { title: file.name.replace(/\.(cbz|cbr|cb7|cbt)$/i, '') }
    // `size: 1` instead of `getSize(name)` — the byte size of each
    // archived image biases foliate-js' progress calculation
    // (`sizeBefore / sizeTotal`). For a CBZ each "section" is one
    // page, so equal-weight sections give the user a linear
    // `pageIndex / totalPages` progress reading instead of a fraction
    // that jumps around with image-compression ratios.
    book.sections = files.map(name => ({
        id: name,
        load: () => load(name),
        unload: () => unload(name),
        size: 1,
    }))
    book.toc = files.map(name => ({ label: name, href: name }))
    book.rendition = { layout: 'pre-paginated', zoomable: true }
    book.resolveHref = href => ({ index: book.sections.findIndex(s => s.id === href) })
    book.splitTOCHref = href => [href, null]
    book.getTOCFragment = doc => doc.documentElement
    // Only encoded image blobs are prefetched, not offscreen iframe/bitmap
    // trees. Visible pages are mandatory; speculative neighbours share 8 MiB.
    book.prepareAdjacentPages = async (visibleIndices, { prefetch = true } = {}) => {
        if (destroyed || !visibleIndices.length) return
        const revision = ++windowRevision
        const retained = new Set(visibleIndices.map(index => files[index]))
        let budget = PREFETCH_BYTES
        const neighbours = [Math.max(...visibleIndices) + 1, Math.min(...visibleIndices) - 1]
            .map(index => files[index]).filter(Boolean)
            .filter(name => {
                const size = Number(getSize?.(name))
                if (!Number.isFinite(size) || size <= 0 || size > budget) return false
                budget -= size
                retained.add(name)
                return true
            })
        for (const name of cache.keys()) if (!retained.has(name)) unload(name)
        if (!prefetch) return
        let bytes = 0
        for (const name of neighbours) {
            if (destroyed || revision !== windowRevision) return
            try {
                await load(name, true)
                if (destroyed || revision !== windowRevision) return
                const entry = cache.get(name)
                if (bytes + entry.bytes > PREFETCH_BYTES && !entry.demand) unload(name)
                else bytes += entry.bytes
            } catch {
                // Speculative failures must not interrupt reading; demand retries.
            }
        }
    }
    book.destroy = () => {
        destroyed = true
        ++windowRevision
        for (const name of cache.keys()) unload(name)
    }
    return book
}
