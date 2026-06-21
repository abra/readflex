const parseViewport = str => str
    ?.split(/[,;\s]/) // NOTE: technically, only the comma is valid
    ?.filter(x => x)
    ?.map(x => x.split('=').map(x => x.trim()))

const getViewport = (doc, viewport) => {
    // use `viewBox` for SVG
    if (doc.documentElement.localName === 'svg') {
        const [, , width, height] = doc.documentElement
            .getAttribute('viewBox')?.split(/\s/) ?? []
        return { width, height }
    }

    // get `viewport` `meta` element
    const meta = parseViewport(doc.querySelector('meta[name="viewport"]')
        ?.getAttribute('content'))
    if (meta) return Object.fromEntries(meta)

    // fallback to book's viewport
    if (typeof viewport === 'string') return parseViewport(viewport)
    if (viewport) return viewport

    // if no viewport (possibly with image directly in spine), get image size
    const img = doc.querySelector('img')
    if (img) return { width: img.naturalWidth, height: img.naturalHeight }

    // get generated canvas size for canvas-backed fixed-layout pages
    const canvas = doc.querySelector('canvas')
    if (canvas) return { width: canvas.width, height: canvas.height }

    // just show *something*, i guess...
    console.warn(new Error('Missing viewport properties'))
    return { width: 1000, height: 2000 }
}

const isCanvasImageSource = src =>
    src && typeof src === 'object' && src.kind === 'canvas-image'

// Crop is a renderer hint; the iframe document keeps its original size.
const normalizeCrop = (crop, width, height) => {
    if (!crop || !Number.isFinite(width) || !Number.isFinite(height)) return null
    const left = Math.max(0, Math.min(width - 1, Math.round(Number(crop.left) || 0)))
    const top = Math.max(0, Math.min(height - 1, Math.round(Number(crop.top) || 0)))
    const right = Math.max(left + 1, Math.min(width, Math.round(Number(crop.right) || width)))
    const bottom = Math.max(top + 1, Math.min(height, Math.round(Number(crop.bottom) || height)))
    const cropWidth = right - left
    const cropHeight = bottom - top

    if (cropWidth < width * 0.35 || cropHeight < height * 0.35) return null
    return { left, top, right, bottom, width: cropWidth, height: cropHeight }
}

const writeCanvasImageDocument = (iframe, src) => {
    const doc = iframe.contentDocument
    doc.open()
    doc.write(src.html)
    doc.close()
    src.draw?.(doc)
    return doc
}

