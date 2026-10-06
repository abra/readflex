// Compare DOM boundaries, not painted rectangles: adjacent highlights touch
// without sharing text, and paint geometry is not stable during selection.

const compare = (range, how, other) => {
    try {
        return range.compareBoundaryPoints(how, other)
    } catch {
        // Ranges from different documents (book iframes) never relate.
        return null
    }
}

export const rangeContainsRange = (outer, inner) => {
    if (!outer || !inner || outer.collapsed || inner.collapsed) return false
    const start = compare(outer, Range.START_TO_START, inner)
    const end = compare(outer, Range.END_TO_END, inner)
    return start != null && end != null && start <= 0 && end >= 0
}

// True when the ranges share at least one character. Touching boundaries
// (one ends where the other starts) do not intersect.
export const rangesIntersect = (a, b) => {
    if (!a || !b || a.collapsed || b.collapsed) return false
    // END_TO_START compares a's start with b's end; START_TO_END a's end
    // with b's start.
    return compare(a, Range.END_TO_START, b) === -1
        && compare(a, Range.START_TO_END, b) === 1
}

const sameBoundaries = (a, b) =>
    compare(a, Range.START_TO_START, b) === 0
    && compare(a, Range.END_TO_END, b) === 0

/**
 * Plans how saving `selection` as a highlight absorbs saved highlights that
 * share text with it, so one piece of text never belongs to two highlights.
 *
 * `saved` holds `{ id, range, ...extra }` entries for one document. The union
 * grows until no remaining entry intersects it: an absorbed highlight that
 * reaches further pulls in a highlight it already overlapped. Returns `null`
 * when nothing intersects; otherwise the union range (a new Range, the
 * selection is untouched), the absorbed entries in document order and
 * `sameAs`, the absorbed entry whose range equals the union, if any. Saving
 * onto `sameAs` keeps that highlight's identity (a recolour).
 *
 * Cost is O(absorbed * saved) boundary comparisons, run once per settled
 * selection, never per handle move.
 */
export const planHighlightMerge = (selection, saved) => {
    if (!selection || selection.collapsed || !saved?.length) return null
    const pending = saved.filter(entry => entry?.id && entry.range && !entry.range.collapsed)
    const absorbed = []
    const union = selection.cloneRange()
    let grew = true
    while (grew && pending.length) {
        grew = false
        for (let i = pending.length - 1; i >= 0; i -= 1) {
            const entry = pending[i]
            if (!rangesIntersect(union, entry.range)) continue
            pending.splice(i, 1)
            absorbed.push(entry)
            if (compare(union, Range.START_TO_START, entry.range) === 1) {
                union.setStart(entry.range.startContainer, entry.range.startOffset)
            }
            if (compare(union, Range.END_TO_END, entry.range) === -1) {
                union.setEnd(entry.range.endContainer, entry.range.endOffset)
            }
            grew = true
        }
    }
    if (!absorbed.length) return null
    absorbed.sort((a, b) =>
        compare(a.range, Range.START_TO_START, b.range)
        || compare(a.range, Range.END_TO_END, b.range)
        || 0)
    return {
        range: union,
        absorbed,
        sameAs: absorbed.find(entry => sameBoundaries(entry.range, union)) ?? null,
    }
}

const BLOCK_DISPLAYS = new Set(['block', 'list-item', 'table', 'table-row', 'table-cell', 'flex', 'grid'])

const blockOf = (node, view, cache) => {
    const visited = []
    let block = null
    for (let element = node.parentElement; element; element = element.parentElement) {
        if (cache.has(element)) {
            block = cache.get(element)
            break
        }
        visited.push(element)
        const display = view?.getComputedStyle?.(element)?.display
        if (display && BLOCK_DISPLAYS.has(display)) {
            block = element
            break
        }
    }
    for (const element of visited) cache.set(element, block)
    return block
}

/**
 * Text of `range` with a line break where it crosses into another block, the
 * way `Selection.toString()` renders paragraphs (`Range.toString()` would
 * glue "end.Start"). Used for merged highlight text, which no live selection
 * covers. Each element's style is read at most once per call.
 */
export const rangeTextWithBlockBreaks = range => {
    if (!range || range.collapsed) return ''
    const doc = range.startContainer.ownerDocument ?? range.startContainer
    const view = doc.defaultView
    const root = range.commonAncestorContainer
    const walker = doc.createTreeWalker(
        root.nodeType === Node.TEXT_NODE ? root.parentNode : root,
        NodeFilter.SHOW_TEXT,
    )
    const blocks = new Map()
    let text = ''
    let previousBlock
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        if (!range.intersectsNode(node)) continue
        const start = node === range.startContainer ? range.startOffset : 0
        const end = node === range.endContainer ? range.endOffset : node.data.length
        if (end <= start) continue
        const block = blockOf(node, view, blocks)
        if (previousBlock !== undefined && block !== previousBlock) text += '\n'
        previousBlock = block
        text += node.data.slice(start, end)
    }
    return text
}
