const wait = ms => new Promise(resolve => setTimeout(resolve, ms))

const lerp = (min, max, x) => x * (max - min) + min
const easeOutSine = x => Math.sin((x * Math.PI) / 2)
const easeInOutSine = x => -(Math.cos(Math.PI * x) - 1) / 2
// const easeOutSine = x => 1 - (1 - x) * (1 - x);
const animate = (a, b, duration, ease, render, { initialProgress = 0 } = {}) => new Promise(resolve => {
  let start
  const clampedInitial = Math.max(0, Math.min(initialProgress, 0.95))
  const step = now => {
    start ??= now - clampedInitial * duration
    const fraction = Math.min(1, (now - start) / duration)
    render(lerp(a, b, ease(fraction)))
    if (fraction < 1) requestAnimationFrame(step)
    else resolve()
  }
  requestAnimationFrame(step)
})

// collapsed range doesn't return client rects sometimes (or always?)
// try make get a non-collapsed range or element
const uncollapse = range => {
  if (!range?.collapsed) return range
  const { endOffset, endContainer } = range
  if (endContainer.nodeType === 1) return endContainer
  if (endOffset + 1 < endContainer.length) range.setEnd(endContainer, endOffset + 1)
  else if (endOffset > 1) range.setStart(endContainer, endOffset - 1)
  else return endContainer.parentNode
  return range
}

const makeRange = (doc, node, start, end = start) => {
  const range = doc.createRange()
  range.setStart(node, start)
  range.setEnd(node, end)
  return range
}

// use binary search to find an offset value in a text node
const bisectNode = (doc, node, cb, start = 0, end = node.nodeValue.length) => {
  if (end - start === 1) {
    const result = cb(makeRange(doc, node, start), makeRange(doc, node, end))
    return result < 0 ? start : end
  }
  const mid = Math.floor(start + (end - start) / 2)
  const result = cb(makeRange(doc, node, start, mid), makeRange(doc, node, mid, end))
  return result < 0 ? bisectNode(doc, node, cb, start, mid)
    : result > 0 ? bisectNode(doc, node, cb, mid, end) : mid
}

const { SHOW_ELEMENT, SHOW_TEXT, SHOW_CDATA_SECTION,
  FILTER_ACCEPT, FILTER_REJECT, FILTER_SKIP } = NodeFilter

const filter = SHOW_ELEMENT | SHOW_TEXT | SHOW_CDATA_SECTION
let missingBodyVisibleRangeLogged = false

const getVisibleRange = (doc, start, end, mapRect) => {
  // first get all visible nodes
  const acceptNode = node => {
    const name = node.localName?.toLowerCase()
    // ignore all scripts, styles, and their children
    if (name === 'script' || name === 'style') return FILTER_REJECT
    if (node.nodeType === 1) {
      const { left, right } = mapRect(node.getBoundingClientRect())
      // no need to check child nodes if it's completely out of view
      if (right < start || left > end) return FILTER_REJECT
      // elements must be completely in view to be considered visible
      // because you can't specify offsets for elements
      if (left >= start && right <= end) return FILTER_ACCEPT
      // TODO: it should probably allow elements that do not contain text
      // because they can exceed the whole viewport in both directions
      // especially in scrolled mode
    } else {
      // ignore empty text nodes
      if (!node.nodeValue?.trim()) return FILTER_REJECT
      // create range to get rect
      const range = doc.createRange()
      range.selectNodeContents(node)
      const { left, right } = mapRect(range.getBoundingClientRect())
      // it's visible if any part of it is in view
      if (right >= start && left <= end) return FILTER_ACCEPT
    }
    return FILTER_SKIP
  }
  if (!doc?.body) {
    if (missingBodyVisibleRangeLogged) return
    missingBodyVisibleRangeLogged = true
    console.warn(
      '[readflex-paginator] visible range skipped: document body is unavailable',
      { readyState: doc?.readyState, url: doc?.URL },
    )
    return
  }
  const walker = doc.createTreeWalker(doc.body, filter, { acceptNode })
  const nodes = []
  for (let node = walker.nextNode(); node; node = walker.nextNode())
    nodes.push(node)

  // we're only interested in the first and last visible nodes
  const from = nodes[0] ?? doc.body
  const to = nodes[nodes.length - 1] ?? from

  // find the offset at which visibility changes
  const startOffset = from.nodeType === 1 ? 0
    : bisectNode(doc, from, (a, b) => {
      const p = mapRect(a.getBoundingClientRect())
      const q = mapRect(b.getBoundingClientRect())
      if (p.right < start && q.left > start) return 0
      return q.left > start ? -1 : 1
    })
  const endOffset = to.nodeType === 1 ? 0
    : bisectNode(doc, to, (a, b) => {
      const p = mapRect(a.getBoundingClientRect())
      const q = mapRect(b.getBoundingClientRect())
      if (p.right < end && q.left > end) return 0
      return q.left > end ? -1 : 1
    })

  const range = doc.createRange()
  range.setStart(from, startOffset)
  range.setEnd(to, endOffset)
  return range
}

const getDirection = doc => {
  const { defaultView } = doc
  const { writingMode, direction } = defaultView.getComputedStyle(doc.body)
  const vertical = writingMode === 'vertical-rl'
    || writingMode === 'vertical-lr'
  const rtl = doc.body.dir === 'rtl'
    || direction === 'rtl'
    || doc.documentElement.dir === 'rtl'
  return { vertical, rtl, writingMode }
}

// const getBackground = doc => {
//   const bodyStyle = doc.defaultView.getComputedStyle(doc.body)
//   return bodyStyle.backgroundColor === 'rgba(0, 0, 0, 0)'
//     && bodyStyle.backgroundImage === 'none'
//     ? doc.defaultView.getComputedStyle(doc.documentElement).background
//     : bodyStyle.background
// }
const getBackground = (bgimgUrl) => {
  let bg
  if (bgimgUrl === 'none') {
    bg = `none`
  } else {
    bg = `url(${bgimgUrl}) repeat scroll 50% 50% / 100% 100%`
  }
  return bg
}

const makeMarginals = (length, part) => Array.from({ length }, () => {
  const div = document.createElement('div')
  const child = document.createElement('div')
  div.append(child)
  child.setAttribute('part', part)
  return div
})

const setStylesImportant = (el, styles) => {
  const { style } = el
  for (const [k, v] of Object.entries(styles)) style.setProperty(k, v, 'important')
}

