const DJVU_SCRIPT_URL = new URL('./vendor/djvu.js', import.meta.url).href
const SEARCH_UNAVAILABLE_MESSAGE = 'This DjVu file has no searchable text layer.'
const BITMAP_PAGE_CACHE_LIMIT = 7
const IMAGE_DATA_PAGE_CACHE_LIMIT = 3

let djvuLibraryPromise

const loadDjVuLibrary = () => {
    if (globalThis.DjVu?.Worker) return Promise.resolve(globalThis.DjVu)
    if (djvuLibraryPromise) return djvuLibraryPromise

    djvuLibraryPromise = new Promise((resolve, reject) => {
        const script = document.createElement('script')
        script.src = DJVU_SCRIPT_URL
        script.async = true
        script.onload = () => globalThis.DjVu?.Worker
            ? resolve(globalThis.DjVu)
            : reject(new Error('DjVu.js loaded without exposing DjVu.Worker'))
        script.onerror = () => reject(new Error('Failed to load DjVu.js'))
        document.head.append(script)
    })
    return djvuLibraryPromise
}

const stripDjVuExtension = name =>
    name.replace(/\.(djvu|djv)$/i, '')

const makeTextDocument = text => {
    const doc = document.implementation.createHTMLDocument('')
    const pre = doc.createElement('pre')
    pre.style.whiteSpace = 'pre-wrap'
    pre.textContent = text
    doc.body.append(pre)
    return doc
}

const makeCanvasPageHtml = ({ width, height }) => `<!doctype html>
<meta charset="utf-8">
<style>
html, body {
    margin: 0;
    width: ${width}px;
    height: ${height}px;
    overflow: hidden;
    background: transparent;
}
canvas {
    display: block;
    width: ${width}px;
    height: ${height}px;
}
</style>
<canvas id="page" width="${width}" height="${height}" aria-hidden="true"></canvas>
`

const imageDataToBitmap = async imageData => {
    if (typeof globalThis.createImageBitmap !== 'function') return null
    try {
        return await globalThis.createImageBitmap(imageData)
    } catch (error) {
        console.warn('[readflex-djvu] createImageBitmap failed', error)
        return null
    }
}

const imageDataToCanvasEntry = async imageData => {
    const width = Math.max(1, Number(imageData.width) || 1)
    const height = Math.max(1, Number(imageData.height) || 1)
    const bitmap = await imageDataToBitmap(imageData)
    const retainedImageData = bitmap ? null : imageData

    const drawToContext = ctx => {
        if (bitmap) {
            ctx.drawImage(bitmap, 0, 0)
            return
        }
        if (retainedImageData) ctx.putImageData(retainedImageData, 0, 0)
    }

    return {
        kind: 'canvas-image',
        width,
        height,
        usesImageBitmap: Boolean(bitmap),
        draw(doc) {
            const canvas = doc.getElementById('page')
            const ctx = canvas?.getContext?.('2d')
            if (!ctx) return
            drawToContext(ctx)
        },
        async toBlob() {
            const canvas = document.createElement('canvas')
            canvas.width = width
            canvas.height = height
            const ctx = canvas.getContext('2d')
            if (!ctx) return new Blob([], { type: 'image/png' })
            drawToContext(ctx)
            return await new Promise(resolve => {
                canvas.toBlob(
                    blob => resolve(blob ?? new Blob([], { type: 'image/png' })),
                    'image/png',
                )
            })
        },
        close() {
            bitmap?.close?.()
        },
    }
}

const normalizeContents = async (worker, items = []) => Promise.all(
    items.map(async item => {
        const pageNumber = item.url
            ? await worker.doc.getPageNumberByUrl(item.url).run().catch(() => null)
            : null
        const children = item.children?.length
            ? await normalizeContents(worker, item.children)
            : undefined
        return {
            label: item.description || item.title || item.url || 'Page',
            href: pageNumber ? `page-${pageNumber}` : item.url,
            ...(children ? { subitems: children } : {}),
        }
    }),
)

export const isDjVu = async ({ name = '', type = '', slice }) => {
    const lowerName = name.toLowerCase()
    if (
        lowerName.endsWith('.djvu') ||
        lowerName.endsWith('.djv') ||
        type === 'image/vnd.djvu' ||
        type === 'image/x-djvu'
    ) {
        return true
    }
    try {
        const header = await slice(0, 12).text()
        const form = header.slice(0, 4)
        const kind = header.slice(8, 12)
        return form === 'FORM' && ['DJVU', 'DJVM', 'PM44', 'BM44'].includes(kind)
    } catch (_) {
        return false
    }
}

