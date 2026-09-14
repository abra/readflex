import { createSelectionContinuationHandles } from './readflex_selection_handles.js'
import { installCustomSelectionStart } from './readflex_selection_start.js'

const samePoint = (a, b) => a && b && a.node === b.node && a.offset === b.offset
const boundary = (range, end) => ({
    node: end ? range.endContainer : range.startContainer,
    offset: end ? range.endOffset : range.startOffset,
})
const snapshot = range => range && ({ start: boundary(range, false), end: boundary(range, true) })
const sameRange = (a, b) => a && b && samePoint(a.start, b.start) && samePoint(a.end, b.end)
const liveRange = doc => {
    const selection = doc.getSelection()
    return selection?.rangeCount && !selection.isCollapsed ? selection.getRangeAt(0) : null
}

export function fixedSelectionBoundary(previous, current, fixed) {
    if (!previous || !current) return null
    if (sameRange(previous, current)) return fixed
    // Native start-handle drags can retain forward anchor/focus order. The
    // unchanged DOM endpoint, including after crossing, is authoritative.
    const shared = [current.start, current.end].filter(point =>
        samePoint(point, previous.start) || samePoint(point, previous.end))
    return shared.length === 1 ? shared[0] : null
}

export function selectionNavigationDirection(start, end, { vertical, rtl, width, height }) {
    const dx = end.x - start.x, dy = end.y - start.y
    const along = vertical ? dy : dx, across = vertical ? dx : dy
    const sign = !vertical && rtl ? -1 : 1
    if (Math.abs(along) >= 48 && Math.abs(along) >= Math.abs(across) * 1.5) return -Math.sign(along) * sign
    if (Math.hypot(dx, dy) > 8) return 0
    const fraction = vertical ? start.y / height : start.x / width
    return fraction < 0.2 ? -sign : fraction > 0.8 ? sign : 0
}

const segmenter = typeof Intl.Segmenter === 'function'
    ? new Intl.Segmenter(undefined, { granularity: 'grapheme' }) : null

const frameGeometry = doc => {
    const frame = doc.defaultView.frameElement
    const rect = frame?.getBoundingClientRect()
    return rect ? { x: rect.left, y: rect.top,
        sx: rect.width / (frame.clientWidth || rect.width || 1),
        sy: rect.height / (frame.clientHeight || rect.height || 1) }
        : { x: 0, y: 0, sx: 1, sy: 1 }
}
const mapPoint = (point, frame) => ({ x: frame.x + point.x * frame.sx, y: frame.y + point.y * frame.sy })
const mapRect = (rect, frame) => ({
    left: frame.x + rect.left * frame.sx, right: frame.x + rect.right * frame.sx,
    top: frame.y + rect.top * frame.sy, bottom: frame.y + rect.bottom * frame.sy,
})
const visibleRect = (rect, viewport) => rect.bottom > 0 && rect.top < viewport.innerHeight &&
    rect.right > 0 && rect.left < viewport.innerWidth && rect.bottom > rect.top

// Bound traversal by nodes, not chapter length. Element offset zero at a page
// end belongs BEFORE that element; searching only its children loses the handle.
function adjacentText(point, backwards, root) {
    let { node, offset } = point
    const child = backwards ? 'lastChild' : 'firstChild'
    const sibling = backwards ? 'previousSibling' : 'nextSibling'
    let steps = 0
    if (node.nodeType === 3 && (backwards ? offset > 0 : offset < node.length)) return point
    const inside = node.nodeType === 1 && node.childNodes[backwards ? offset - 1 : offset]
    if (inside) node = inside
    else {
        while (node && node !== root && !node[sibling] && steps++ < 64) node = node.parentNode
        node = node && node !== root ? node[sibling] : null
    }
    for (; node && steps++ < 64;) {
        if (node.nodeType === 3 && node.data.trim()) return { node, offset: backwards ? node.length : 0 }
        if (node[child] && !['SCRIPT', 'STYLE'].includes(node.nodeName)) node = node[child]
        else {
            while (node && node !== root && !node[sibling] && steps++ < 64) node = node.parentNode
            node = node && node !== root ? node[sibling] : null
        }
    }
    return null
}

