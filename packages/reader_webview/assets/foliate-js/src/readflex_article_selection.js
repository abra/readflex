import { createSelectionContinuationHandles } from './readflex_selection_handles.js'
import { installCustomSelectionStart } from './readflex_selection_start.js'
import { selectionEndpointRect } from './readflex_selection_navigation.js'

const boundary = (range, end) => ({
    node: end ? range.endContainer : range.startContainer,
    offset: end ? range.endOffset : range.startOffset,
})
const sameRange = (a, b) => a && b && a.startContainer === b.startContainer &&
    a.startOffset === b.startOffset && a.endContainer === b.endContainer && a.endOffset === b.endOffset

function createContentLock(root) {
    const doc = root.ownerDocument, win = doc.defaultView
    let restore = null
    return {
        lock() {
            if (restore) return
            const properties = [[doc.body, 'height'], [root, 'position'], [root, 'top']]
            restore = properties.map(([node, name]) => ({ node, name,
                value: node.style.getPropertyValue(name), priority: node.style.getPropertyPriority(name) }))
            // Chromium scrolls native handles before JS scroll listeners run.
            // Pin the content without moving text nodes or changing scroll extent.
            const height = doc.documentElement.scrollHeight, y = win.scrollY
            doc.body.style.height = `${height}px`
            root.style.position = 'fixed'
            root.style.top = `${-y}px`
        },
        unlock() {
            if (!restore) return
            for (const { node, name, value, priority } of restore) {
                if (value) node.style.setProperty(name, value, priority)
                else node.style.removeProperty(name)
            }
            restore = null
        },
    }
}

// An edge control represents an offscreen endpoint, not a new text boundary.
export function articleContinuationRect(rect, height) {
    if (!rect || (rect.bottom > 0 && rect.top < height)) return null
    const top = rect.bottom <= 0 ? 24 : Math.max(24, height - 48)
    return { ...rect, top, bottom: top + 16 }
}

