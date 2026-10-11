// Rendered PDF pages kept for the visible spread and one neighbour on each
// side. Each page bitmap costs megabytes, so everything else is released as
// soon as the reader moves on, and in-flight renders of released pages stop.

/**
 * @template T
 * @param {(index: number, signal: AbortSignal) => Promise<T>} render
 *   renders one page; must stop early once [signal] aborts
 * @param {(value: T) => void} release frees a rendered page
 * @param {number} count number of pages in the document
 */
export const createPdfPageCache = ({ render, release, count }) => {
    const entries = new Map()
    let destroyed = false
    let revision = 0
    let visible = []

    const unload = index => {
        const entry = entries.get(index)
        if (!entry) return
        entries.delete(index)
        entry.controller.abort()
        if (entry.value !== undefined) release(entry.value)
    }

    const load = index => {
        if (destroyed) return Promise.reject(new DOMException('PDF closed', 'AbortError'))
        const existing = entries.get(index)
        if (existing) return existing.promise
        const entry = { controller: new AbortController(), value: undefined }
        entries.set(index, entry)
        entry.promise = (async () => {
            try {
                const value = await render(index, entry.controller.signal)
                if (destroyed || entries.get(index) !== entry) {
                    release(value)
                    throw new DOMException('PDF page released', 'AbortError')
                }
                entry.value = value
                return value
            } catch (error) {
                // Failed pages are retried by the next demand load.
                if (entries.get(index) === entry) entries.delete(index)
                throw error
            }
        })()
        return entry.promise
    }

    /**
     * Keeps [visibleIndices] and their neighbours, releases the rest, then
     * renders the next page and the previous one ahead of the reader.
     */
    const retain = async (visibleIndices, { prefetch = true } = {}) => {
        const pages = visibleIndices.filter(index => Number.isInteger(index) && index >= 0 && index < count)
        if (destroyed || !pages.length) return
        const current = ++revision
        visible = pages
        const next = Math.max(...pages) + 1
        const previous = Math.min(...pages) - 1
        const neighbours = [next, previous].filter(index => index >= 0 && index < count)
        const retained = new Set([...pages, ...neighbours])
        for (const index of [...entries.keys()]) if (!retained.has(index)) unload(index)
        if (!prefetch) return
        for (const index of neighbours) {
            if (destroyed || current !== revision) return
            try {
                await load(index)
            } catch {
                // Speculative failures must not interrupt reading; demand retries.
            }
        }
    }

    return {
        load,
        unload,
        retain,
        /** Rendered value of [index], or undefined while it is not ready. */
        peek: index => entries.get(index)?.value,
        /** Rendered pages, the visible ones first. */
        ready() {
            const order = [...visible, ...entries.keys()]
            return [...new Set(order)]
                .map(index => [index, entries.get(index)?.value])
                .filter(([, value]) => value !== undefined)
        },
        get size() { return entries.size },
        destroy() {
            destroyed = true
            ++revision
            for (const index of [...entries.keys()]) unload(index)
        },
    }
}
