// Selection controls for Android and offscreen continuation on iOS.
// The selected text remains a native Range.
export function createSelectionContinuationHandles({ viewport, labels, getRange, rectFor, onStart, onMove, onKey, onEnd }) {
    const root = viewport.document.createElement('div')
    // Shadow children do not make :empty false. Exempt this UI host from
    // the reader's normalization of anonymous empty content containers.
    root.className = 'readflex-selection-handles'
    root.dataset.readflexSelectionHandles = ''
    root.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:2147483647;contain:layout style;'
    const shadow = root.attachShadow({ mode: 'open' })
    const style = viewport.document.createElement('style')
    style.textContent = `
      button { position:absolute; width:48px; height:48px; padding:0; border:0;
        margin:0; background:transparent; pointer-events:auto; touch-action:none;
        user-select:none; -webkit-user-select:none; -webkit-tap-highlight-color:transparent; }
      button::before { content:''; position:absolute; width:2px; height:var(--line-height);
        left:23px; top:var(--stem-top); background:Highlight; }
      button::after { content:''; position:absolute; width:20px; height:20px;
        left:14px; top:14px; border-radius:50%; background:Highlight;
        box-shadow:0 0 0 1px Canvas; }
      button:focus-visible { outline:2px solid Highlight; outline-offset:-4px; }
      button[hidden] { display:none; }
    `
    shadow.append(style)
    let active = null, frame = null, pending = null, enabled = false
    let magnifierVisible = false
    const magnify = point => {
        const visible = !!point
        if (!visible && !magnifierVisible) return
        magnifierVisible = visible
        const bridge = viewport.flutter_inappwebview
        try {
            bridge?._readerSelectionMagnifier?.(
                visible ? point.x / viewport.innerWidth : 0,
                visible ? point.y / viewport.innerHeight : 0, visible)
        } catch { /* Optional Android enhancement; selection must remain usable. */ }
    }
    const buttons = [false, true].map(end => {
        const button = viewport.document.createElement('button')
        button.type = 'button'
        button.dataset.endpoint = end ? 'end' : 'start'
        button.hidden = true
        button.addEventListener('pointerdown', event => {
            if (event.button !== 0 || active) return
            event.preventDefault()
            event.stopPropagation()
            active = { id: event.pointerId, button, initialEnd: end, liveEnd: end }
            button.setPointerCapture(event.pointerId)
            onStart(end)
        })
        button.addEventListener('pointermove', event => {
            if (active?.id !== event.pointerId) return
            event.preventDefault()
            pending = { x: event.clientX, y: event.clientY }
            if (frame == null) frame = viewport.requestAnimationFrame(() => { frame = null; flush() })
        })
        const finish = event => {
            if (active?.id !== event.pointerId) return
            event.preventDefault()
            if (event.type === 'pointerup') flush()
            pending = null
            if (frame != null) viewport.cancelAnimationFrame(frame)
            frame = null
            const id = active.id
            active = null
            magnify(null)
            if (button.hasPointerCapture(id)) button.releasePointerCapture(id)
            onEnd()
            render()
        }
        button.addEventListener('pointerup', finish)
        button.addEventListener('pointercancel', finish)
        button.addEventListener('lostpointercapture', finish)
        button.addEventListener('click', event => { event.preventDefault(); event.stopPropagation() })
        button.addEventListener('keydown', event => {
            if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Escape'].includes(event.key)) return
            event.preventDefault()
            event.stopPropagation()
            onKey(end, event.key)
            render()
        })
        shadow.append(button)
        return button
    })
    const flush = () => {
        if (!active || !pending) return
        const point = pending
        pending = null
        // Same-document article controls must not obscure caret hit testing.
        buttons.forEach(button => { button.style.pointerEvents = 'none' })
        try {
            const end = onMove(point)
            if (active) {
                active.liveEnd = end ?? active.liveEnd
                active.moved = true
            }
        }
        finally { buttons.forEach(button => { button.style.pointerEvents = '' }) }
        render(true)
    }
    const render = (magnifierUpdate = false) => {
        const range = enabled && getRange()
        let magnifierPoint = null
        buttons.forEach((button, index) => {
            const end = active && active.initialEnd !== active.liveEnd ? index === 0 : index === 1
            const rect = range && rectFor(range, end)
            button.hidden = !rect
            if (!rect) return
            button.setAttribute('aria-label', end ? labels.end : labels.start)
            const x = end ? rect.right : rect.left
            if (active?.button === button && active.moved) {
                magnifierPoint = { x, y: (rect.top + rect.bottom) / 2 }
            }
            const y = end ? rect.bottom + 10 : rect.top - 10
            button.style.left = `${Math.max(0, Math.min(viewport.innerWidth - 48, x - 24))}px`
            const top = Math.max(0, Math.min(viewport.innerHeight - 48, y - 24))
            button.style.top = `clamp(max(env(safe-area-inset-top, 0px), var(--rf-safe-area-top, 0px)),
                ${top}px, calc(100% - 48px - max(env(safe-area-inset-bottom, 0px), var(--rf-safe-area-bottom, 0px))))`
            button.style.setProperty('--line-height', `${rect.bottom - rect.top + 10}px`)
            button.style.setProperty('--stem-top', end ? `${14 - (rect.bottom - rect.top)}px` : '24px')
        })
        if (magnifierUpdate || !magnifierPoint) magnify(magnifierPoint)
    }
    viewport.document.body.append(root)
    return {
        show() { enabled = true; render() },
        refresh: render,
        hide() {
            enabled = false
            pending = null
            active = null
            magnify(null)
            if (frame != null) viewport.cancelAnimationFrame(frame)
            frame = null
            render()
        },
        dispose() { this.hide(); root.remove() },
    }
}
