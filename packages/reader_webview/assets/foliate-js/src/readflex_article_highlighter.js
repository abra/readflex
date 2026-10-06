import { Overlayer } from './overlayer.js'

// Uses the existing non-mutating SVG renderer on WebViews without CSS highlights.
export class ArticleHighlighter {
    #native = Boolean(globalThis.Highlight && globalThis.CSS?.highlights)
    #overlay = null
    #keys = new Map()
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

    get isNative() {
        return this.#native
    }

    // `style` holds the Overlayer.highlight option set (color, opacity,
    // mixBlendMode, verticalOffset, radius, verticalInset); the CSS path
    // receives its colour through a `::highlight` rule owned by the caller.
    set(name, range, style) {
        this.setMany(name, [range], style)
    }

    setMany(name, ranges, style) {
        this.delete(name)
        this.append(name, ranges, style)
    }

    // Adds ranges to an existing group without redrawing the earlier ones.
    append(name, ranges, style) {
        const list = ranges.filter(Boolean)
        if (!list.length) return
        if (this.#native) {
            const existing = CSS.highlights.get(name)
            if (existing) for (const range of list) existing.add(range)
            else CSS.highlights.set(name, new Highlight(...list))
            this.#keys.set(name, [])
            return
        }
        const keys = this.#keys.get(name) ?? []
        this.#keys.set(name, keys)
        for (const range of list) {
            const key = `${name}:${keys.length}`
            keys.push(key)
            this.#overlay.add(key, range, rects => {
                const origin = this.#overlay.element.getBoundingClientRect()
                return Overlayer.highlight(rects.map(rect => ({
                    ...rect, left: rect.left - origin.left, top: rect.top - origin.top,
                })), style)
            })
        }
    }

    delete(name) {
        const keys = this.#keys.get(name)
        this.#keys.delete(name)
        if (this.#native) {
            CSS.highlights.delete(name)
            return
        }
        for (const key of keys ?? []) this.#overlay.remove(key)
    }
}