class View {
  // Readflex patch: coalesce ResizeObserver callbacks via rAF. expand()
  // mutates the iframe size that this observer watches — on slower
  // Android Chromium (Adreno-Vulkan) this trips an unbounded layout
  // feedback loop ("ResizeObserver loop completed with undelivered
  // notifications" spam, page never settles, blank screen). One
  // expand per frame is enough to converge. expand() itself null-guards
  // `this.document` so a deferred call after iframe-unload is safe.
  #expandPending = false
  #observer = new ResizeObserver(() => {
    if (this.#expandPending) return
    this.#expandPending = true
    requestAnimationFrame(() => {
      this.#expandPending = false
      this.expand()
    })
  })
  #element = document.createElement('div')
  #iframe = document.createElement('iframe')
  #contentRange = document.createRange()
  #overlayer
  #vertical = false
  #rtl = false
  #writingMode = 'horizontal-ltr'
  #column = true
  #size
  #layout = {}
  constructor({ container, onExpand }) {
    this.container = container
    this.onExpand = onExpand
    this.#iframe.setAttribute('part', 'filter')
    this.#element.append(this.#iframe)
    Object.assign(this.#element.style, {
      boxSizing: 'content-box',
      position: 'relative',
      overflow: 'hidden',
      flex: '0 0 auto',
      width: '100%', height: '100%',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      contain: 'layout paint size',
      contentVisibility: 'auto',
      willChange: 'transform',
    })
    Object.assign(this.#iframe.style, {
      overflow: 'hidden',
      border: '0',
      display: 'none',
      width: '100%', height: '100%',
    })
    // `allow-scripts` is needed for events because of WebKit bug
    // https://bugs.webkit.org/show_bug.cgi?id=218086
    this.#iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts')
    this.#iframe.setAttribute('scrolling', 'no')
  }
  get element() {
    return this.#element
  }
  get document() {
    return this.#iframe.contentDocument
  }
  createPagePreview(scrollOffset) {
    const doc = this.document
    if (!doc?.documentElement) return null

    const root = doc.documentElement.cloneNode(true)
    const head = root.querySelector('head')
    if (head && doc.baseURI) {
      const base = document.createElement('base')
      base.href = doc.baseURI
      head.prepend(base)
    }

    const wrapper = document.createElement('div')
    const element = document.createElement('div')
    const frame = document.createElement('iframe')

    Object.assign(wrapper.style, {
      position: 'absolute',
      inset: '0',
      overflow: 'hidden',
      pointerEvents: 'none',
      contain: 'layout paint size',
      zIndex: '2',
      willChange: 'transform',
    })
    Object.assign(element.style, {
      boxSizing: 'content-box',
      position: 'absolute',
      left: '0',
      top: '0',
      overflow: 'hidden',
      width: this.#element.style.width || `${this.#element.getBoundingClientRect().width}px`,
      height: this.#element.style.height || '100%',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      contain: 'layout paint size',
      pointerEvents: 'none',
      willChange: 'transform',
    })
    Object.assign(frame.style, {
      overflow: 'hidden',
      border: '0',
      display: 'block',
      width: this.#iframe.style.width || `${this.#iframe.getBoundingClientRect().width}px`,
      height: this.#iframe.style.height || '100%',
      pointerEvents: 'none',
    })
    frame.setAttribute('sandbox', 'allow-same-origin')
    frame.setAttribute('scrolling', 'no')
    frame.srcdoc = `<!doctype html>${root.outerHTML}`

    element.append(frame)
    wrapper.append(element)
    this.setPagePreviewScrollOffset(wrapper, scrollOffset)
    return wrapper
  }
  setPagePreviewScrollOffset(wrapper, scrollOffset) {
    const element = wrapper?.firstElementChild
    if (!element) return
    const offset = Number.isFinite(scrollOffset) ? scrollOffset : 0
    element.style.transform = `translateX(${-offset}px)`
  }
  async load(src, afterLoad, beforeRender) {
    if (typeof src !== 'string') throw new Error(`${src} is not string`)
    return new Promise(resolve => {
      this.#iframe.addEventListener('load', () => {
        const doc = this.document
        afterLoad?.(doc)

        // it needs to be visible for Firefox to get computed style
        this.#iframe.style.display = 'block'
        const { vertical, rtl, writingMode } = getDirection(doc)
        this.#iframe.style.display = 'none'

        this.#vertical = vertical
        this.#rtl = rtl
        this.#writingMode = writingMode

        this.#contentRange.selectNodeContents(doc.body)
        const layout = beforeRender?.({ vertical, rtl })
        this.#iframe.style.display = 'block'
        this.render(layout)
        this.#observer.observe(doc.body)

        // the resize observer above doesn't work in Firefox
        // (see https://bugzilla.mozilla.org/show_bug.cgi?id=1832939)
        // until the bug is fixed we can at least account for font load
        doc.fonts.ready.then(() => this.expand())

        resolve()
      }, { once: true })
      this.#iframe.src = src
    })
  }
  render(layout) {
    // Readflex patch (ported from readest/foliate-js): also guard for
    // an unloaded iframe document — render() can be called from the
    // rAF-coalesced ResizeObserver one frame after a chapter swap.
    if (!layout || !this.document?.documentElement) return
    this.#column = layout.flow !== 'scrolled'
    this.#layout = layout
    if (this.#column) this.columnize(layout)
    else this.scrolled(layout)
  }
  scrolled({ gap, columnWidth }) {
    const vertical = this.#vertical
    const doc = this.document
    if (!doc) return
    setStylesImportant(doc.documentElement, {
      'box-sizing': 'border-box',
      'padding': vertical ? `${gap}px 0` : `0 ${gap}px`,
      'column-width': 'auto',
      'height': 'auto',
      'width': 'auto',
    })
    setStylesImportant(doc.body, {
      [vertical ? 'max-height' : 'max-width']: `${columnWidth}px`,
      'margin': 'auto',
      'padding': '0',
      'position': 'static',
    })
    this.setImageSize()
    this.expand()
  }
  columnize({ width, height, gap, columnWidth, topMargin, bottomMargin }) {
    const vertical = this.#vertical
    this.#size = vertical ? height : width

    const doc = this.document

    const verticlePadding = `${gap / 2}px ${topMargin}px ${gap / 2}px ${bottomMargin}px`
    const horizontalPadding = `${topMargin}px ${gap / 2}px ${bottomMargin}px ${gap / 2}px`

    setStylesImportant(doc.documentElement, {
      'box-sizing': 'border-box',
      'column-width': `${Math.trunc(columnWidth)}px`,
      'column-gap': `${gap}px`,
      'column-fill': 'auto',
      ...(vertical
        ? { 'width': `${width}px` }
        : { 'height': `${height}px` }),
      'padding': vertical ? verticlePadding : horizontalPadding,
      'overflow': 'hidden',
      // force wrap long words
      'overflow-wrap': 'break-word',
      // reset some potentially problematic props
      'position': 'static', 'border': '0', 'margin': '0',
      'max-height': 'none', 'max-width': 'none',
      'min-height': 'none', 'min-width': 'none',
      // fix glyph clipping in WebKit
      '-webkit-line-box-contain': 'block glyphs replaced',
    })
    setStylesImportant(doc.body, {
      'max-height': 'none',
      'max-width': 'none',
      'margin': '0',
      // Readflex patch: zero body padding too, otherwise EPUBs that
      // ship `body { padding: 2em !important }` add a second layer
      // of edge spacing on top of the side/top margins we already
      // applied to <html>. Result: some books visibly have wider
      // text margins than others. With this, the only source of
      // edge spacing is reader-controlled.
      'padding': '0',
      // Readflex patch (ported from readest/foliate-js): prevent
      // `position: absolute/fixed` on the publisher's body from
      // coupling its computed size to the iframe — on Android
      // Chromium that coupling makes expand() diverge into an
      // infinite ResizeObserver feedback loop, page never settles
      // (e.g. Khononov DDD EPUB hits this exact path).
      'position': 'static',
    })
    this.setImageSize()
    this.expand()
  }
  setImageSize() {
    const { width, height, margin } = this.#layout
    const vertical = this.#vertical
    const doc = this.document
    for (const el of doc.body.querySelectorAll('img, svg, video')) {
      // preserve max size if they are already set
      const { maxHeight, maxWidth } = doc.defaultView.getComputedStyle(el)
      setStylesImportant(el, {
        'max-height': vertical
          ? (maxHeight !== 'none' && maxHeight !== '0px' ? maxHeight : '100%')
          : `${height - margin * 2}px`,
        'max-width': vertical
          ? `${width - margin * 2}px`
          : (maxWidth !== 'none' && maxWidth !== '0px' ? maxWidth : '100%'),
        'object-fit': 'contain',
        'page-break-inside': 'avoid',
        'break-inside': 'avoid',
        'box-sizing': 'border-box',
      })
    }
  }
  expand() {
    // Readflex patch: bail when iframe is mid-transition. With our rAF
    // coalescing on the ResizeObserver below, expand() can fire one
    // frame after the iframe was unloaded for chapter swap, at which
    // point `this.document` is null and the destructure throws.
    if (!this.document) return
    const { documentElement } = this.document
    if (this.#column) {
      const side = this.#vertical ? 'height' : 'width'
      const otherSide = this.#vertical ? 'width' : 'height'
      this.#contentRange.selectNodeContents(this.document.body)
      const contentRect = this.#contentRange.getBoundingClientRect()
      const rootRect = documentElement.getBoundingClientRect()
      // offset caused by column break at the start of the page
      // which seem to be supported only by WebKit and only for horizontal writing
      const contentStart = this.#vertical ? 0
        : this.#rtl ? rootRect.right - contentRect.right : contentRect.left - rootRect.left
      const contentSize = contentStart + contentRect[side]
      const pageCount = Math.ceil(contentSize / this.#size)
      const expandedSize = pageCount * this.#size
      this.#element.style.padding = '0'
      this.#iframe.style[side] = `${expandedSize}px`
      this.#element.style[side] = `${expandedSize + this.#size * 2}px`
      this.#iframe.style[otherSide] = '100%'
      this.#element.style[otherSide] = '100%'
      documentElement.style[side] = `${this.#size}px`
      if (this.#overlayer) {
        this.#overlayer.element.style.margin = '0'
        this.#overlayer.element.style.left = this.#vertical ? '0' : `${this.#size}px`
        this.#overlayer.element.style.top = this.#vertical ? `${this.#size}px` : '0'
        this.#overlayer.element.style[side] = `${expandedSize}px`
        this.#overlayer.redraw()
      }
    } else {
      const side = this.#vertical ? 'width' : 'height'
      const otherSide = this.#vertical ? 'height' : 'width'
      const contentSize = documentElement.getBoundingClientRect()[side]
      const expandedSize = contentSize
      const { margin } = this.#layout
      const padding = this.#vertical ? `0 ${margin}px` : `${margin}px 0`
      this.#element.style.padding = padding
      this.#iframe.style[side] = `${expandedSize}px`
      this.#element.style[side] = `${expandedSize}px`
      this.#iframe.style[otherSide] = '100%'
      this.#element.style[otherSide] = '100%'
      if (this.#overlayer) {
        this.#overlayer.element.style.margin = padding
        this.#overlayer.element.style.left = '0'
        this.#overlayer.element.style.top = '0'
        this.#overlayer.element.style[side] = `${expandedSize}px`
        this.#overlayer.redraw()
      }
    }
    this.onExpand()
  }
  set overlayer(overlayer) {
    this.#overlayer = overlayer
    this.#element.append(overlayer.element)
  }
  get overlayer() {
    return this.#overlayer
  }
  get writingMode() {
    return this.#writingMode
  }
  destroy() {
    if (this.document) this.#observer.unobserve(this.document.body)
  }
}

// NOTE: everything here assumes the so-called "negative scroll type" for RTL
export class Paginator extends HTMLElement {
  static observedAttributes = [
    'flow', 'gap', 'top-margin', 'bottom-margin', 'background-color',
    'max-inline-size', 'max-block-size', 'max-column-count', 'page-turn-axis',
  ]
  #root = this.attachShadow({ mode: 'open' })
  // Readflex patch: same rAF coalescing as View#observer above.
  #renderPending = false
  #observer = new ResizeObserver(() => {
    if (this.#renderPending) return
    this.#renderPending = true
    requestAnimationFrame(() => {
      this.#renderPending = false
      this.render()
    })
  })
  #top
  #background
  #container
  // #header
  // #footer
  #view
  #vertical = false
  #rtl = false
  #pageProgressionRtl = false
  #margin = 0
  #index = -1
  #anchor = 0 // anchor view to a fraction (0-1), Range, or Element
  #justAnchored = false
  #locked = false // while true, prevent any further navigation
  #styles
  #styleMap = new WeakMap()
  #mediaQuery = matchMedia('(prefers-color-scheme: dark)')
  #mediaQueryListener
  #ignoreNativeScroll = false
  #pendingScrollFrame = null
  #touchState
  #touchScrolled
  #loadingNext = false
  #loadingPrev = false
  #momentumDisabled = false
  #prevOverflowScrolling = ''
  #prevOverflowX = ''
  #prevOverflowY = ''
  #momentumTimer = null
  #pendingRelocate = null
  #verticalDragPreview = null
  #cancelMomentumTimer() {
    if (this.#momentumTimer) {
      clearTimeout(this.#momentumTimer)
      this.#momentumTimer = null
    }
  }
  #disableMomentum() {
    this.#cancelMomentumTimer()
    if (this.#momentumDisabled) return
    const style = this.#container.style
    this.#prevOverflowScrolling = style.webkitOverflowScrolling
    this.#prevOverflowX = style.overflowX
    this.#prevOverflowY = style.overflowY
    style.webkitOverflowScrolling = 'auto'
    if (this.scrollProp === 'scrollLeft') style.overflowX = 'hidden'
    else style.overflowY = 'hidden'
    this.#momentumDisabled = true
  }
  #restoreMomentum() {
    this.#cancelMomentumTimer()
    if (!this.#momentumDisabled) return
    const style = this.#container.style
    style.webkitOverflowScrolling = this.#prevOverflowScrolling || 'touch'
    style.overflowX = this.#prevOverflowX || ''
    style.overflowY = this.#prevOverflowY || ''
    this.#prevOverflowScrolling = ''
    this.#prevOverflowX = ''
    this.#prevOverflowY = ''
    this.#momentumDisabled = false
  }
  constructor() {
    super()
    this.#root.innerHTML = `<style>
        :host {
            display: block;
            container-type: size;
        }
        :host, #top {
            box-sizing: border-box;
            overflow: hidden;
            width: 100%;
            height: 100%;
        }
        #top {
            height: 100%;
            // --_gap: 7%;
            background-color: var(--_background-color);
            --_max-inline-size: 720px;
            --_max-block-size: 1440px;
            --_max-column-count: 2;
            --_max-column-count-portrait: 1;
            --_max-column-count-spread: var(--_max-column-count);
            --_half-gap: calc(var(--_gap) / 2);
            --_max-width: calc(var(--_max-inline-size) * var(--_max-column-count-spread));
            --_max-height: var(--_max-block-size);
            display: grid;
            grid-template-columns:
                minmax(var(--_half-gap), 1fr)
                var(--_half-gap)
                minmax(0, calc(var(--_max-width) - var(--_gap)))
                var(--_half-gap)
                minmax(var(--_half-gap), 1fr);
            grid-template-rows:
                var(--_top-margin)
                1fr
                var(--_bottom-margin);
            &.vertical {
                --_max-column-count-spread: var(--_max-column-count-portrait);
                --_max-width: var(--_max-block-size);
                --_max-height: calc(var(--_max-inline-size) * var(--_max-column-count-spread));
            }
            @container (orientation: portrait) {
                & {
                    --_max-column-count-spread: var(--_max-column-count-portrait);
                }
                &.vertical {
                    --_max-column-count-spread: var(--_max-column-count);
                }
            }
        }
        #background {
            grid-column: 1 / -1;
            grid-row: 1 / -1;
        }
        #container {
            grid-column: 1 / -1;
            grid-row: 1 / -1;
            overflow-x: auto;
            overflow-y: hidden;
            -webkit-overflow-scrolling: touch;
            -ms-overflow-style: none;  /* Internet Explorer 10+ */
            scrollbar-width: none;  /* Firefox */
        }
        #container::-webkit-scrollbar {
            display: none;  /* Safari and Chrome */
        }
        :host([flow="scrolled"]) #container {
            grid-column: 1 / -1;
            grid-row: 2;
            overflow: auto;
        }
        :host([flow='scrolled'][no-continuous-scroll]) #container {
            overflow: hidden;
        }
        #header {
            grid-column: 3 / 4;
            grid-row: 1;
        }
        #footer {
            grid-column: 3 / 4;
            grid-row: 3;
            align-self: end;
        }
        #header, #footer {
            display: grid;
            height: var(--_margin);
        }
        :is(#header, #footer) > * {
            display: flex;
            align-items: center;
            min-width: 0;
        }
        :is(#header, #footer) > * > * {
            width: 100%;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            text-align: center;
            font-size: .75em;
            opacity: .6;
        }
        </style>
        <div id="top">
            <div id="background" part="filter"></div>
            <div id="container"></div>
        </div>
        `

    this.#top = this.#root.getElementById('top')
    this.#background = this.#root.getElementById('background')
    this.#container = this.#root.getElementById('container')
    // this.#header = this.#root.getElementById('header')
    // this.#footer = this.#root.getElementById('footer')

    this.#observer.observe(this.#container)
    this.#container.addEventListener('scroll', () => {
      if (this.#ignoreNativeScroll) return
      if (this.#justAnchored) {
        this.#justAnchored = false
        return
      }
      if (this.#pendingScrollFrame)
        cancelAnimationFrame(this.#pendingScrollFrame)
      this.#pendingScrollFrame = requestAnimationFrame(() => {
        this.#pendingScrollFrame = null
        this.#afterScroll('scroll')
        if (this.scrolled) this.#handleScrollBoundaries()
      })
    })

    const opts = { passive: false }
    this.addEventListener('touchstart', this.#onTouchStart.bind(this), opts)
    this.addEventListener('touchmove', this.#onTouchMove.bind(this), opts)
    this.addEventListener('touchend', this.#onTouchEnd.bind(this), opts)
    this.addEventListener('load', ({ detail: { doc } }) => {
      doc.addEventListener('touchstart', this.#onTouchStart.bind(this), opts)
      doc.addEventListener('touchmove', this.#onTouchMove.bind(this), opts)
      doc.addEventListener('touchend', this.#onTouchEnd.bind(this), opts)
    })

    this.#mediaQueryListener = () => {
      if (!this.#view) return
      this.#background.style.background = getBackground(this.getAttribute('bgimg-url'))
    }
    this.#mediaQuery.addEventListener('change', this.#mediaQueryListener)
  }
  attributeChangedCallback(name, _, value) {
    switch (name) {
      case 'flow':
        this.render()
        break
      case 'page-turn-axis':
        this.render()
        break
      case 'top-margin':
      case 'max-block-size':
      case 'background-color':
        this.#top.style.setProperty('--_' + name, value)
        break
      case 'bottom-margin':
      case 'gap':
      case 'max-column-count':
      case 'max-inline-size':
        // needs explicit `render()` as it doesn't necessarily resize
        this.#top.style.setProperty('--_' + name, value)
        this.render()
        break
    }
  }
  open(book) {
    this.bookDir = book.dir
    this.#pageProgressionRtl = book.dir === 'rtl'
    this.sections = book.sections
  }
  #createView() {
    this.#clearVerticalDragPreview()
    if (this.#view) {
      this.#view.destroy()
      this.#container.removeChild(this.#view.element)
    }
    this.#view = new View({
      container: this,
      onExpand: () => this.scrollToAnchor(this.#anchor),
    })
    this.#container.append(this.#view.element)
    return this.#view
  }
  #beforeRender({ vertical, rtl }) {
    this.#vertical = vertical
    const explicitPageProgressionDirection =
      globalThis.readflexPageProgressionDirection || this.bookDir
    const pageProgressionRtl = explicitPageProgressionDirection
      ? explicitPageProgressionDirection === 'rtl'
      : rtl
    this.#rtl = pageProgressionRtl
    this.#pageProgressionRtl = pageProgressionRtl
    this.#top.classList.toggle('vertical', vertical)

    // set background to `doc` background
    // this is needed because the iframe does not fill the whole element
    this.#background.style.background = getBackground(this.getAttribute('bgimg-url'))

    const { width, height } = this.#container.getBoundingClientRect()
    const size = vertical ? height : width

    const style = getComputedStyle(this.#top)
    const maxInlineSize = parseFloat(style.getPropertyValue('--_max-inline-size'))
    const maxColumnCount = parseInt(style.getPropertyValue('--_max-column-count'))
    const margin = parseFloat(style.getPropertyValue('--_top-margin'))
    this.#margin = margin

    const g = parseFloat(style.getPropertyValue('--_gap')) / 100
    // The gap will be a percentage of the #container, not the whole view.
    // This means the outer padding will be bigger than the column gap. Let
    // `a` be the gap percentage. The actual percentage for the column gap
    // will be (1 - a) * a. Let us call this `b`.
    //
    // To make them the same, we start by shrinking the outer padding
    // setting to `b`, but keep the column gap setting the same at `a`. Then
    // the actual size for the column gap will be (1 - b) * a. Repeating the
    // process again and again, we get the sequence
    //     x₁ = (1 - b) * a
    //     x₂ = (1 - x₁) * a
    //     ...
    // which converges to x = (1 - x) * a. Solving for x, x = a / (1 + a).
    // So to make the spacing even, we must shrink the outer padding with
    //     f(x) = x / (1 + x).
    // But we want to keep the outer padding, and make the inner gap bigger.
    // So we apply the inverse, f⁻¹ = -x / (x - 1) to the column gap.
    const gap = -g / (g - 1) * size

    const topMargin = parseFloat(style.getPropertyValue('--_top-margin'))
    const bottomMargin = parseFloat(style.getPropertyValue('--_bottom-margin'))

    const flow = this.getAttribute('flow')
    if (flow === 'scrolled') {
      const overflow = this.noContinuousScroll ? 'hidden' : 'auto'
      this.#container.style.overflowX = overflow
      this.#container.style.overflowY = overflow
    } else if (vertical) {
      this.#container.style.overflowX = 'hidden'
      this.#container.style.overflowY = 'auto'
    } else if (this.pageTurnAxisVertical) {
      this.#container.style.overflowX = 'hidden'
      this.#container.style.overflowY = 'hidden'
    } else {
      this.#container.style.overflowX = 'auto'
      this.#container.style.overflowY = 'hidden'
    }
    if (flow === 'scrolled') {
      // FIXME: vertical-rl only, not -lr
      this.setAttribute('dir', vertical ? 'rtl' : 'ltr')
      this.#top.style.padding = '0'
      const columnWidth = maxInlineSize

      this.heads = null
      this.feet = null
      // this.#header.replaceChildren()
      // this.#footer.replaceChildren()

      return { flow, margin, gap, columnWidth, topMargin, bottomMargin }
    }

    const divisor = maxColumnCount == 0
      ? Math.min(2, Math.ceil(size / maxInlineSize))
      : maxColumnCount

    const columnWidth = (size / divisor) - gap
    this.setAttribute('dir', this.#rtl ? 'rtl' : 'ltr')

    const marginalDivisor = vertical
      ? Math.min(2, Math.ceil(width / maxInlineSize))
      : divisor
    const marginalStyle = {
      gridTemplateColumns: `repeat(${marginalDivisor}, 1fr)`,
      gap: `${gap}px`,
      direction: this.#pageProgressionRtl ? 'rtl' : 'ltr',
    }
    // Object.assign(this.#header.style, marginalStyle)
    // Object.assign(this.#footer.style, marginalStyle)
    const heads = makeMarginals(marginalDivisor, 'head')
    const feet = makeMarginals(marginalDivisor, 'foot')
    this.heads = heads.map(el => el.children[0])
    this.feet = feet.map(el => el.children[0])
    // this.#header.replaceChildren(...heads)
    // this.#footer.replaceChildren(...feet)

    return { height, width, margin, gap, columnWidth, topMargin, bottomMargin }
  }
  render() {
    if (!this.#view) return
    this.#view.render(this.#beforeRender({
      vertical: this.#vertical,
      rtl: this.#rtl,
    }))
    this.scrollToAnchor(this.#anchor)
  }
  get scrolled() {
    return this.getAttribute('flow') === 'scrolled'
  }
  get noContinuousScroll() {
    return this.scrolled && this.hasAttribute('no-continuous-scroll')
  }
  get pageTurnAxisVertical() {
    return !this.scrolled
      && !this.#vertical
      && this.getAttribute('page-turn-axis') === 'vertical'
  }
  get scrollProp() {
    const { scrolled } = this
    return this.#vertical ? (scrolled ? 'scrollLeft' : 'scrollTop')
      : scrolled ? 'scrollTop' : 'scrollLeft'
  }
  get sideProp() {
    const { scrolled } = this
    return this.#vertical ? (scrolled ? 'width' : 'height')
      : scrolled ? 'height' : 'width'
  }
  get vertical() {
    return this.#vertical
  }
  get pageProgressionDirection() {
    return this.#pageProgressionRtl ? 'rtl' : 'ltr'
  }
  get size() {
    return this.#container.getBoundingClientRect()[this.sideProp]
  }
  get viewSize() {
    return this.#view.element.getBoundingClientRect()[this.sideProp]
  }
  get start() {
    return Math.abs(this.#container[this.scrollProp])
  }
  get end() {
    return this.start + this.size
  }
  get page() {
    return Math.floor(((this.start + this.end) / 2) / this.size)
  }
  get pages() {
    return Math.round(this.viewSize / this.size)
  }
  #scrollPageStepBy(dx, dy, state) {
    const prop = this.scrollProp
    const delta = prop === 'scrollLeft' ? dx : dy
    const originPage = state?.startPage ?? this.page
    const maxBookPage = Math.max(0, this.pages - 1)
    const minPage = Math.max(0, originPage - 1)
    const maxPage = Math.min(maxBookPage, originPage + 1)
    const invertOffset = this.#rtl && prop === "scrollLeft"
    const minOffset = this.size * (invertOffset ? -maxPage : minPage)
    const maxOffset = this.size * (invertOffset ? -minPage : maxPage)
    const lower = Math.min(minOffset, maxOffset)
    const upper = Math.max(minOffset, maxOffset)
    const nextOffset = this.#container[prop] + delta
    this.#container[prop] = Math.max(lower, Math.min(upper, nextOffset))
  }
  scrollBy(dx, dy) {
    const element = this.#container
    const prop = this.scrollProp
    const horizontal = prop === 'scrollLeft'
    const delta = horizontal ? dx : dy
    if (horizontal) element.scrollBy({ left: delta, top: 0, behavior: 'auto' })
    else element.scrollBy({ left: 0, top: delta, behavior: 'auto' })
  }
  #pageOffset(page) {
    const invertOffset = this.#rtl && this.scrollProp === 'scrollLeft'
    return this.size * (invertOffset ? -page : page)
  }
  #clearVerticalDragPreview({ resetCurrent = true } = {}) {
    this.#verticalDragPreview?.layer?.remove()
    this.#verticalDragPreview = null
    if (resetCurrent && this.#view?.element) {
      this.#view.element.style.transform = ''
      this.#view.element.style.willChange = ''
    }
  }
  #verticalDragPreviewExtent() {
    return this.#container.getBoundingClientRect().height
  }
  #verticalDragTargetPage(direction, startPage) {
    if (!direction || !this.pages) return null
    if (direction < 0 && this.atStart) return null
    if (direction > 0 && this.atEnd) return null
    const targetPage = startPage + direction
    return targetPage >= 0 && targetPage < this.pages ? targetPage : null
  }
  #ensureVerticalDragPreview(direction, targetPage) {
    if (this.#verticalDragPreview?.direction === direction
      && this.#verticalDragPreview?.targetPage === targetPage)
      return this.#verticalDragPreview

    this.#clearVerticalDragPreview({ resetCurrent: false })
    const layer = this.#view?.createPagePreview(this.#pageOffset(targetPage))
    if (!layer) return null

    this.#top.append(layer)
    this.#view.element.style.willChange = 'transform'
    this.#verticalDragPreview = { direction, targetPage, layer }
    return this.#verticalDragPreview
  }
  #updateVerticalDragPreview(deltaY, state) {
    const extent = this.#verticalDragPreviewExtent()
    if (!extent || !this.#view?.element) return false

    const clampedDelta = Math.max(-extent, Math.min(extent, deltaY))
    const direction = clampedDelta < 0 ? 1 : clampedDelta > 0 ? -1 : 0
    if (!direction) {
      this.#clearVerticalDragPreview()
      state.verticalPreview = null
      return true
    }

    const targetPage = this.#verticalDragTargetPage(
      direction,
      state.startPage ?? this.page,
    )
    const canCommit = targetPage != null
    const visualDelta = canCommit ? clampedDelta : clampedDelta * 0.24
    const preview = canCommit
      ? this.#ensureVerticalDragPreview(direction, targetPage)
      : null

    this.#view.element.style.willChange = 'transform'
    this.#view.element.style.transform = `translateY(${visualDelta}px)`
    if (preview?.layer) {
      preview.layer.style.transform = `translateY(${direction * extent + visualDelta}px)`
    }

    state.verticalPreview = {
      direction,
      targetPage,
      deltaY: visualDelta,
      canCommit,
    }
    return true
  }
  #finishVerticalDragPreview(state) {
    const info = state?.verticalPreview
    const extent = this.#verticalDragPreviewExtent()
    const viewElement = this.#view?.element
    if (!info || !viewElement || !extent) {
      this.#clearVerticalDragPreview()
      this.#restoreMomentum()
      return Promise.resolve()
    }

    const { direction, targetPage, deltaY, canCommit } = info
    const progress = Math.min(1, Math.abs(deltaY) / extent)
    const velocity = state?.vy ?? 0
    const velocityCommits = direction > 0
      ? velocity > 0.25
      : velocity < -0.25
    const shouldCommit = canCommit && targetPage != null
      && (progress >= 0.35 || velocityCommits)

    const preview = this.#verticalDragPreview
    const targetLayer = preview?.layer
    const targetStart = direction * extent + deltaY
    const currentEnd = shouldCommit ? -direction * extent : 0
    const targetEnd = shouldCommit ? 0 : direction * extent
    const duration = Math.max(140, Math.min(260, 240 * (shouldCommit
      ? Math.max(0.25, 1 - progress)
      : Math.max(0.35, progress))))

    return animate(0, 1, duration, easeOutSine, t => {
      const currentY = lerp(deltaY, currentEnd, t)
      const targetY = lerp(targetStart, targetEnd, t)
      viewElement.style.transform = `translateY(${currentY}px)`
      if (targetLayer) targetLayer.style.transform = `translateY(${targetY}px)`
    }).then(() => {
      if (shouldCommit) {
        this.#ignoreNativeScroll = true
        this.#container[this.scrollProp] = this.#pageOffset(targetPage)
        this.#ignoreNativeScroll = false
      }
      this.#clearVerticalDragPreview()
      this.#restoreMomentum()
      if (!shouldCommit) return

      this.#afterScroll('snap')
      const dir = targetPage <= 0 ? -1 : targetPage >= this.pages - 1 ? 1 : null
      if (dir) return this.#goTo({
        index: this.#adjacentIndex(dir),
        anchor: dir < 0 ? () => 1 : () => 0,
      })
    }).catch(err => {
      this.#clearVerticalDragPreview()
      this.#ignoreNativeScroll = false
      this.#restoreMomentum()
      throw err
    })
  }
  snap(vx, vy, touchState) {
    const state = touchState ?? this.#touchState
    const pageStep = this.noContinuousScroll
    const pageStepVertical = pageStep && this.scrollProp === "scrollTop"
    const verticalTurn = this.pageTurnAxisVertical
    const velocity = pageStep ? (pageStepVertical ? vy : vx) : verticalTurn || this.#vertical ? vy : vx
    const invertProgression = this.#pageProgressionRtl && !verticalTurn && !this.#vertical && !pageStepVertical
    const pageVelocity = invertProgression
      ? -velocity
      : velocity
    const { pages, size } = this
    if (!pages || size === 0) {
      this.#restoreMomentum()
      return
    }
    const currentOffset = this.#container[this.scrollProp]
    const invertOffset = this.#rtl && this.scrollProp === "scrollLeft"
    const signedOffset = invertOffset ? -currentOffset : currentOffset
    let page = Math.round(signedOffset / size)
    const velocityThreshold = 0.25
    if (Math.abs(pageVelocity) > velocityThreshold)
      page += pageVelocity > 0 ? 1 : -1
    const originPage = state?.startPage ?? this.page
    if (pageStep) {
      const deltaPages = page - originPage
      if (deltaPages > 1) page = originPage + 1
      else if (deltaPages < -1) page = originPage - 1
      const dir = page < 0 ? -1 : page >= pages ? 1 : null
      const adjacent = dir ? this.#adjacentIndex(dir) : null
      if (adjacent != null) return this.#goTo({
        index: adjacent,
        anchor: dir < 0 ? () => 1 : () => 0,
      })
      page = Math.max(0, Math.min(pages - 1, page))
      const targetOffset = page * size
      const distance = Math.abs(targetOffset - signedOffset)
      const baseDuration = 450
      const duration = Math.max(260, Math.min(380,
        baseDuration * (distance / (size || 1) + 0.2)))
      this.#disableMomentum()
      return this.#scrollToPage(page, "snap", {
        animate: true,
        duration,
        restoreMomentum: true,
        momentumDelay: 20,
        initialVelocity: velocity,
      })
    }
    if (!this.scrolled) {
      const deltaPages = page - originPage
      if (deltaPages > 1) page = originPage + 1
      else if (deltaPages < -1) page = originPage - 1
    }
    // Readflex patch: foliate-js sizes the section container as
    // `expandedSize + size * 2` and treats indices 0 and `pages - 1` as
    // swipe-overshoot buffers used to trigger the chapter transition.
    // Each buffer is only meaningful if there is a section to advance
    // INTO on that side — on the very first chapter, the prev-side
    // buffer leads nowhere and a swipe past page 1 just lands on a
    // blank page. Same with the next-side buffer on the last chapter,
    // and both buffers on a single-section EPUB (article → EPUB).
    // Suppress snap-target into a buffer when the matching neighbour
    // is absent; keep it reachable otherwise so the post-snap
    // `page >= pages - 1` check can still fire chapter advance.
    const noPrevNeighbour = this.#adjacentIndex(-1) == null
    const noNextNeighbour = this.#adjacentIndex(1) == null
    const minPage = noPrevNeighbour ? 1 : 0
    const maxPage = noNextNeighbour ? pages - 2 : pages - 1
    page = Math.max(minPage, Math.min(maxPage, page))
    const targetOffset = page * size
    const distance = Math.abs(targetOffset - signedOffset)
    const baseDuration = 450
    const duration = Math.max(260, Math.min(380,
      baseDuration * (distance / (size || 1) + 0.2)))

    this.#disableMomentum()
    return this.#scrollToPage(page, 'snap', { animate: true, duration, restoreMomentum: true, momentumDelay: 20, initialVelocity: velocity }).then(() => {
      const dir = page <= 0 ? -1 : page >= pages - 1 ? 1 : null
      if (dir) return this.#goTo({
        index: this.#adjacentIndex(dir),
        anchor: dir < 0 ? () => 1 : () => 0,
      })
    })
  }
  #onTouchStart(e) {
    const touch = e.changedTouches[0]
    const scrollProp = this.scrollProp
    this.#touchState = {
      x: touch?.screenX, y: touch?.screenY,
      t: e.timeStamp,
      vx: 0, vy: 0,
      pinched: false,
      direction: 'none',
      startTouch: {
        x: e.touches[0].screenX,
        y: e.touches[0].screenY,
      },
      delta: { x: 0, y: 0 },
      startScroll: this.#container[scrollProp],
      startPage: this.page,
      lockedOffset: null,
      axis: scrollProp,
    }
    this.dispatchEvent(new CustomEvent('doctouchstart', {
      detail: {
        touch: e.changedTouches[0],
        touchState: this.#touchState,
      },
      bubbles: true,
      composed: true
    }))
  }
  #onTouchMove(e) {
    if (window.getSelection()?.toString()) return

    const touch = e.changedTouches[0]
    const state = this.#touchState
    if (!state) return

    const deltaX = touch.screenX - state.startTouch.x
    const deltaY = touch.screenY - state.startTouch.y

    const absDeltaX = Math.abs(deltaX);
    const absDeltaY = Math.abs(deltaY);

    state.delta.x = deltaX
    state.delta.y = deltaY



    const threshold = 5

    const notHorizontal = state.direction === 'horizontal' && absDeltaY > absDeltaX;
    const notVertical = state.direction === 'vertical' && absDeltaX > absDeltaY;

    if (state.direction !== 'none' || (notHorizontal && notVertical)) {
      if (absDeltaX < threshold && absDeltaY < threshold) return;
    }

    if ((absDeltaX > threshold || absDeltaY > threshold) && state.direction === 'none') {
      if (absDeltaX > absDeltaY) {
        state.direction = 'horizontal'
      } else {
        state.direction = 'vertical'
        if (this.scrollProp === 'scrollLeft' && state.lockedOffset == null)
          state.lockedOffset = state.startScroll ?? this.#container.scrollLeft
      }
    }

    const axisProp = this.scrollProp
    state.axis = axisProp
    const horizontalAxis = axisProp === 'scrollLeft'
    const verticalAxis = axisProp === 'scrollTop'
    const horizontalDrag = state.direction === 'horizontal'
    const verticalDrag = state.direction === 'vertical'

    const forwarded = new CustomEvent('doctouchmove', {
      detail: {
        touch,
        touchState: state,
      },
      preventDefault: () => e.preventDefault(),
      bubbles: true,
      composed: true
    })
    this.dispatchEvent(forwarded)

    if (state.pinched) return
    state.pinched = globalThis.visualViewport.scale > 1
    if (state.pinched) return

    if (e.touches.length > 1) {
      if (this.#touchScrolled) e.preventDefault()
      return
    }

    const dt = e.timeStamp - state.t || 16.7
    const stepX = state.x - touch.screenX
    const stepY = state.y - touch.screenY
    state.x = touch.screenX
    state.y = touch.screenY
    state.t = e.timeStamp
    state.vx = stepX / dt
    state.vy = stepY / dt

    if (this.noContinuousScroll) {
      const pageStepDrag = horizontalAxis && horizontalDrag
        || verticalAxis && verticalDrag
      if (pageStepDrag) {
        e.preventDefault()
        this.#touchScrolled = true
        this.#disableMomentum()
        this.#scrollPageStepBy(stepX, stepY, state)
      }
      return
    }

    if (this.scrolled) return

    if (horizontalDrag && horizontalAxis && this.pageTurnAxisVertical) {
      e.preventDefault()
      this.#disableMomentum()
      if (state.lockedOffset == null)
        state.lockedOffset = state.startScroll ?? this.#container.scrollLeft
      this.#container.scrollLeft = state.lockedOffset
      return
    }

    if (verticalDrag && horizontalAxis) {
      e.preventDefault()
      this.#disableMomentum()
      if (state.lockedOffset == null)
        state.lockedOffset = state.startScroll ?? this.#container.scrollLeft
      this.#touchScrolled = this.pageTurnAxisVertical
      this.#container.scrollLeft = state.lockedOffset
      if (this.pageTurnAxisVertical) {
        this.#updateVerticalDragPreview(deltaY, state)
      }
      return
    }

    if (verticalDrag && verticalAxis) {
      this.#touchScrolled = true
      return
    }

    if (horizontalDrag && horizontalAxis) {
      this.#touchScrolled = true
      if (this.#pageProgressionRtl) {
        e.preventDefault()
        this.#disableMomentum()
        const startScroll = state.startScroll ?? this.#container.scrollLeft
        this.#container.scrollLeft = startScroll - deltaX
      }
      // LTR relies on native scrolling for horizontal paging. RTL is handled
      // manually above because WebKit/Chromium scrollLeft direction differs
      // from physical page progression for right-to-left books.
    }
  }
  #onTouchEnd(e) {
    const state = this.#touchState
    this.dispatchEvent(new CustomEvent('doctouchend', {
      detail: {
        touch: e.changedTouches[0],
        touchState: state,
      },
      bubbles: true,
      composed: true
    }))

    this.#touchScrolled = false
    if (this.scrolled && !this.noContinuousScroll) {
      this.#touchState = null
      return
    }

    const verticalLocked = state?.direction === 'vertical'
      && state.axis === 'scrollLeft'
      && state.lockedOffset != null

    const horizontalLocked = state?.direction === 'horizontal'
      && state.axis === 'scrollLeft'
      && state.lockedOffset != null
      && this.pageTurnAxisVertical

    if ((verticalLocked && !this.pageTurnAxisVertical) || horizontalLocked) {
      // restore original horizontal position and skip snapping to avoid accidental page turns
      this.#container.scrollLeft = state.lockedOffset
      this.#restoreMomentum()
      this.#touchState = null
      if (this.#pendingRelocate) {
        const detail = this.#pendingRelocate
        this.#pendingRelocate = null
        this.dispatchEvent(new CustomEvent('relocate', { detail }))
      }
      return
    }

    if (this.pageTurnAxisVertical && state?.verticalPreview) {
      Promise.resolve(this.#finishVerticalDragPreview(state))
        .finally(() => { this.#touchState = null })
      return
    }


    // XXX: Firefox seems to report scale as 1... sometimes...?
    // at this point I'm basically throwing `requestAnimationFrame` at
    // anything that doesn't work
    requestAnimationFrame(() => {
      if (globalThis.visualViewport.scale === 1 && state)
        Promise.resolve(this.snap(state.vx, state.vy, state))
          .finally(() => { this.#touchState = null })
      else this.#touchState = null
    })
  }
  // allows one to process rects as if they were LTR and horizontal
  #getRectMapper() {
    if (this.scrolled) {
      const size = this.viewSize
      const margin = this.#margin
      return this.#vertical
        ? ({ left, right }) =>
          ({ left: size - right - margin, right: size - left - margin })
        : ({ top, bottom }) => ({ left: top + margin, right: bottom + margin })
    }
    const pxSize = this.pages * this.size
    return this.#rtl
      ? ({ left, right }) =>
        ({ left: pxSize - right, right: pxSize - left })
      : this.#vertical
        ? ({ top, bottom }) => ({ left: top, right: bottom })
        : f => f
  }
  async #scrollToRect(rect, reason) {
    if (this.scrolled) {
      const offset = this.#getRectMapper()(rect).left - this.#margin
      return this.#scrollTo(offset, reason)
    }
    const mappedRect = this.#getRectMapper()(rect)
    const left = mappedRect.left
    const pageIndex = Math.floor(left / this.size)
    const pageStart = pageIndex * this.size
    const pageEnd = pageStart + this.size
    const nudgedLeft = Math.min(left + this.#margin / 2, pageEnd - 1)
    const normalizedLeft = Math.max(pageStart, nudgedLeft)
    return this.#scrollToPage(Math.floor(normalizedLeft / this.size) + (this.#rtl ? -1 : 1), reason)
  }
  async #scrollTo(offset, reason, smooth) {
    const element = this.#container
    const { scrollProp, size } = this
    this.#ignoreNativeScroll = true
    const opts = typeof smooth === 'object' ? smooth ?? {} : {}
    const shouldAnimate = opts.animate ?? (reason === 'snap' || smooth === true)
    const easing = opts.easing ?? (reason === 'page' ? easeInOutSine : easeOutSine)
    const finish = () => {
      this.#afterScroll(reason)
      this.#ignoreNativeScroll = false
      if (reason === 'snap' || opts.restoreMomentum) {
        const delay = opts.momentumDelay ?? 20
        this.#cancelMomentumTimer()
        this.#momentumTimer = setTimeout(() => {
          this.#restoreMomentum()
        }, delay)
      }
    }
    if (reason === 'snap' || opts.disableMomentum) this.#disableMomentum()

    const previousBehavior = element.style.scrollBehavior
    if (shouldAnimate) element.style.scrollBehavior = 'auto'

    if (Math.abs(element[scrollProp] - offset) < 1) {
      finish()
      element.style.scrollBehavior = previousBehavior
      return
    }

    // FIXME: vertical-rl only, not -lr
    if (this.scrolled && this.#vertical) offset = -offset

    const useAnimation = shouldAnimate && this.hasAttribute('animated')
    const propKey = scrollProp === 'scrollLeft' ? 'left' : 'top'

    if (useAnimation) {
      const distance = Math.abs(element[scrollProp] - offset)
      const baseDuration = reason === 'page' ? 360 : 300
      const minDuration = reason === 'page' ? 260 : 200
      const maxDuration = reason === 'page' ? 460 : 400
      const adaptiveDuration = opts.duration ?? Math.min(
        maxDuration,
        Math.max(minDuration, baseDuration * (distance / (size || 1)))
      )

      // Give the snap animation an initial kick based on release velocity so it
      // doesn't start from a standstill and then accelerate.
      const averageSpeed = adaptiveDuration ? distance / adaptiveDuration : 0
      const initialSpeed = Math.abs(opts.initialVelocity ?? 0) * 0.3
      const initialProgress = averageSpeed > 0
        ? Math.min(0.45, (initialSpeed / averageSpeed) * 0.2)
        : 0

      if (this.pageTurnAxisVertical && (reason === 'page' || reason === 'snap')) {
        const startOffset = element[scrollProp]
        const direction = opts.verticalPageDirection
          || (offset > startOffset ? 1 : -1)
        const extent = this.#verticalDragPreviewExtent() || size
        const viewElement = this.#view?.element
        const targetLayer = this.#view?.createPagePreview(offset)
        if (viewElement && targetLayer) {
          this.#justAnchored = true
          viewElement.style.willChange = 'transform'
          targetLayer.style.transform = `translateY(${direction * extent}px)`
          this.#top.append(targetLayer)

          return animate(0, 1, adaptiveDuration, easing, t => {
            viewElement.style.transform = `translateY(${lerp(0, -direction * extent, t)}px)`
            targetLayer.style.transform = `translateY(${lerp(direction * extent, 0, t)}px)`
          }, { initialProgress }).then(() => {
            element[scrollProp] = offset
            viewElement.style.transform = ''
            viewElement.style.willChange = ''
            targetLayer.remove()
            return wait(10)
          }).then(() => {
            finish()
            element.style.scrollBehavior = previousBehavior
          }).catch(err => {
            viewElement.style.transform = ''
            viewElement.style.willChange = ''
            targetLayer.remove()
            this.#ignoreNativeScroll = false
            this.#restoreMomentum()
            element.style.scrollBehavior = previousBehavior
            throw err
          })
        }
      }

      // Prefer native smooth scroll (runs on compositor and can keep 120Hz on Safari)
      const isSafari = /^(?!.*(Chrome|CriOS|Edg|Edge)).*AppleWebKit/i.test(navigator.userAgent)
      const supportsSmooth = 'scrollBehavior' in document.documentElement.style && isSafari
      if (supportsSmooth && reason !== 'page' && !opts.forceJsAnimation) {
        this.#justAnchored = true
        element.style.scrollBehavior = 'smooth'
        element.scrollTo({ [propKey]: offset, behavior: 'smooth' })

        // Resolve when we get close to target or after the expected duration.
        return new Promise(resolve => {
          const start = performance.now()
          const check = now => {
            const done = Math.abs(element[scrollProp] - offset) < 0.5
              || now - start > adaptiveDuration + 120
            if (done) resolve()
            else requestAnimationFrame(check)
          }
          requestAnimationFrame(check)
        }).then(() => {
          element[scrollProp] = offset
          return wait(10)
        }).then(() => {
          finish()
          element.style.scrollBehavior = previousBehavior
        })
      }

      this.#justAnchored = true

      return animate(
        element[scrollProp],
        offset,
        adaptiveDuration,
        easing,
        x => element[scrollProp] = x,
        { initialProgress },
      ).then(() => {
        element[scrollProp] = offset
        return wait(10)
      }).then(() => {
        finish()
        element.style.scrollBehavior = previousBehavior
      }).catch(err => {
        this.#ignoreNativeScroll = false
        this.#restoreMomentum()
        element.style.scrollBehavior = previousBehavior
        throw err
      })
    } else {
      element.style.scrollBehavior = 'auto'
      element[scrollProp] = offset
      finish()
      element.style.scrollBehavior = previousBehavior
    }
  }
  async #scrollToPage(page, reason, smooth) {
    const opts = typeof smooth === 'object' ? { ...smooth } : smooth
    if (this.pageTurnAxisVertical && opts && typeof opts === 'object') {
      const currentPage = this.page
      const direction = page > currentPage ? 1 : page < currentPage ? -1 : 0
      if (direction) opts.verticalPageDirection = direction
    }
    return this.#scrollTo(this.#pageOffset(page), reason, opts)
  }
  async scrollToAnchor(anchor, select) {
    this.#anchor = anchor
    const rects = uncollapse(anchor)?.getClientRects?.()
    // if anchor is an element or a range
    if (rects) {
      // when the start of the range is immediately after a hyphen in the
      // previous column, there is an extra zero width rect in that column
      const rect = Array.from(rects)
        .find(r => r.width > 0 && r.height > 0) || rects[0]
      if (!rect) return
      await this.#scrollToRect(rect, 'anchor')
      if (select) this.#selectAnchor()
      return
    }
    // if anchor is a fraction
    if (this.scrolled) {
      await this.#scrollTo(anchor * this.viewSize, 'anchor')
      return
    }
    const { pages } = this
    if (!pages) return
    const textPages = pages - 2
    const newPage = Math.round(anchor * (textPages - 1))
    await this.#scrollToPage(newPage + 1, 'anchor')
  }
  #selectAnchor() {
    const { defaultView } = this.#view.document
    if (this.#anchor.startContainer) {
      const sel = defaultView.getSelection()
      sel.removeAllRanges()
      sel.addRange(this.#anchor)
    }
  }
  #getVisibleRange() {
    if (this.scrolled) return getVisibleRange(this.#view.document,
      this.start + this.#margin, this.end - this.#margin, this.#getRectMapper())
    const size = this.#rtl ? -this.size : this.size
    return getVisibleRange(this.#view.document,
      this.start - size, this.end - size, this.#getRectMapper())
  }
  #afterScroll(reason) {
    const range = this.#getVisibleRange()
    if (!range) return
    // don't set new anchor if relocation was to scroll to anchor
    if (reason !== 'anchor') this.#anchor = range
    else this.#justAnchored = true

    const index = this.#index
    const detail = { reason, range, index }
    if (this.scrolled) detail.fraction = this.start / this.viewSize
    else if (this.pages > 0) {
      const { page, pages } = this
      // this.#header.style.visibility = page > 1 ? 'visible' : 'hidden'
      detail.fraction = (page - 1) / (pages - 2)
      detail.size = 1 / (pages - 2)
    }
    if (!this.scrolled && reason === 'scroll' && (this.#touchState || this.#touchScrolled)) {
      this.#pendingRelocate = detail
      return
    }

    this.#pendingRelocate = null
    this.dispatchEvent(new CustomEvent('relocate', { detail }))
  }
  #handleScrollBoundaries() {
    // if (!this.scrolled || this.#locked) return
    
    // // Only trigger transitions when very close to boundaries (95% through)
    // const threshold = Math.min(50, this.size * 0.05) // Small threshold or 5% of size
    // const atEnd = this.viewSize - this.end <= threshold
    // const atStart = this.start <= threshold
    
    // // Only auto-load if we're actually at the boundary, not just approaching
    // if (atEnd && !this.#loadingNext) {
    //   const nextIndex = this.#adjacentIndex(1)
    //   if (nextIndex != null) {
    //     this.#loadingNext = true
    //     // Small delay to ensure scroll has finished
    //     setTimeout(() => {
    //       this.#goTo({
    //         index: nextIndex,
    //         anchor: () => 0,
    //       }).then(() => {
    //         this.#loadingNext = false
    //       }).catch(() => {
    //         this.#loadingNext = false
    //       })
    //     }, 200)
    //   }
    // }
    
    // if (atStart && !this.#loadingPrev) {
    //   const prevIndex = this.#adjacentIndex(-1)
    //   if (prevIndex != null) {
    //     this.#loadingPrev = true
    //     setTimeout(() => {
    //       this.#goTo({
    //         index: prevIndex,
    //         anchor: () => 1,
    //       }).then(() => {
    //         this.#loadingPrev = false
    //       }).catch(() => {
    //         this.#loadingPrev = false
    //       })
    //     }, 200)
    //   }
    // }
  }
  async #display(promise) {
    const { index, src, anchor, onLoad, select } = await promise
    this.#index = index
    if (src) {
      const view = this.#createView()
      const afterLoad = doc => {
        if (doc.head) {
          const $styleBefore = doc.createElement('style')
          doc.head.prepend($styleBefore)
          const $style = doc.createElement('style')
          doc.head.append($style)
          this.#styleMap.set(doc, [$styleBefore, $style])
        }
        onLoad?.({ doc, index })
      }
      const beforeRender = this.#beforeRender.bind(this)
      await view.load(src, afterLoad, beforeRender)
      this.dispatchEvent(new CustomEvent('create-overlayer', {
        detail: {
          doc: view.document, index,
          attach: overlayer => view.overlayer = overlayer,
        },
      }))
      this.#view = view
    }
    await this.scrollToAnchor((typeof anchor === 'function'
      ? anchor(this.#view.document) : anchor) ?? 0, select)
  }
  #canGoToIndex(index) {
    return index >= 0 && index <= this.sections.length - 1
  }
  async #goTo({ index, anchor, select }) {
    // Readflex patch: callers (snap post-callback, next/prev) compute
    // `index` from `#adjacentIndex(dir)`, which returns undefined when
    // there is no linear neighbour. Without this guard, `sections[undefined].load()`
    // below throws "Cannot read properties of undefined (reading 'load')"
    // and the paginator stops accepting further navigation.
    if (index == null || !this.sections[index]) return
    if (index === this.#index) await this.#display({ index, anchor, select })
    else {
      const oldIndex = this.#index
      const onLoad = detail => {
        this.sections[oldIndex]?.unload?.()
        this.setStyles(this.#styles)
        this.dispatchEvent(new CustomEvent('load', { detail }))
      }
      await this.#display(Promise.resolve(this.sections[index].load())
        .then(src => ({ index, src, anchor, onLoad, select }))
        .catch(e => {
          console.warn(e)
          console.warn(new Error(`Failed to load section ${index}`))
          return {}
        }))
    }
  }
  async goTo(target) {
    if (this.#locked) return
    const resolved = await target
    if (this.#canGoToIndex(resolved.index)) return this.#goTo(resolved)
  }
  #scrollPrev(distance) {
    if (!this.#view) return true
    if (this.scrolled) {
      if (this.start > 0) return this.#scrollTo(
        Math.max(0, this.start - (distance ?? this.size)), null, { animate: true })
      return !this.atStart
    }
    if (this.atStart) return false
    const page = this.page - 1
    if (page <= 0) return this.#adjacentIndex(-1) != null
    return this.#scrollToPage(page, 'page', { animate: true }).then(() => false)
  }
  #scrollNext(distance) {
    if (!this.#view) return true
    if (this.scrolled) {
      if (this.viewSize - this.end > 2) return this.#scrollTo(
        Math.min(this.viewSize, distance ? this.start + distance : this.end), null, { animate: true })
      return !this.atEnd
    }
    if (this.atEnd) return false
    const page = this.page + 1
    const pages = this.pages
    if (page >= pages - 1) return this.#adjacentIndex(1) != null
    return this.#scrollToPage(page, 'page', { animate: true }).then(() => false)
  }
  get atStart() {
    return this.#adjacentIndex(-1) == null && this.page <= 1
  }
  get atEnd() {
    return this.#adjacentIndex(1) == null && this.page >= this.pages - 2
  }
  #adjacentIndex(dir) {
    for (let index = this.#index + dir; this.#canGoToIndex(index); index += dir)
      if (this.sections[index]?.linear !== 'no') return index
  }
  async #turnPage(dir, distance) {
    if (this.#locked) return
    this.#locked = true
    try {
      const prev = dir === -1
      const shouldGo = await (prev ? this.#scrollPrev(distance) : this.#scrollNext(distance))

      if (shouldGo) await this.#goTo({
        index: this.#adjacentIndex(dir),
        anchor: prev ? () => 1 : () => 0,
      })
      if (shouldGo || !this.hasAttribute('animated')) await wait(100)
    } finally {
      this.#locked = false
    }
  }
  prev(distance) {
    return this.#turnPage(-1, distance)
  }
  next(distance) {
    return this.#turnPage(1, distance)
  }
  prevSection() {
    return this.goTo({ index: this.#adjacentIndex(-1) })
  }
  nextSection() {
    return this.goTo({ index: this.#adjacentIndex(1) })
  }
  firstSection() {
    const index = this.sections.findIndex(section => section.linear !== 'no')
    return this.goTo({ index })
  }
  lastSection() {
    const index = this.sections.findLastIndex(section => section.linear !== 'no')
    return this.goTo({ index })
  }
  getContents() {
    if (this.#view) return [{
      index: this.#index,
      overlayer: this.#view.overlayer,
      doc: this.#view.document,
    }]
    return []
  }
  setStyles(styles) {
    this.#styles = styles
    const $$styles = this.#styleMap.get(this.#view?.document)
    if (!$$styles) return
    const [$beforeStyle, $style] = $$styles
    if (Array.isArray(styles)) {
      const [beforeStyle, style] = styles
      $beforeStyle.textContent = beforeStyle
      $style.textContent = style
    } else $style.textContent = styles

    this.#background.style.background = getBackground(this.getAttribute('bgimg-url'))

    // needed because the resize observer doesn't work in Firefox
    this.#view?.document?.fonts?.ready?.then(() => this.#view.expand())
  }
  get writingMode() {
    return this.#view?.writingMode
  }
  destroy() {
    this.#clearVerticalDragPreview()
    this.#observer.unobserve(this)
    this.#view.destroy()
    this.#view = null
    this.sections[this.#index]?.unload?.()
    this.#mediaQuery.removeEventListener('change', this.#mediaQueryListener)
    if (this.#pendingScrollFrame) {
      cancelAnimationFrame(this.#pendingScrollFrame)
      this.#pendingScrollFrame = null
    }
    this.#restoreMomentum()
    this.#pendingRelocate = null
  }
}

customElements.define('foliate-paginator', Paginator)
