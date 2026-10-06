// Article anchors never navigate the WebView. A fragment scrolls in place,
// anything off the reader server is handed to Flutter, and loopback links
// stay inert so the token-scoped server URL never leaves the reader.

const stripHash = url => `${url.origin}${url.pathname}${url.search}`

const parseURL = (value, base) => {
    try {
        return new URL(value, base)
    } catch {
        return null
    }
}

export const classifyArticleLink = (href, { documentUrl, baseUrl } = {}) => {
    const raw = String(href ?? '').trim()
    if (!raw) return { kind: 'inert' }
    if (raw.startsWith('#')) {
        return raw.length > 1 ? { kind: 'fragment', hash: raw } : { kind: 'inert' }
    }
    const document = parseURL(documentUrl)
    const resolved = parseURL(raw, baseUrl || documentUrl)
    if (!resolved) return { kind: 'inert' }
    if (resolved.hash && resolved.hash.length > 1) {
        const target = stripHash(resolved)
        const sameDocument = [documentUrl, baseUrl]
            .map(value => parseURL(value))
            .some(url => url && stripHash(url) === target)
        if (sameDocument) return { kind: 'fragment', hash: resolved.hash }
    }
    if (document && resolved.origin === document.origin) return { kind: 'inert' }
    if (!/^(https?|mailto|tel):$/i.test(resolved.protocol)) return { kind: 'inert' }
    return { kind: 'external', href: resolved.href }
}

// Finds the anchor for a click without scanning beyond the ancestor chain.
export const anchorFromEvent = event => {
    const target = event?.target
    const element = target?.nodeType === 1 ? target : target?.parentElement
    return element?.closest?.('a[href]') ?? null
}