export function selectionPageEndpoint(range, direction, viewport = window) {
    const backwards = direction < 0
    const doc = range.startContainer.ownerDocument
    const frame = frameGeometry(doc)
    let point = boundary(range, backwards)
    for (let attempt = 0; attempt < 64; attempt++) {
        point = adjacentText(point, backwards, doc.body)
        if (!point) return null
        const index = backwards ? point.offset - 1 : point.offset
        const segment = segmenter?.segment(point.node.data).containing(index)
        if (!segment) return point
        const probe = doc.createRange()
        probe.setStart(point.node, segment.index)
        probe.setEnd(point.node, segment.index + segment.segment.length)
        // Retain a complete visible grapheme so native WebKit shows the handle.
        const rect = mapRect(probe.getBoundingClientRect(), frame)
        const inside = probe.compareBoundaryPoints(Range.START_TO_START, range) >= 0 &&
            probe.compareBoundaryPoints(Range.END_TO_END, range) <= 0
        if (inside && segment.segment.trim() && visibleRect(rect, viewport)) {
            return { node: point.node, offset: backwards ? segment.index : segment.index + segment.segment.length }
        }
        point = { node: point.node, offset: backwards ? segment.index : segment.index + segment.segment.length }
    }
    return null
}

export function selectionEndpointRect(range, end, viewport = window, includeOffscreen = false) {
    const doc = range.startContainer.ownerDocument
    const probe = range.cloneRange()
    probe.collapse(!end)
    let rect = probe.getBoundingClientRect()
    if (!rect.height) {
        const point = adjacentText(boundary(range, end), end, doc.body)
        if (point) {
            const start = Math.max(0, Math.min(point.node.length - 1, point.offset - (end ? 1 : 0)))
            probe.setStart(point.node, start)
            probe.setEnd(point.node, start + 1)
            rect = probe.getBoundingClientRect()
        }
    }
    const mapped = mapRect(rect, frameGeometry(doc))
    return (includeOffscreen && rect.height > 0) || visibleRect(mapped, viewport) ? mapped : null
}

export function selectionViewportPosition(range, viewport = window) {
    if (!range) return null
    const selection = range.startContainer.ownerDocument.getSelection()
    const backwards = selection.focusNode === range.startContainer && selection.focusOffset === range.startOffset
    const rect = selectionEndpointRect(range, !backwards, viewport) ?? selectionEndpointRect(range, backwards, viewport)
    if (!rect) return null
    const clamp = n => Math.min(1, Math.max(0, n))
    return { left: clamp(rect.left / viewport.innerWidth), right: clamp(rect.right / viewport.innerWidth),
        top: clamp(rect.top / viewport.innerHeight), bottom: clamp(rect.bottom / viewport.innerHeight) }
}

