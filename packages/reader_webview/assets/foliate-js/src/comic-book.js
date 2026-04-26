export const makeComicBook = ({ entries, loadBlob, getSize }, file) => {
    const cache = new Map()
    const urls = new Map()
    const load = async name => {
        if (cache.has(name)) return cache.get(name)
        const src = URL.createObjectURL(await loadBlob(name))
        const page = URL.createObjectURL(
            new Blob([`<img src="${src}">`], { type: 'text/html' }))
        urls.set(name, [src, page])
        cache.set(name, page)
        return page
    }
    const unload = name => {
        urls.get(name)?.forEach?.(url => URL.revokeObjectURL(url))
        urls.delete(name)
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
    book.rendition = { layout: 'pre-paginated' }
    book.resolveHref = href => ({ index: book.sections.findIndex(s => s.id === href) })
    book.splitTOCHref = href => [href, null]
    book.getTOCFragment = doc => doc.documentElement
    book.destroy = () => {
        for (const arr of urls.values())
            for (const url of arr) URL.revokeObjectURL(url)
    }
    return book
}
