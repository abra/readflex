import { ACTIVE_SEARCH_HIGHLIGHT_COLOR } from './readflex_shell_constants.js'
export { ACTIVE_SEARCH_HIGHLIGHT_COLOR }
const SVG_NS = 'http://www.w3.org/2000/svg'

// Project only fragments inside the viewport's covered band, never a match
// on a different page. Merging keeps multi-line/RTL ranges from stacking bars.
export const occludedSearchSpans = (rects, { width, height }, bottomInset) => {
    if (!(width > 0 && height > 0 && bottomInset > 0 && bottomInset < 1)) return []
    const edge = height * (1 - bottomInset)
    const intervals = []
    for (const { left, top, right, bottom } of rects) {
        if (![left, top, right, bottom].every(Number.isFinite)) continue
        if (right <= left || bottom <= top || bottom <= edge || top >= height) continue
        const start = Math.max(0, left)
        const end = Math.min(width, right)
        if (end > start) intervals.push({ left: start, right: end })
    }
    intervals.sort((a, b) => a.left - b.left)
    const merged = []
    for (const interval of intervals) {
        const previous = merged.at(-1)
        if (previous && interval.left <= previous.right)
            previous.right = Math.max(previous.right, interval.right)
        else merged.push(interval)
    }
    return merged.map(({ left, right }) => ({ left, width: right - left }))
}

/** Paints an inert edge marker without changing content geometry or selection.
 * Geometry stays in the WebView; Flutter sends only the covered height ratio.
 */
export class SearchOcclusionIndicator {
    #getRects
    #scrollTarget
    #resizeTarget
    #inset = 0
    #frame = null
    #observer = null
    #element = null
    #signature = ''
    #destroyed = false

    constructor({ getRects, scrollTarget = window, resizeTarget = document.documentElement }) {
        this.#getRects = getRects
        this.#scrollTarget = scrollTarget
        this.#resizeTarget = resizeTarget
    }

    setBottomInset(value) {
        if (this.#destroyed) return
        const next = Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0
        if (next === this.#inset) return
        const wasActive = this.#inset > 0
        this.#inset = next
        if (!next) {
            this.#stop()
            return
        }
        if (!wasActive) {
            window.addEventListener('resize', this.invalidate)
            window.addEventListener('scroll', this.invalidate, { capture: true, passive: true })
            if (this.#scrollTarget !== window)
                this.#scrollTarget.addEventListener('scroll', this.invalidate, { capture: true, passive: true })
            window.visualViewport?.addEventListener('resize', this.invalidate)
            this.#observer = new ResizeObserver(this.invalidate)
            this.#observer.observe(this.#resizeTarget)
        }
        this.invalidate()
    }

    invalidate = () => {
        if (!this.#inset || this.#destroyed || this.#frame != null) return
        this.#frame = requestAnimationFrame(() => {
            this.#frame = null
            this.#paint()
        })
    }

    hide() {
        this.#element?.remove()
        this.#element = null
        this.#signature = ''
    }

    #paint() {
        const viewport = { width: window.innerWidth, height: window.innerHeight }
        const spans = occludedSearchSpans(this.#getRects(), viewport, this.#inset)
        if (!spans.length) {
            this.hide()
            return
        }
        const top = viewport.height * (1 - this.#inset) - 4
        const signature = JSON.stringify([top, spans])
        if (signature === this.#signature) return
        this.#signature = signature
        if (!this.#element) {
            // SVG stays independent of prose rules such as span:empty.
            this.#element = document.createElementNS(SVG_NS, 'svg')
            this.#element.dataset.readflexSearchOcclusion = ''
            this.#element.setAttribute('aria-hidden', 'true')
            this.#element.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;pointer-events:none;user-select:none;z-index:2147483646;'
            document.body.append(this.#element)
        }
        const children = spans.map(({ left, width }) => {
            const rect = document.createElementNS(SVG_NS, 'rect')
            for (const [name, value] of Object.entries({
                x: left, y: top, width, height: 4, rx: 2,
                fill: ACTIVE_SEARCH_HIGHLIGHT_COLOR,
            })) rect.setAttribute(name, value)
            return rect
        })
        this.#element.replaceChildren(...children)
    }

    #stop() {
        if (this.#frame != null) cancelAnimationFrame(this.#frame)
        this.#frame = null
        this.#observer?.disconnect()
        this.#observer = null
        window.removeEventListener('resize', this.invalidate)
        window.removeEventListener('scroll', this.invalidate, true)
        if (this.#scrollTarget !== window)
            this.#scrollTarget.removeEventListener('scroll', this.invalidate, true)
        window.visualViewport?.removeEventListener('resize', this.invalidate)
        this.hide()
    }

    destroy() {
        this.#destroyed = true
        this.#inset = 0
        this.#stop()
    }
}