export const makeDjVuBook = async file => {
    const DjVu = await loadDjVuLibrary()
    const worker = new DjVu.Worker(DJVU_SCRIPT_URL)
    await worker.createDocument(await file.arrayBuffer(), {})

    const pageCount = await worker.doc.getPagesQuantity().run()
    const contents = await worker.doc.getContents().run().catch(() => [])
    const toc = await normalizeContents(worker, contents ?? [])
    const cache = new Map()
    const pending = new Map()
    const textCache = new Map()
    const prefetching = new Set()
    const lru = []
    let textLayerPromise
    let destroyed = false

    const pageCacheLimit = () => {
        for (const entry of cache.values()) {
            if (!entry.usesImageBitmap) return IMAGE_DATA_PAGE_CACHE_LIMIT
        }
        return BITMAP_PAGE_CACHE_LIMIT
    }

    const getPageText = async pageNumber => {
        if (textCache.has(pageNumber)) return textCache.get(pageNumber)

        const text = await worker.doc.getPage(pageNumber).getText().run()
            .catch(() => '')
        const value = typeof text === 'string' ? text : ''
        textCache.set(pageNumber, value)
        return value
    }

    const hasTextLayer = async () => {
        if (!textLayerPromise) {
            textLayerPromise = (async () => {
                for (let pageNumber = 1; pageNumber <= pageCount; pageNumber += 1) {
                    if ((await getPageText(pageNumber)).trim()) return true
                }
                return false
            })()
        }
        return textLayerPromise
    }

    const touch = pageNumber => {
        const index = lru.indexOf(pageNumber)
        if (index !== -1) lru.splice(index, 1)
        lru.unshift(pageNumber)
    }

    const revoke = entry => {
        entry?.close?.()
    }

    const evictIfNeeded = () => {
        while (lru.length > pageCacheLimit()) {
            const pageNumber = lru.pop()
            const entry = cache.get(pageNumber)
            cache.delete(pageNumber)
            revoke(entry)
        }
    }

    const canRenderPage = pageNumber =>
        Number.isInteger(pageNumber) && pageNumber >= 1 && pageNumber <= pageCount

    const schedulePrefetch = pageNumber => {
        if (destroyed || !canRenderPage(pageNumber)) return
        if (cache.has(pageNumber) || pending.has(pageNumber) || prefetching.has(pageNumber)) return
        prefetching.add(pageNumber)
        setTimeout(() => {
            if (destroyed) {
                prefetching.delete(pageNumber)
                return
            }
            render(pageNumber, { prefetch: true })
                .catch(error => console.warn('[readflex-djvu] prefetch failed', error))
                .finally(() => prefetching.delete(pageNumber))
        }, 0)
    }

    const prefetchAround = pageNumber => {
        schedulePrefetch(pageNumber + 1)
        schedulePrefetch(pageNumber - 1)
    }

    const renderPage = async pageNumber => {
        const imageData = await worker.doc.getPage(pageNumber).getImageData().run()
        const entry = await imageDataToCanvasEntry(imageData)
        cache.set(pageNumber, entry)
        touch(pageNumber)
        evictIfNeeded()
        return entry
    }

    async function render(pageNumber, { prefetch = false } = {}) {
        if (!canRenderPage(pageNumber)) throw new Error(`Invalid DjVu page ${pageNumber}`)
        const cached = cache.get(pageNumber)
        if (cached) {
            touch(pageNumber)
            if (!prefetch) prefetchAround(pageNumber)
            return cached
        }
        const active = pending.get(pageNumber)
        if (active) {
            const entry = await active
            if (!prefetch) prefetchAround(pageNumber)
            return entry
        }

        const task = renderPage(pageNumber)
        pending.set(pageNumber, task)
        try {
            const entry = await task
            if (!prefetch) prefetchAround(pageNumber)
            return entry
        } finally {
            pending.delete(pageNumber)
        }
    }

    const unload = pageNumber => {
        const entry = cache.get(pageNumber)
        cache.delete(pageNumber)
        const index = lru.indexOf(pageNumber)
        if (index !== -1) lru.splice(index, 1)
        revoke(entry)
    }

    const book = { rendition: { layout: 'pre-paginated' } }
    book.metadata = { title: stripDjVuExtension(file.name) }
    book.features = {
        format: 'djvu',
        hasToc: toc.length > 0,
        hasTextLayer: null,
        searchUnavailableMessage: SEARCH_UNAVAILABLE_MESSAGE,
    }
    book.hasTextLayer = async () => {
        const detected = await hasTextLayer()
        book.features.hasTextLayer = detected
        return detected
    }
    book.sections = Array.from({ length: pageCount }).map((_, i) => {
        const pageNumber = i + 1
        return {
            id: `page-${pageNumber}`,
            load: async () => {
                const entry = await render(pageNumber)
                entry.html ??= makeCanvasPageHtml(entry)
                return entry
            },
            createDocument: async () => makeTextDocument(await getPageText(pageNumber)),
            unload: () => unload(pageNumber),
            size: 1,
        }
    })
    if (book.sections[0]) book.sections[0].pageSpread = 'right'
    book.toc = toc
    book.getCover = async () => {
        const entry = await render(1, { prefetch: true })
        return entry.toBlob()
    }
    book.resolveHref = href => {
        const index = book.sections.findIndex(section => section.id === href)
        return { index: index < 0 ? 0 : index }
    }
    book.splitTOCHref = href => [href, null]
    book.getTOCFragment = doc => doc.documentElement
    book.destroy = () => {
        destroyed = true
        for (const entry of cache.values()) revoke(entry)
        cache.clear()
        pending.clear()
        prefetching.clear()
        textCache.clear()
        lru.length = 0
        worker.cancelAllTasks?.()
        worker.terminate?.()
    }
    return book
}
