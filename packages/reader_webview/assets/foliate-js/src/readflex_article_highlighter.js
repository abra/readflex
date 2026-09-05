import { Overlayer } from './overlayer.js'

// Uses the existing non-mutating SVG renderer on WebViews without CSS highlights.
export class ArticleHighlighter {
    #native = Boolean(globalThis.Highlight && globalThis.CSS?.highlights)
    #overlay = null
    #keys = new Set()
    #redrawPending = false

    constructor(content) {
        if (this.#native) return
        this.#overlay = new Overlayer(document)
        const element = this.#overlay.element
        element.dataset.rfHighlightOverlay = ''
        element.setAttribute('aria-hidden', 'true')
        element.style.overflow = 'visible'
        document.documentElement.append(element)
        const redraw = () => {
            if (this.#redrawPending || !this.#keys.size) return
            this.#redrawPending = true
            requestAnimationFrame(() => {
                this.#redrawPending = false
                this.#overlay.redraw()
            })
        }
        new ResizeObserver(redraw).observe(content)
        window.addEventListener('resize', redraw)
        content.addEventListener('load', redraw, true)
        document.fonts?.addEventListener('loadingdone', redraw)
    }

    set(name, range, background) {
        this.#keys.add(name)
        if (this.#native) {
            CSS.highlights.set(name, new Highlight(range))
            return
        }
        this.#overlay.add(name, range, rects => {
            const origin = this.#overlay.element.getBoundingClientRect()
            return Overlayer.highlight(rects.map(rect => ({
                ...rect, left: rect.left - origin.left, top: rect.top - origin.top,
            })), { color: background, opacity: 1 })
        })
    }

    delete(name) {
        this.#keys.delete(name)
        if (this.#native) CSS.highlights.delete(name)
        else this.#overlay.remove(name)
    }
}
