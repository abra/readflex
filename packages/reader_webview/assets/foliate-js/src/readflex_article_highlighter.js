import { Overlayer } from './overlayer.js'

// Uses the existing non-mutating SVG renderer on WebViews without CSS highlights.
//
// Overlapping groups paint by `priority`, higher on top, on both paths. The
// CSS path sets `Highlight.priority`; registration order is not a stable
// substitute (WebKit's registry does not iterate in insertion order). The SVG
// path keeps overlay children in ascending priority.
export class ArticleHighlighter {
    #native = Boolean(globalThis.Highlight && globalThis.CSS?.highlights)
    #overlay = null
    // name -> { priority, entries: [{ key, range, style, order }] }; entries
    // stay empty on the CSS path, which needs only the priority.
    #groups = new Map()
    #drawOrder = 0
    #batchDepth = 0
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
            if (this.#redrawPending || !this.#groups.size) return
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
    set(name, range, style, priority = 0) {
        this.setMany(name, [range], style, priority)
    }

    setMany(name, ranges, style, priority = 0) {
        this.delete(name)
        this.#add(name, ranges, style, priority)
    }

    // Adds ranges to a group without redrawing the earlier ones. `priority`
    // applies when this call creates the group; an existing group keeps its.
    append(name, ranges, style, priority = 0) {
        this.#add(name, ranges, style, this.#groups.get(name)?.priority ?? priority)
    }

    // Groups several changes so the SVG path restores paint order once.
    batch(callback) {
        this.#batchDepth += 1
        try {
            callback()
        } finally {
            this.#batchDepth -= 1
            if (!this.#batchDepth) this.#restack()
        }
    }

    delete(name) {
        const group = this.#groups.get(name)
        this.#groups.delete(name)
        if (this.#native) {
            CSS.highlights.delete(name)
            return
        }
        for (const { key } of group?.entries ?? []) this.#overlay.remove(key)
    }

    #add(name, ranges, style, priority) {
        const list = ranges.filter(Boolean)
        if (!list.length) return
        const group = this.#groups.get(name) ?? { priority, entries: [] }
        this.#groups.set(name, group)
        if (this.#native) {
            const existing = CSS.highlights.get(name)
            if (existing) {
                for (const range of list) existing.add(range)
            } else {
                const highlight = new Highlight(...list)
                highlight.priority = priority
                CSS.highlights.set(name, highlight)
            }
            return
        }
        for (const range of list) {
            const entry = { key: `${name}:${group.entries.length}`, range, style, order: 0 }
            group.entries.push(entry)
            this.#draw(entry)
        }
        if (!this.#batchDepth) this.#restack()
    }

    #draw(entry) {
        const { key, range, style } = entry
        entry.order = ++this.#drawOrder
        this.#overlay.add(key, range, rects => {
            const origin = this.#overlay.element.getBoundingClientRect()
            return Overlayer.highlight(rects.map(rect => ({
                ...rect, left: rect.left - origin.left, top: rect.top - origin.top,
            })), style)
        })
    }

    // The overlay paints in insertion order. Walk groups by priority (ties
    // keep their draw order) and re-add only those drawn before a lower
    // group, so a usual change (new groups added on top) re-measures nothing.
    #restack() {
        if (this.#native) return
        const spans = []
        for (const group of this.#groups.values()) {
            if (!group.entries.length) continue
            let first = Infinity
            let last = 0
            for (const { order } of group.entries) {
                if (order < first) first = order
                if (order > last) last = order
            }
            spans.push({ group, first, last })
        }
        spans.sort((a, b) => a.group.priority - b.group.priority || a.first - b.first)
        let reached = 0
        for (const { group, first, last } of spans) {
            if (first > reached) {
                reached = last
                continue
            }
            for (const entry of group.entries) {
                this.#overlay.remove(entry.key)
                this.#draw(entry)
            }
            reached = this.#drawOrder
        }
    }
}