export class FixedLayout extends HTMLElement {
    #root = this.attachShadow({ mode: 'closed' })
    #observer = new ResizeObserver(() => this.#render())
    #spreads
    #index = -1
    #currentSpread
    #locked = false
    defaultViewport
    spread
    #portrait = false
    #left
    #right
    #center
    #side
    constructor() {
        super()

        const sheet = new CSSStyleSheet()
        this.#root.adoptedStyleSheets = [sheet]
        sheet.replaceSync(`:host {
            width: 100%;
            height: 100%;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
            position: relative;
            contain: layout paint;
        }
        .spread {
            position: absolute;
            inset: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            pointer-events: none;
            will-change: transform, opacity;
        }
        .spread.current {
            pointer-events: auto;
        }`)

        this.#observer.observe(this)
    }
    #shouldAnimate(direction) {
        if (!direction || !this.hasAttribute('animated')) return false
        return !globalThis.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches
    }
    #turnAnimation(element, keyframes) {
        const animation = element.animate?.(keyframes, {
            duration: 180,
            easing: 'cubic-bezier(.2, .8, .2, 1)',
            fill: 'both',
        })
        const finished = animation?.finished?.catch(() => {})
        return finished?.finally(() => animation.cancel()) ?? Promise.resolve()
    }
    get pageTurnAxisVertical() {
        return this.getAttribute('page-turn-axis') === 'vertical'
    }
    #spreadTurnTransform(offset) {
        return this.pageTurnAxisVertical
            ? `translate3d(0, ${offset}, 0)`
            : `translate3d(${offset}, 0, 0)`
    }
    #frameTurnTransform(offset) {
        return this.pageTurnAxisVertical
            ? `translate3d(-50%, calc(-50% + ${offset}), 0)`
            : `translate3d(calc(-50% + ${offset}), -50%, 0)`
    }
    #nextTurnDirection() {
        return this.pageTurnAxisVertical ? 1 : this.rtl ? -1 : 1
    }
    #prevTurnDirection() {
        return this.pageTurnAxisVertical ? -1 : this.rtl ? 1 : -1
    }
    #leftTurnDirection() {
        return this.rtl ? this.#nextTurnDirection() : this.#prevTurnDirection()
    }
    #rightTurnDirection() {
        return this.rtl ? this.#prevTurnDirection() : this.#nextTurnDirection()
    }
    async #animateSpreadTurn(previousSpread, nextSpread, direction) {
        if (!this.#shouldAnimate(direction) || !previousSpread) return
        const enterOffset = direction > 0 ? '18%' : '-18%'
        const exitOffset = direction > 0 ? '-18%' : '18%'
        await Promise.all([
            this.#turnAnimation(nextSpread, [
                { transform: this.#spreadTurnTransform(enterOffset), opacity: 0.35 },
                { transform: 'translate3d(0, 0, 0)', opacity: 1 },
            ]),
            this.#turnAnimation(previousSpread, [
                { transform: 'translate3d(0, 0, 0)', opacity: 1 },
                { transform: this.#spreadTurnTransform(exitOffset), opacity: 0.35 },
            ]),
        ])
    }
    async #animateSideTurn(fromFrame, toFrame, direction) {
        if (!this.#shouldAnimate(direction) || !fromFrame?.element || !toFrame?.element) return
        const enterOffset = direction > 0 ? '18%' : '-18%'
        const exitOffset = direction > 0 ? '-18%' : '18%'
        const frames = [fromFrame.element, toFrame.element]
        for (const element of frames) {
            Object.assign(element.style, {
                display: 'block',
                position: 'absolute',
                left: '50%',
                top: '50%',
                transform: 'translate3d(-50%, -50%, 0)',
                willChange: 'transform, opacity',
            })
        }
        await Promise.all([
            this.#turnAnimation(toFrame.element, [
                { transform: this.#frameTurnTransform(enterOffset), opacity: 0.35 },
                { transform: 'translate3d(-50%, -50%, 0)', opacity: 1 },
            ]),
            this.#turnAnimation(fromFrame.element, [
                { transform: 'translate3d(-50%, -50%, 0)', opacity: 1 },
                { transform: this.#frameTurnTransform(exitOffset), opacity: 0.35 },
            ]),
        ])
        for (const element of frames) {
            element.style.position = ''
            element.style.left = ''
            element.style.top = ''
            element.style.transform = ''
            element.style.willChange = ''
            element.style.opacity = ''
        }
        this.#render()
    }
    async #createFrame(position, { index, src }, parent = this.#root) {
        const element = document.createElement('div')
        const iframe = document.createElement('iframe')
        element.append(iframe)
        Object.assign(iframe.style, {
            border: '0',
            display: 'none',
            overflow: 'hidden',
        })
        // `allow-scripts` is needed for events because of WebKit bug
        // https://bugs.webkit.org/show_bug.cgi?id=218086
        iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts')
        iframe.setAttribute('scrolling', 'no')
        iframe.setAttribute('part', 'filter')
        parent.append(element)
        if (!src) return { blank: true, element, iframe }
        if (isCanvasImageSource(src)) {
            const doc = writeCanvasImageDocument(iframe, src)
            doc.position = position
            doc.readflexSectionIndex = index
            this.dispatchEvent(new CustomEvent('load', { detail: { doc, index } }))
            return {
                element, iframe,
                width: src.width,
                height: src.height,
                crop: src.crop,
            }
        }
        return new Promise(resolve => {
            const onload = () => {
                iframe.removeEventListener('load', onload)
                const doc = iframe.contentDocument
                doc.position = position
                doc.readflexSectionIndex = index
                this.dispatchEvent(new CustomEvent('load', { detail: { doc, index } }))
                // Image-backed fixed pages can fire iframe `load` before
                // the image bitmap is decoded, leaving naturalWidth/Height
                // at 0. Wait before measuring viewport so scaling is stable.
                const finish = () => {
                    const { width, height } = getViewport(doc, this.defaultViewport)
                    resolve({
                        element, iframe,
                        width: parseFloat(width),
                        height: parseFloat(height),
                    })
                }
                const img = doc.querySelector('img')
                if (img && !img.complete) {
                    const done = () => {
                        img.removeEventListener('load', done)
                        img.removeEventListener('error', done)
                        finish()
                    }
                    img.addEventListener('load', done)
                    img.addEventListener('error', done)
                } else {
                    finish()
                }
            }
            iframe.addEventListener('load', onload)
            iframe.src = src
        })
    }
    #render(side = this.#side) {
        if (!side) return
        const left = this.#left ?? {}
        const right = this.#center ?? this.#right ?? {}
        const target = side === 'left' ? left : right
        const { width, height } = this.getBoundingClientRect()
        // Bail if the host hasn't been laid out — the ResizeObserver will
        // re-trigger us once dimensions are real. Without this guard a
        // 0×0 rect would silently flip portrait detection to false.
        if (width <= 0 || height <= 0) return
        // Same heuristic readest uses (1.2× threshold): on devices that
        // are only marginally taller than wide (unfolded foldables, etc.)
        // fall through to the two-up spread layout.
        const portrait = this.spread !== 'both' && this.spread !== 'portrait'
            && height > width * 1.2
        this.#portrait = portrait
        const blankWidth = left.width ?? right.width
        const blankHeight = left.height ?? right.height
        const renderSize = frame => {
            const sourceWidth = frame.width ?? blankWidth
            const sourceHeight = frame.height ?? blankHeight
            const crop = normalizeCrop(frame.crop, sourceWidth, sourceHeight)
            return {
                width: crop?.width ?? sourceWidth,
                height: crop?.height ?? sourceHeight,
            }
        }
        const targetSize = renderSize(target)
        const leftSize = renderSize(left)
        const rightSize = renderSize(right)

        const scale = portrait || this.#center
            ? Math.min(
                width / targetSize.width,
                height / targetSize.height)
            : Math.min(
                width / (leftSize.width + rightSize.width),
                height / Math.max(leftSize.height, rightSize.height))

        const transform = frame => {
            const { element, iframe, width, height, blank } = frame
            const sourceWidth = width ?? blankWidth
            const sourceHeight = height ?? blankHeight
            const crop = normalizeCrop(frame.crop, sourceWidth, sourceHeight)
            const renderWidth = crop?.width ?? sourceWidth
            const renderHeight = crop?.height ?? sourceHeight
            const pageTransform = crop
                ? `translate(${-crop.left * scale}px, ${-crop.top * scale}px) scale(${scale})`
                : `scale(${scale})`
            iframe.contentDocument.scale = scale
            iframe.contentDocument.readflexVisibleRect = {
                left: crop?.left ?? 0,
                top: crop?.top ?? 0,
                width: renderWidth,
                height: renderHeight,
            }
            Object.assign(iframe.style, {
                width: `${sourceWidth}px`,
                height: `${sourceHeight}px`,
                transform: pageTransform,
                transformOrigin: 'top left',
                display: blank ? 'none' : 'block',
            })
            Object.assign(element.style, {
                width: `${renderWidth * scale}px`,
                height: `${renderHeight * scale}px`,
                overflow: 'hidden',
                display: 'block',
            })
            if (portrait && frame !== target) {
                element.style.display = 'none'
            }
        }
        if (this.#center) {
            transform(this.#center)
        } else {
            transform(left)
            transform(right)
        }
    }
    async #showSpread({ left, right, center, side, direction = 0 }) {
        const previousSpread = this.#currentSpread
        const nextSpread = document.createElement('div')
        nextSpread.className = 'spread'
        nextSpread.style.visibility = 'hidden'
        this.#root.append(nextSpread)
        this.#left = null
        this.#right = null
        this.#center = null
        if (center) {
            this.#center = await this.#createFrame('center', center, nextSpread)
            this.#side = 'center'
            this.#render()
        } else {
            this.#left = await this.#createFrame('left', left, nextSpread)
            this.#right = await this.#createFrame('right', right, nextSpread)
            this.#side = this.#left.blank ? 'right'
                : this.#right.blank ? 'left' : side
            this.#render()
        }
        nextSpread.style.visibility = ''
        nextSpread.classList.add('current')
        this.#currentSpread = nextSpread
        previousSpread?.classList.remove('current')
        await this.#animateSpreadTurn(previousSpread, nextSpread, direction)
        previousSpread?.remove()
    }
    // Following readest's pattern: instead of toggling display values
    // manually here, set `#side` and re-run `#render()` so display state
    // has a single source of truth. Manual toggling kept getting out of
    // sync with the rendered state on back navigation, leaving both
    // halves of a spread visible at once.
    async #goLeft() {
        if (this.#center || this.#left?.blank) return
        if (this.#portrait && this.#left?.element?.style?.display === 'none') {
            const previousFrame = this.#right
            this.#side = 'left'
            this.#render()
            this.#reportLocation('page')
            await this.#animateSideTurn(previousFrame, this.#left, this.#leftTurnDirection())
            return true
        }
    }
    async #goRight() {
        if (this.#center || this.#right?.blank) return
        if (this.#portrait && this.#right?.element?.style?.display === 'none') {
            const previousFrame = this.#left
            this.#side = 'right'
            this.#render()
            this.#reportLocation('page')
            await this.#animateSideTurn(previousFrame, this.#right, this.#rightTurnDirection())
            return true
        }
    }
    open(book) {
        this.book = book
        const { rendition } = book
        this.spread = rendition?.spread
        this.defaultViewport = rendition?.viewport

        const rtl = book.dir === 'rtl'
        const ltr = !rtl
        this.rtl = rtl

        if (rendition?.spread === 'none')
            this.#spreads = book.sections.map(section => ({ center: section }))
        else this.#spreads = book.sections.reduce((arr, section) => {
            const last = arr[arr.length - 1]
            const { linear, pageSpread } = section
            if (linear === 'no') return arr
            const newSpread = () => {
                const spread = {}
                arr.push(spread)
                return spread
            }
            if (pageSpread === 'center') {
                const spread = last.left || last.right ? newSpread() : last
                spread.center = section
            }
            else if (pageSpread === 'left') {
                const spread = last.center || last.left || ltr ? newSpread() : last
                spread.left = section
            }
            else if (pageSpread === 'right') {
                const spread = last.center || last.right || rtl ? newSpread() : last
                spread.right = section
            }
            else if (ltr) {
                if (last.center || last.right) newSpread().left = section
                else if (last.left) last.right = section
                else last.left = section
            }
            else {
                if (last.center || last.left) newSpread().right = section
                else if (last.right) last.left = section
                else last .right = section
            }
            return arr
        }, [{}])
    }
    get pageProgressionDirection() {
        return this.rtl ? 'rtl' : 'ltr'
    }
    #canGoLeftWithinSpread() {
        if (this.#center || this.#left?.blank) return false
        return this.#portrait && this.#left?.element?.style?.display === 'none'
    }
    #canGoRightWithinSpread() {
        if (this.#center || this.#right?.blank) return false
        return this.#portrait && this.#right?.element?.style?.display === 'none'
    }
    get atStart() {
        if (this.#index < 0) return true
        const canGoWithinSpread = this.rtl
            ? this.#canGoRightWithinSpread()
            : this.#canGoLeftWithinSpread()
        return !canGoWithinSpread && this.#index <= 0
    }
    get atEnd() {
        if (this.#index < 0) return true
        const lastIndex = (this.#spreads?.length ?? 0) - 1
        const canGoWithinSpread = this.rtl
            ? this.#canGoLeftWithinSpread()
            : this.#canGoRightWithinSpread()
        return !canGoWithinSpread && this.#index >= lastIndex
    }
    get index() {
        const spread = this.#spreads[this.#index]
        // Upstream foliate-js writes `this.side` here, but the property is
        // only ever assigned as `#side` (private) — so `this.side` is
        // always `undefined`, the `=== 'left'` check always fails, and the
        // getter always returns the section on the RIGHT of a two-page
        // spread. When the user is on the LEFT page, the saved CFI ends
        // up pointing one section forward, and on reopen the renderer
        // restores into the same spread but lands on the wrong half.
        const section = spread?.center ?? (this.#side === 'left'
            ? spread.left ?? spread.right : spread.right ?? spread.left)
        return this.book.sections.indexOf(section)
    }
    #reportLocation(reason) {
        this.dispatchEvent(new CustomEvent('relocate', { detail:
            { reason, range: null, index: this.index, fraction: 0, size: 1 } }))
    }
    getSpreadOf(section) {
        const spreads = this.#spreads
        for (let index = 0; index < spreads.length; index++) {
            const { left, right, center } = spreads[index]
            if (left === section) return { index, side: 'left' }
            if (right === section) return { index, side: 'right' }
            if (center === section) return { index, side: 'center' }
        }
    }
    async goToSpread(index, side, reason, direction = 0) {
        if (index < 0 || index > this.#spreads.length - 1) return
        if (index === this.#index) {
            this.#render(side)
            return
        }
        this.#index = index
        const spread = this.#spreads[index]
        if (spread.center) {
            const index = this.book.sections.indexOf(spread.center)
            const src = await spread.center?.load?.()
            await this.#showSpread({ center: { index, src }, direction })
        } else {
            const indexL = this.book.sections.indexOf(spread.left)
            const indexR = this.book.sections.indexOf(spread.right)
            const [srcL, srcR] = await Promise.all([
                spread.left?.load?.(),
                spread.right?.load?.(),
            ])
            const left = { index: indexL, src: srcL }
            const right = { index: indexR, src: srcR }
            await this.#showSpread({ left, right, side, direction })
        }
        this.#reportLocation(reason)
    }
    async select(target) {
        await this.goTo(target)
        // TODO
    }
    async goTo(target) {
        const { book } = this
        const resolved = await target
        const section = book.sections[resolved.index]
        if (!section) return
        const { index, side } = this.getSpreadOf(section)
        await this.goToSpread(index, side)
    }
    async next() {
        if (this.#locked) return
        this.#locked = true
        try {
            const s = await (this.rtl ? this.#goLeft() : this.#goRight())
            if (!s) {
                await this.goToSpread(
                    this.#index + 1,
                    this.rtl ? 'right' : 'left',
                    'page',
                    this.#nextTurnDirection()
                )
            }
        } finally {
            this.#locked = false
        }
    }
    async prev() {
        if (this.#locked) return
        this.#locked = true
        try {
            const s = await (this.rtl ? this.#goRight() : this.#goLeft())
            if (!s) {
                await this.goToSpread(
                    this.#index - 1,
                    this.rtl ? 'left' : 'right',
                    'page',
                    this.#prevTurnDirection()
                )
            }
        } finally {
            this.#locked = false
        }
    }
    getContents() {
        return Array.from(this.#root.querySelectorAll('iframe'), frame => ({
            doc: frame.contentDocument,
            index: frame.contentDocument?.readflexSectionIndex,
        }))
    }
    destroy() {
        this.#observer.unobserve(this)
        this.#currentSpread = null
    }
}

customElements.define('foliate-fxl', FixedLayout)