export function installArticleSelection({ doc, root = doc.body,
    onAdjusting = () => {}, onSettled = () => {},
    handleLabels = { start: 'Selection start', end: 'Selection end' },
    customHandles = false, lockContentWhileSelecting = false }) {
    const win = doc.defaultView
    const listeners = new AbortController()
    const options = { capture: true, passive: true, signal: listeners.signal }
    let position = win.scrollY, unrestrictedUntil = 0, previous = null
    let touch = null, timer = null, frame = null, controls = null, fixed = null
    let adjusting = false, dragging = false, custom = false, disposed = false
    const removeSelectionStart = customHandles ? installCustomSelectionStart({
        doc, root, isActive: () => !dragging,
    }) : null
    const contentLock = lockContentWhileSelecting ? createContentLock(root) : null
    const range = () => {
        const selection = doc.getSelection()
        if (!selection?.rangeCount || selection.isCollapsed) return null
        const value = selection.getRangeAt(0)
        return root.contains(value.commonAncestorContainer) ? value : null
    }
    const isContinuationEvent = event => event.composedPath().some(node => node.dataset?.readflexSelectionHandles != null)
    const isHandlePoint = (value, point) => [false, true].some(end => {
        const rect = selectionEndpointRect(value, end, win)
        // Android places both native knobs below the line; iOS places
        // the start knob above it. Do not confuse either with a swipe.
        return rect && [rect.top - 8, rect.bottom + 8].some(y =>
            Math.hypot(point.clientX - (end ? rect.right : rect.left), point.clientY - y) <= 32)
    })
    const phase = value => {
        if (adjusting === value) return
        adjusting = value
        onAdjusting(value)
    }
    const updateContentLock = () => {
        if (!contentLock) return
        const value = range()
        // With no native endpoint onscreen there is nothing to drag. Leaving
        // fixed content here can prevent Chromium from latching the next swipe.
        if (value && (dragging || [false, true].some(end => selectionEndpointRect(value, end, win)))) {
            contentLock.lock()
        } else contentLock.unlock()
    }
    const settle = () => {
        clearTimeout(timer)
        timer = setTimeout(() => {
            timer = null
            if (disposed || dragging || touch) return
            updateContentLock()
            onSettled()
            phase(false)
            refresh()
        }, 160)
    }
    const allowScroll = () => {
        contentLock?.unlock()
        unrestrictedUntil = win.performance.now() + 700
    }
    const endpointRect = (value, end) => selectionEndpointRect(value, end, win, true)
    const controlRect = (value, end) => {
        const rect = endpointRect(value, end)
        const edge = articleContinuationRect(rect, win.innerHeight)
        if (edge) {
            // When both endpoints leave through the same edge, expose the
            // nearer boundary only, avoiding two overlapping proxy handles.
            const other = endpointRect(value, !end)
            if ((!end && rect.bottom <= 0 && other?.bottom <= 0) ||
                (end && rect.top >= win.innerHeight && other?.top >= win.innerHeight)) return null
            return edge
        }
        return dragging || customHandles ? rect : null
    }
    const refresh = () => {
        const value = range()
        if (!value) { controls?.hide(); return }
        if (!controls && !controlRect(value, false) && !controlRect(value, true)) return
        controls ??= createSelectionContinuationHandles({
            viewport: win, labels: handleLabels, getRange: range, rectFor: controlRect,
            onStart: end => {
                const value = range()
                if (!value) return
                fixed = boundary(value, !end)
                dragging = true
                contentLock?.lock()
                unrestrictedUntil = 0
                clearTimeout(timer)
            },
            onMove: point => {
                if (!fixed?.node.isConnected) return
                const x = Math.max(1, Math.min(win.innerWidth - 1, point.x))
                const y = Math.max(1, Math.min(win.innerHeight - 1, point.y))
                const caret = doc.caretPositionFromPoint?.(x, y)
                const probe = caret ? null : doc.caretRangeFromPoint?.(x, y)
                const node = caret?.offsetNode ?? probe?.startContainer
                const offset = caret?.offset ?? probe?.startOffset
                if (!node || !root.contains(node) || (fixed.node === node && fixed.offset === offset)) return
                // Keep the Flutter overlay stable until WebView owns the drag.
                // Removing it during pointerdown can interrupt hybrid input.
                phase(true)
                doc.getSelection().setBaseAndExtent(fixed.node, fixed.offset, node, offset)
                custom = true
                const changed = range()
                previous = changed?.cloneRange() ?? null
                return changed ? changed.startContainer === fixed.node && changed.startOffset === fixed.offset : undefined
            },
            onEnd: () => { dragging = false; fixed = null; settle() },
            onKey: (end, key) => {
                const selection = doc.getSelection(), value = range()
                if (key === 'Escape') { selection.removeAllRanges(); cancel(); return }
                if (!value || !selection.modify) return
                const origin = boundary(value, !end), target = boundary(value, end)
                selection.setBaseAndExtent(origin.node, origin.offset, target.node, target.offset)
                selection.modify('extend', key.slice(5).toLowerCase(),
                    key === 'ArrowUp' || key === 'ArrowDown' ? 'line' : 'character')
                custom = true
                previous = range()?.cloneRange() ?? null
                phase(true)
                settle()
            },
        })
        controls.show()
    }
    const scheduleRefresh = () => {
        if (frame != null) return
        frame = win.requestAnimationFrame(() => { frame = null; refresh() })
    }
    const cancel = () => {
        touch = null
        dragging = false
        fixed = null
        unrestrictedUntil = 0
        position = win.scrollY
        clearTimeout(timer)
        timer = null
        if (frame != null) win.cancelAnimationFrame(frame)
        frame = null
        controls?.hide()
        contentLock?.unlock()
        phase(false)
    }
    doc.addEventListener('selectionchange', () => {
        const value = range()
        if (!value) { previous = null; custom = false; cancel(); return }
        // Continuation updates already record their range and own settling.
        if (custom && sameRange(previous, value)) return
        if (!previous) position = win.scrollY
        if (!sameRange(previous, value)) {
            unrestrictedUntil = 0
            if (touch) touch.handle = true
            if (!dragging) custom = false
            contentLock?.lock()
        }
        previous = value.cloneRange()
        if (customHandles && !custom) {
            custom = true
            refresh()
        }
        phase(true)
        settle()
    }, options)
    doc.addEventListener('pointerdown', event => {
        if (!contentLock || isContinuationEvent(event)) return
        const value = range()
        // Unlock before touchstart so Chromium can latch a normal scroll target.
        if (value && (customHandles || !isHandlePoint(value, event))) contentLock.unlock()
    }, options)
    doc.addEventListener('touchstart', event => {
        if (isContinuationEvent(event)) return
        const value = range(), first = event.touches[0]
        if (!value || !first) return
        if (event.touches.length !== 1) { cancel(); allowScroll(); return }
        const handle = !customHandles && isHandlePoint(value, first)
        touch = { x: first.clientX, y: first.clientY, handle, scrolling: false }
        if (!handle) contentLock?.unlock()
        unrestrictedUntil = 0
        clearTimeout(timer)
        phase(true)
    }, options)
    doc.addEventListener('touchmove', event => {
        const first = event.touches[0]
        if (!touch || !first || touch.handle || dragging) return
        if (Math.hypot(first.clientX - touch.x, first.clientY - touch.y) >= 8) touch.scrolling = true
    }, options)
    for (const type of ['touchend', 'touchcancel']) doc.addEventListener(type, () => {
        if (touch?.scrolling && !touch.handle) allowScroll()
        touch = null
        if (range()) settle()
    }, options)
    doc.addEventListener('wheel', allowScroll, options)
    doc.addEventListener('keydown', event => {
        if (['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End', ' '].includes(event.key) &&
            !isContinuationEvent(event)) allowScroll()
    }, options)
    win.addEventListener('scroll', () => {
        if (!range() || (!dragging && (touch?.scrolling && !touch.handle || win.performance.now() < unrestrictedUntil))) {
            position = win.scrollY
            if (range()) { phase(true); settle(); scheduleRefresh() }
            return
        }
        // Native handle events may never reach JS. Selection-induced scrolling
        // is locked unless an independent content gesture granted permission.
        if (Math.abs(win.scrollY - position) >= 1) {
            win.scrollTo({ left: win.scrollX, top: position, behavior: 'instant' })
            position = win.scrollY
        }
    }, options)
    win.addEventListener('blur', cancel, options)
    win.addEventListener('focus', () => {
        position = win.scrollY
        updateContentLock()
        scheduleRefresh()
    }, options)
    win.addEventListener('resize', () => { cancel(); scheduleRefresh() }, options)
    doc.addEventListener('visibilitychange', () => { if (doc.hidden) cancel() }, options)
    const dispose = () => {
        if (disposed) return
        disposed = true
        cancel()
        controls?.dispose()
        removeSelectionStart?.()
        listeners.abort()
    }
    win.addEventListener('pagehide', event => { if (event.persisted) cancel(); else dispose() }, options)
    return { allowScroll, dispose, get isAdjusting() { return adjusting } }
}
