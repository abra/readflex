// Touch event forwarding + gesture interceptor registry. Inspired by
// readest's split between iframe-side forwarding and app-side priority
// chain (apps/readest-app/src/app/reader/{utils/iframeEventHandlers,
// hooks/useIframeEvents,hooks/usePagination}.ts), simplified to a single
// in-WebView module since we don't ship a separate app frame to dispatch
// into — handlers register here directly.
//
// Why this exists: foliate-js' built-in gesture story is split between
// renderers — paginator.js owns its own swipe/scroll/snap, fixed-layout.js
// has nothing. Adding new gestures (pinch-zoom, double-tap, tap-zones)
// inside each renderer would multiply patches across foliate-js source.
// Instead, every iframe load goes through `attachGestures(doc)` (called
// from book.js' Reader#onLoad) and any feature can call
// `registerGesture(...)` to plug into the same touch stream.
//
// Lifecycle:
//   1. `attachGestures(doc)` — call once per iframe contentDocument (each
//      time a new chapter / spread / image loads). Idempotent per-doc.
//   2. `registerGesture(name, predicate, handler, priority)` — add a
//      gesture handler. On every phase ('start' | 'move' | 'end'), the
//      registry walks handlers from highest to lowest priority; for each,
//      if `predicate(detail)` returns truthy, `handler(detail)` runs.
//      Returning `true` from a handler consumes the gesture and
//      short-circuits the rest of the chain.
//   3. `unregisterGesture(name)` / `clearGestures()` — cleanup.
//
// `detail` passed to predicate/handler:
//   { phase, x, y, deltaX, deltaY, deltaT }
// where deltaX/deltaY are signed pixels from touchstart, deltaT is ms.

const registry = []
const states = new WeakMap()

const dispatch = (detail) => {
  const ordered = [...registry].sort((a, b) => b.priority - a.priority)
  for (const entry of ordered) {
    try {
      if (entry.predicate(detail) && entry.handler(detail) === true) return true
    } catch (e) {
      console.error('readflex_gestures:', entry.name, e)
    }
  }
  return false
}

export const attachGestures = (doc) => {
  if (!doc || states.has(doc)) return
  states.set(doc, null)

  doc.addEventListener(
    'touchstart',
    (e) => {
      // Multi-touch (pinch / zoom) — defer to a future pinch-zoom gesture
      // by recording no state. Keeps single-finger swipes clean.
      if (e.touches.length !== 1) {
        states.set(doc, null)
        return
      }
      const t = e.touches[0]
      const state = {
        startX: t.clientX,
        startY: t.clientY,
        startTime: Date.now(),
      }
      states.set(doc, state)
      dispatch({
        phase: 'start',
        x: t.clientX,
        y: t.clientY,
        deltaX: 0,
        deltaY: 0,
        deltaT: 0,
      })
    },
    { passive: true },
  )

  doc.addEventListener(
    'touchmove',
    (e) => {
      const state = states.get(doc)
      if (!state || e.touches.length !== 1) return
      const t = e.touches[0]
      dispatch({
        phase: 'move',
        x: t.clientX,
        y: t.clientY,
        deltaX: t.clientX - state.startX,
        deltaY: t.clientY - state.startY,
        deltaT: Date.now() - state.startTime,
      })
    },
    { passive: true },
  )

  doc.addEventListener(
    'touchend',
    (e) => {
      const state = states.get(doc)
      if (!state) return
      const t = e.changedTouches[0]
      states.set(doc, null)
      dispatch({
        phase: 'end',
        x: t.clientX,
        y: t.clientY,
        deltaX: t.clientX - state.startX,
        deltaY: t.clientY - state.startY,
        deltaT: Date.now() - state.startTime,
      })
    },
    { passive: true },
  )

  doc.addEventListener(
    'touchcancel',
    () => {
      states.set(doc, null)
    },
    { passive: true },
  )
}

export const registerGesture = (name, predicate, handler, priority = 0) => {
  unregisterGesture(name)
  registry.push({ name, predicate, handler, priority })
}

export const unregisterGesture = (name) => {
  const idx = registry.findIndex((e) => e.name === name)
  if (idx >= 0) registry.splice(idx, 1)
}

export const clearGestures = () => {
  registry.length = 0
}