export function installSelectionNavigation({ doc, viewport = window, navigation, onAdjusting, onSettled, isActive,
    customHandles = false, handleLabels = { start: 'Selection start', end: 'Selection end' } }) {
    let previous = null, fixed = null, pointer = null, timer = null, frame = null
    let adjusting = false, turning = false, disposed = false, generation = 0, consumeClick = false
    let controls = null, draggingControl = false
    const listeners = []
    // Android's long-click timer may fire before a delayed native MOVE arrives.
    if (customHandles) listeners.push(installCustomSelectionStart({
        doc, viewport, isActive: () => isActive() && !draggingControl,
    }))
    const listen = (target, name, callback, passive = true) => {
        target.addEventListener(name, callback, { capture: true, passive })
        listeners.push(() => target.removeEventListener(name, callback, true))
    }
    const phase = value => {
        if (adjusting === value) return
        adjusting = value
        onAdjusting(value)
    }
    const clearTimer = () => { clearTimeout(timer); timer = null }
    const observe = () => {
        const current = snapshot(liveRange(doc))
        const unchanged = fixedSelectionBoundary(previous, current, fixed)
        if (current) {
            if (previous && !unchanged) controls?.hide()
            fixed = unchanged ?? current.start
        } else if (!pointer && !draggingControl) { fixed = null; controls?.hide() }
        if (current || (!pointer?.handle && !draggingControl)) previous = current
        return current
    }
    const settle = () => {
        clearTimer()
        timer = setTimeout(() => {
            timer = null
            if (disposed || pointer || draggingControl || turning || !isActive()) return
            adjusting = false
            onSettled()
            onAdjusting(false)
            if (customHandles && liveRange(doc)) showControls()
            else controls?.refresh()
        }, 160)
    }
    const turn = async (direction, origin = fixed) => {
        if (turning || !origin || !navigation.state()) return
        const version = generation
        turning = true
        phase(true)
        try {
            if (!await navigation.turnPage(direction) || disposed || !isActive() || version !== generation) return
            const target = navigation.target(direction)
            if (!target || !origin.node.isConnected || !target.node.isConnected) return
            doc.getSelection().setBaseAndExtent(origin.node, origin.offset, target.node, target.offset)
            previous = snapshot(liveRange(doc))
            fixed = origin
            if (customHandles) showControls()
        } finally {
            turning = false
            if (!disposed && isActive()) settle()
        }
    }
    const showControls = () => {
        controls ??= createSelectionContinuationHandles({
            viewport, labels: handleLabels, getRange: () => liveRange(doc),
            rectFor: (range, end) => selectionEndpointRect(range, end, viewport),
            onStart: end => {
                const range = liveRange(doc)
                if (!range) return
                fixed = boundary(range, !end)
                draggingControl = true
                generation++
                clearTimer()
            },
            onMove: point => {
                if (!fixed?.node.isConnected || !isActive()) return
                const frame = frameGeometry(doc)
                const x = (Math.max(1, Math.min(viewport.innerWidth - 1, point.x)) - frame.x) / frame.sx
                const y = (Math.max(1, Math.min(viewport.innerHeight - 1, point.y)) - frame.y) / frame.sy
                const caret = doc.caretPositionFromPoint?.(x, y)
                const range = caret ? null : doc.caretRangeFromPoint?.(x, y)
                const node = caret?.offsetNode ?? range?.startContainer
                const offset = caret?.offset ?? range?.startOffset
                if (!node || !doc.body.contains(node) || samePoint(fixed, { node, offset })) return
                // Let WebView acquire pointer capture before hiding Flutter's menu.
                phase(true)
                doc.getSelection().setBaseAndExtent(fixed.node, fixed.offset, node, offset)
                previous = snapshot(liveRange(doc))
                return previous ? samePoint(previous.start, fixed) : undefined
            },
            onEnd: () => { draggingControl = false; settle() },
            onKey: (end, key) => {
                const selection = doc.getSelection()
                if (key === 'Escape') { selection.removeAllRanges(); cancel(); return }
                const range = liveRange(doc)
                if (!range || !selection.modify) return
                const origin = boundary(range, !end), target = boundary(range, end)
                selection.setBaseAndExtent(origin.node, origin.offset, target.node, target.offset)
                selection.modify('extend', key.slice(5).toLowerCase(),
                    key === 'ArrowUp' || key === 'ArrowDown' ? 'line' : 'character')
                const changed = liveRange(doc)
                if (!changed || !selectionEndpointRect(changed, end, viewport)) {
                    selection.setBaseAndExtent(origin.node, origin.offset, target.node, target.offset)
                }
                previous = snapshot(liveRange(doc))
                fixed = origin
                phase(true)
                settle()
            },
        })
        controls.show()
    }
    const updatePoint = () => {
        if (!pointer?.pending) return
        pointer.point = pointer.outer ? pointer.pending : mapPoint(pointer.pending, frameGeometry(doc))
        pointer.pending = null
    }
    const schedule = () => {
        if (frame != null) return
        frame = viewport.requestAnimationFrame(() => { frame = null; updatePoint() })
    }
    const cancel = () => {
        generation++
        pointer = null
        if (frame != null) viewport.cancelAnimationFrame(frame)
        frame = null
        clearTimer()
        draggingControl = false
        controls?.hide()
        phase(false)
    }
    const start = (event, outer = false) => {
        if (!isActive() || disposed) return
        if (event.touches.length !== 1) { cancel(); return }
        if (pointer) return
        const range = liveRange(doc)
        const config = navigation.state()
        if (!range || !config) return
        observe()
        const touch = event.touches[0]
        const local = { x: touch.clientX, y: touch.clientY }
        const point = outer ? local : mapPoint(local, frameGeometry(doc))
        const distances = [false, true].map(end => {
            const rect = selectionEndpointRect(range, end, viewport)
            return rect ? Math.hypot(point.x - (end ? rect.right : rect.left),
                point.y - (end ? rect.bottom + 8 : rect.top - 8)) : Infinity
        })
        const handle = !customHandles && Math.min(...distances) <= 44
        if (handle) fixed = boundary(range, distances[0] < distances[1])
        pointer = { id: touch.identifier, origin: point, point, config, fixed, outer,
            range: snapshot(range), handle, started: Date.now() }
        consumeClick = false
        generation++
        clearTimer()
        phase(true)
    }
    const finish = event => {
        if (!pointer) return
        updatePoint()
        const drag = pointer
        pointer = null
        if (frame != null) viewport.cancelAnimationFrame(frame)
        frame = null
        const current = navigation.state()
        const config = { ...drag.config, width: viewport.innerWidth, height: viewport.innerHeight }
        const direction = !drag.handle && !turning && current?.pageKey === drag.config.pageKey &&
            current?.vertical === drag.config.vertical && current?.rtl === drag.config.rtl &&
            liveRange(doc) ? selectionNavigationDirection(drag.origin, drag.point, config) : 0
        const tap = Math.hypot(drag.origin.x - drag.point.x, drag.origin.y - drag.point.y) <= 8
        if (direction && (!tap || Date.now() - drag.started < 500)) {
            event.preventDefault()
            consumeClick = true
            void turn(direction, drag.fixed).catch(error => console.error('Selection navigation failed', error))
        } else settle()
    }
    const move = event => {
        if (!pointer) return
        if (event.touches.length !== 1) { cancel(); return }
        const touch = event.touches[0]
        if (touch.identifier !== pointer.id) return
        pointer.pending = { x: touch.clientX, y: touch.clientY }
        if (!pointer.handle) event.preventDefault()
        schedule()
    }
    const consume = event => {
        if (!consumeClick) return
        consumeClick = false
        event.preventDefault()
        event.stopImmediatePropagation()
    }
    // Iframe events do not bubble into the paginator. Its margins need the
    // same gesture arbitration, in viewport rather than chapter coordinates.
    const host = doc.defaultView.frameElement?.getRootNode()?.host
    for (const target of [doc, host].filter(Boolean)) {
        listen(target, 'touchstart', event => start(event, target === host))
        listen(target, 'touchmove', move, false)
        listen(target, 'touchend', finish, false)
        listen(target, 'touchcancel', () => {
            // Android cancels the original touch stream when long press starts
            // native selection. This is not a cancellation of the selected text.
            const keepSelection = customHandles && !pointer && !draggingControl && liveRange(doc)
            cancel()
            if (keepSelection) settle()
        })
        listen(target, 'click', consume, false)
    }
    listen(doc, 'selectionchange', () => {
        if (!isActive() || (!customHandles && !navigation.state())) return
        if (customHandles && sameRange(previous, snapshot(liveRange(doc)))) return
        const current = observe()
        if (!current) {
            if (pointer?.handle || draggingControl) return
            cancel()
            return
        }
        if (pointer && !sameRange(pointer.range, current)) {
            pointer.handle = true
            pointer.fixed = fixed
        }
        if (customHandles && !draggingControl) {
            showControls()
        }
        phase(true)
        if (!pointer && !draggingControl) settle()
    })
    listen(viewport, 'blur', cancel)
    const resumeControls = () => {
        if (customHandles && isActive() && liveRange(doc)) { showControls(); settle() }
    }
    listen(viewport, 'focus', resumeControls)
    listen(viewport, 'resize', () => { cancel(); resumeControls() })
    listen(viewport, 'pagehide', cancel)
    listen(viewport.document, 'visibilitychange', () => {
        if (viewport.document.hidden) cancel()
        else resumeControls()
    })
    return {
        get isAdjusting() { return adjusting },
        cancel,
        relocated() {
            if (!customHandles && !navigation.state()) { cancel(); return }
            if (liveRange(doc)) { phase(true); if (!pointer && !turning) settle() }
        },
        dispose() { cancel(); disposed = true; controls?.dispose(); listeners.forEach(remove => remove()) },
    }
}
