import Panzoom from './vendor/panzoom.js'

const DOUBLE_TAP_MS = 280
const TAP_DISTANCE = 32
const DRAG_DISTANCE = 8

// Coordinates inside a fitted iframe are not viewport coordinates. Include
// ancestor transforms as well as the renderer's original page-fit scale.
const viewportPoint = (event, doc) => {
    const frame = doc?.defaultView?.frameElement
    if (!frame) return { clientX: event.clientX, clientY: event.clientY }
    const rect = frame.getBoundingClientRect()
    return {
        clientX: rect.left + event.clientX * rect.width / frame.clientWidth,
        clientY: rect.top + event.clientY * rect.height / frame.clientHeight,
    }
}

export function createComicZoom(stage, host, onTap, {
    hostTaps = false, pageTapZoneFraction = 0.3,
} = {}) {
    const listeners = new AbortController()
    const pointers = new Map()
    const documents = new Set()
    let active = false
    let disposed = false
    let pendingTap = null
    let frame = 0
    let suppressClickUntil = 0
    let compatibilityClickUntil = 0
    const zoom = Panzoom(stage, {
        noBind: true, minScale: 1, maxScale: 4, contain: 'outside',
        panOnlyWhenZoomed: true, cursor: '',
        // Reader owns gesture arbitration; Panzoom owns focal zoom and bounds.
        handleStartEvent: () => {},
        setTransform: (element, { x, y, scale }) => {
            if (!disposed) element.style.transform = `scale(${scale}) translate(${x}px, ${y}px)`
        },
    })
    const isZoomed = () => zoom.getScale() > 1.01
    const selectionActive = () => globalThis.__readflexImageAreaDraftActive === true
    const cancelTap = () => {
        if (pendingTap) clearTimeout(pendingTap.timer)
        pendingTap = null
    }
    const stop = event => {
        if (event.cancelable) event.preventDefault()
        event.stopImmediatePropagation()
    }
    // Screen deltas remain stable while the iframe itself is transformed.
    // Read its geometry only on pointer down, not once per animation frame.
    const asPointer = pointer => ({
        clientX: pointer.start.clientX + pointer.event.screenX - pointer.screenX,
        clientY: pointer.start.clientY + pointer.event.screenY - pointer.screenY,
        pointerId: pointer.event.pointerId, target: stage,
    })
    const flush = () => {
        cancelAnimationFrame(frame)
        frame = 0
        if (!active) return
        for (const pointer of pointers.values()) {
            if (!pointer.dirty) continue
            zoom.handleMove(asPointer(pointer))
            pointer.dirty = false
        }
    }
    const release = () => {
        cancelAnimationFrame(frame)
        frame = 0
        for (const pointer of pointers.values()) {
            zoom.handleUp({ pointerId: pointer.event.pointerId })
        }
        pointers.clear()
        active = false
    }
    const begin = () => {
        active = true
        cancelTap()
        for (const doc of documents) doc.__readflexCancelImageAreaPress?.()
        for (const pointer of pointers.values()) {
            zoom.handleDown({ ...pointer.start, pointerId: pointer.event.pointerId, target: stage })
            try { pointer.event.target?.setPointerCapture?.(pointer.event.pointerId) } catch { /* Pointer ended. */ }
        }
    }
    const bind = (target, doc = null) => {
        const options = { capture: true, passive: false, signal: listeners.signal }
        target.addEventListener('pointerdown', event => {
            if (event.button !== 0 || selectionActive()) return
            suppressClickUntil = 0
            const start = viewportPoint(event, doc)
            pointers.set(event.pointerId, { event, doc, start,
                screenX: event.screenX, screenY: event.screenY,
                started: performance.now(), moved: false, dirty: false })
            if (pointers.size > 1) {
                if (active) zoom.handleDown(asPointer(pointers.get(event.pointerId)))
                else begin()
                stop(event)
            }
        }, options)
        target.addEventListener('pointermove', event => {
            const pointer = pointers.get(event.pointerId)
            if (!pointer || selectionActive()) return
            pointer.event = event
            const moved = Math.hypot(event.screenX - pointer.screenX, event.screenY - pointer.screenY) > DRAG_DISTANCE
            pointer.moved ||= moved
            if (moved) cancelTap()
            if (!active && moved && isZoomed()) begin()
            if (!active) return
            pointer.dirty = true
            if (!frame) frame = requestAnimationFrame(flush)
            stop(event)
        }, options)
        const end = event => {
            const pointer = pointers.get(event.pointerId)
            if (!pointer) return
            if (active) {
                flush()
                zoom.handleUp({ pointerId: event.pointerId })
                pointers.delete(event.pointerId)
                // Rebase when a finger lifts so the remaining finger can pan.
                for (const remaining of pointers.values()) zoom.handleDown(asPointer(remaining))
                active = pointers.size > 0
                suppressClickUntil = performance.now() + 400
                stop(event)
            } else {
                pointers.delete(event.pointerId)
                if (event.type === 'pointerup' && event.pointerType === 'touch'
                    && !pointer.moved && !selectionActive()
                    && performance.now() - pointer.started < 500) {
                    // Use completed touches without waiting for compatibility
                    // clicks. iOS may forward these taps from the Flutter host.
                    pointer.event = event
                    const { clientX: x, clientY: y } = asPointer(pointer)
                    compatibilityClickUntil = performance.now() + 500
                    if (!hostTaps) onTap({ x, y })
                }
            }
            if (event.type === 'pointercancel') cancelTap()
        }
        target.addEventListener('pointerup', end, options)
        target.addEventListener('pointercancel', end, options)
        for (const type of ['touchstart', 'touchmove', 'touchend', 'touchcancel']) {
            target.addEventListener(type, event => {
                if (active || performance.now() < suppressClickUntil) stop(event)
                // The comic renderer owns scrolling/zoom; leave propagation
                // intact for page swipes and image-area long press.
                else if (!selectionActive() && event.cancelable) event.preventDefault()
            }, options)
        }
        target.addEventListener('click', event => {
            if (performance.now() < Math.max(suppressClickUntil, compatibilityClickUntil)) stop(event)
        }, options)
        target.addEventListener('dblclick', event => event.preventDefault(), options)
    }
    bind(host)
    const reset = () => {
        cancelTap()
        release()
        zoom.reset({ animate: false })
    }
    window.addEventListener('blur', () => {
        // Focusing a page iframe also blurs its parent window.
        if (!document.hasFocus()) { cancelTap(); release() }
    }, { signal: listeners.signal })
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) { cancelTap(); release() }
    }, { signal: listeners.signal })
    return {
        attach(doc) {
            if (documents.has(doc)) return
            documents.add(doc)
            doc.documentElement.style.touchAction = 'none'
            bind(doc.defaultView, doc)
        },
        get blocksPageSwipe() { return isZoomed() || active || performance.now() < suppressClickUntil },
        tapFromHost(point) {
            // Area editing owns its native touches, including taps on handles.
            if (hostTaps && !selectionActive()) onTap(point)
        },
        tap(point, singleTap) {
            if (disposed || active || performance.now() < suppressClickUntil) return
            // Edge navigation is never a zoom gesture. Only the centre waits
            // for a second tap; zoomed pages keep all taps out of page zones.
            const x = point.x / innerWidth
            if (!isZoomed() && (x <= pageTapZoneFraction || x >= 1 - pageTapZoneFraction)) {
                cancelTap()
                singleTap(point)
                return
            }
            const previous = pendingTap
            if (previous && Math.hypot(point.x - previous.point.x, point.y - previous.point.y) <= TAP_DISTANCE) {
                cancelTap()
                if (isZoomed()) zoom.reset({ animate: false })
                else zoom.zoomToPoint(2.5, { clientX: point.x, clientY: point.y })
                return
            }
            cancelTap()
            previous?.fire()
            const tapPoint = isZoomed() ? { x: innerWidth / 2, y: innerHeight / 2 } : point
            const fire = () => {
                if (!disposed && !selectionActive()) singleTap(tapPoint)
            }
            pendingTap = { point, fire,
                timer: setTimeout(() => {
                    pendingTap = null
                    fire()
                }, DOUBLE_TAP_MS) }
        },
        reset,
        destroy() {
            cancelTap()
            release()
            disposed = true
            listeners.abort()
            documents.clear()
            zoom.destroy()
        },
    }
}
