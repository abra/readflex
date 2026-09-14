// Android recognizes long press; the reader owns the resulting DOM selection.
// Selection.modify uses the browser's word boundaries, including inline nodes
// and languages without spaces. No chapter-wide text or geometry scan is needed.
export function selectWordAtPoint(doc, x, y, root = doc.body) {
    const caret = doc.caretPositionFromPoint?.(x, y)
    const probe = caret ? null : doc.caretRangeFromPoint?.(x, y)
    const node = caret?.offsetNode ?? probe?.startContainer
    const offset = caret?.offset ?? probe?.startOffset
    const selection = doc.getSelection()
    if (node?.nodeType !== 3 || !root.contains(node) || !selection?.modify) return false
    const glyph = doc.createRange()
    let hit = null
    for (let index of [offset, offset - 1]) {
        if (index < 0 || index >= node.length) continue
        const unit = node.data.charCodeAt(index)
        if (index > 0 && unit >= 0xDC00 && unit <= 0xDFFF) index--
        const character = String.fromCodePoint(node.data.codePointAt(index))
        if (!/[\p{L}\p{N}\p{M}]/u.test(character)) continue
        glyph.setStart(node, index)
        glyph.setEnd(node, index + character.length)
        const rect = glyph.getBoundingClientRect()
        if (x >= rect.left - 1 && x <= rect.right + 1 && y >= rect.top && y <= rect.bottom) {
            hit = index
            break
        }
    }
    if (hit == null) return false
    selection.setBaseAndExtent(node, hit, node, hit)
    selection.modify('move', 'forward', 'character')
    selection.modify('move', 'backward', 'word')
    selection.modify('extend', 'forward', 'word')
    return !selection.isCollapsed
}

export function installCustomSelectionStart({ doc, root = doc.body, viewport = doc.defaultView, isActive = () => true }) {
    const select = event => {
        if (!isActive()) return
        const { x, y } = event.detail ?? {}
        if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || x > 1 || y < 0 || y > 1) return
        const frame = doc.defaultView.frameElement
        const rect = frame?.getBoundingClientRect()
        const localX = rect ? (x * viewport.innerWidth - rect.left) * frame.clientWidth / rect.width : x * viewport.innerWidth
        const localY = rect ? (y * viewport.innerHeight - rect.top) * frame.clientHeight / rect.height : y * viewport.innerHeight
        if (localX < 0 || localY < 0 || localX >= doc.defaultView.innerWidth || localY >= doc.defaultView.innerHeight) return
        selectWordAtPoint(doc, localX, localY, root)
    }
    viewport.addEventListener('readflex-long-press', select)
    return () => viewport.removeEventListener('readflex-long-press', select)
}
