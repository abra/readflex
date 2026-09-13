const CONTEXT_SIDE_CHARS = 2048
const CONTEXT_SIDE_NODES = 256
const MAX_SEGMENTED_SELECTION_CHARS = 4096
const TEXT_NODE = 3
const SHOW_ALL = 0xffffffff
const blockSelector = '[data-rf-sentence], p, li, blockquote, h1, h2, h3, h4, h5, h6, '
    + 'pre, div, td, th, dt, dd, figcaption'
const collapseWhitespace = text => text.replace(/\s+/g, ' ').trim()

let cachedLocale
let cachedSegmenter

const sentenceSegmenter = locale => {
    if (typeof globalThis.Intl?.Segmenter !== 'function') return null
    if (cachedSegmenter && cachedLocale === locale) return cachedSegmenter
    try {
        cachedSegmenter = new Intl.Segmenter(locale, { granularity: 'sentence' })
    } catch {
        cachedSegmenter = new Intl.Segmenter('en', { granularity: 'sentence' })
    }
    cachedLocale = locale
    return cachedSegmenter
}

const selectedContext = selected => {
    const contextText = collapseWhitespace(selected)
    return { contextText, markedContextText: contextText ? `[[${contextText}]]` : '' }
}

export const sentenceContextForSelection = (before, selected, after, {
    locale = 'en', beforeClipped = false, afterClipped = false,
} = {}) => {
    const fallback = selectedContext(selected)
    if (!selected.trim() || selected.length > MAX_SEGMENTED_SELECTION_CHARS) return fallback
    const segmenter = sentenceSegmenter(locale)
    if (!segmenter) return fallback

    // EPUB source line breaks are HTML whitespace, not sentence boundaries.
    const prefix = before.replace(/\s+/g, ' ')
    const selection = selected.replace(/\s+/g, ' ')
    const suffix = after.replace(/\s+/g, ' ')
    const text = prefix + selection + suffix
    const start = prefix.length
    const end = start + selection.length
    const segments = segmenter.segment(text)
    const first = segments.containing(start + selection.length - selection.trimStart().length)
    const last = segments.containing(start + selection.trimEnd().length - 1)
    if (!first || !last) return fallback
    const sentenceStart = first.index
    const sentenceEnd = last.index + last.segment.length
    // A window edge is not a sentence boundary. Never present a clipped word
    // or an unverified fragment as a complete source sentence.
    if ((beforeClipped && sentenceStart === 0)
        || (afterClipped && sentenceEnd === text.length)) return fallback

    return {
        contextText: collapseWhitespace(text.slice(sentenceStart, sentenceEnd)),
        markedContextText: collapseWhitespace(
            `${text.slice(sentenceStart, start)}[[${selection}]]${text.slice(end, sentenceEnd)}`,
        ),
    }
}

const contextRoot = node => {
    const element = node.nodeType === TEXT_NODE ? node.parentElement : node
    return element?.closest?.(blockSelector) ?? node.ownerDocument?.body
}

// Walk outwards from the range, not from the start of a chapter. Both text
// collection and segmentation stay bounded even for unstructured long blocks.
const readContextSide = (container, offset, root, before) => {
    const walker = root.ownerDocument.createTreeWalker(root, SHOW_ALL)
    walker.currentNode = container
    const chunks = []
    let remaining = CONTEXT_SIDE_CHARS
    let visited = 0
    const finish = clipped => ({
        text: (before ? chunks.reverse() : chunks).join(''), clipped,
    })
    const takeText = (node, start, end) => {
        const length = end - start
        chunks.push(before
            ? node.data.slice(Math.max(start, end - remaining), end)
            : node.data.slice(start, Math.min(end, start + remaining)))
        remaining -= Math.min(length, remaining)
    }
    const advance = () => before ? walker.previousNode() : walker.nextNode()
    let node
    if (container.nodeType === TEXT_NODE) {
        const start = before ? 0 : offset
        const end = before ? offset : container.length
        const clipped = end - start > remaining
        takeText(container, start, end)
        if (clipped) return finish(true)
        node = advance()
    } else if (offset < container.childNodes.length) {
        walker.currentNode = container.childNodes[offset]
        node = before ? advance() : walker.currentNode
    } else {
        // Element offsets point between children, not into textContent.
        while (visited < CONTEXT_SIDE_NODES && walker.lastChild()) visited++
        if (visited === CONTEXT_SIDE_NODES) return finish(true)
        node = before ? walker.currentNode : advance()
        if (node === container) node = advance()
    }
    while (node && node !== root && remaining > 0 && visited < CONTEXT_SIDE_NODES) {
        visited++
        if (node.nodeType === TEXT_NODE) {
            // Backward traversal reaches a previous block's last text node
            // before its element, so check ownership before collecting it.
            if (contextRoot(node) !== root) return finish(false)
            const clipped = node.length > remaining
            takeText(node, 0, node.length)
            if (clipped) return finish(true)
        } else if (node.matches?.(blockSelector)) {
            return finish(false)
        }
        node = advance()
    }
    return finish(node != null && node !== root)
}

export const buildSelectionContext = range => {
    if (!range || range.collapsed) return selectedContext('')
    const selected = range.toString()
    if (!selected.trim() || selected.length > MAX_SEGMENTED_SELECTION_CHARS) {
        return selectedContext(selected)
    }
    const root = contextRoot(range.startContainer)
    // Cross-block selections retain the exact selected text. Unselected parts
    // of neighbouring paragraphs do not belong to the selection's sentence.
    if (!root || root !== contextRoot(range.endContainer)) return selectedContext(selected)
    const before = readContextSide(range.startContainer, range.startOffset, root, true)
    const after = readContextSide(range.endContainer, range.endOffset, root, false)
    const locale = root.closest?.('[lang]')?.getAttribute('lang')
        || root.ownerDocument.documentElement.getAttribute('xml:lang') || 'en'
    return sentenceContextForSelection(before.text, selected, after.text, {
        locale, beforeClipped: before.clipped, afterClipped: after.clipped,
    })
}
