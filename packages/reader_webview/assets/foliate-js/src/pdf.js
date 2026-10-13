import './vendor/pdfjs/pdf.js'
import { createPdfPageCache } from './readflex_pdf_page_cache.js'
import { PAGE_CONTENT_SAMPLE_SIZE, detectContentBox } from './readflex_page_content.js'
import { applyPageColors, samePageColors } from './readflex_page_colors.js'
import { SHARPEN_THRESHOLD, tileCovers, tileFor } from './readflex_page_geometry.js'

const { pdfjsLib } = globalThis
// Module scripts have no document.currentScript for PDF.js to infer this path.
pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/pdf.worker.js', import.meta.url).href

// https://github.com/mozilla/pdf.js/blob/f04967017f22e46d70d11468dd928b4cdc2f6ea1/web/text_layer_builder.css
const textLayerBuilderCSS = `
/* Copyright 2014 Mozilla Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

:root {
  --highlight-bg-color: rgb(180 0 170);
  --highlight-selected-bg-color: rgb(0 100 0);
}

@media screen and (forced-colors: active) {
  :root {
    --highlight-bg-color: Highlight;
    --highlight-selected-bg-color: ButtonText;
  }
}

.textLayer {
  position: absolute;
  text-align: initial;
  inset: 0;
  overflow: hidden;
  opacity: 0.25;
  line-height: 1;
  text-size-adjust: none;
  forced-color-adjust: none;
  transform-origin: 0 0;
  z-index: 2;
}

.textLayer :is(span, br) {
  color: transparent;
  position: absolute;
  white-space: pre;
  cursor: text;
  transform-origin: 0% 0%;
}

/* Only necessary in Google Chrome, see issue 14205, and most unfortunately
 * the problem doesn't show up in "text" reference tests. */
/*#if !MOZCENTRAL*/
.textLayer span.markedContent {
  top: 0;
  height: 0;
}
/*#endif*/

.textLayer .highlight {
  margin: -1px;
  padding: 1px;
  background-color: var(--highlight-bg-color);
  border-radius: 4px;
}

.textLayer .highlight.appended {
  position: initial;
}

.textLayer .highlight.begin {
  border-radius: 4px 0 0 4px;
}

.textLayer .highlight.end {
  border-radius: 0 4px 4px 0;
}

.textLayer .highlight.middle {
  border-radius: 0;
}

.textLayer .highlight.selected {
  background-color: var(--highlight-selected-bg-color);
}

.textLayer ::selection {
  /*#if !MOZCENTRAL*/
  background: blue;
  /*#endif*/
  background: AccentColor; /* stylelint-disable-line declaration-block-no-duplicate-properties */
}

/* Avoids https://github.com/mozilla/pdf.js/issues/13840 in Chrome */
/*#if !MOZCENTRAL*/
.textLayer br::selection {
  background: transparent;
}
/*#endif*/

.textLayer .endOfContent {
  display: block;
  position: absolute;
  inset: 100% 0 0;
  z-index: -1;
  cursor: default;
  user-select: none;
}

.textLayer .endOfContent.active {
  top: 0;
}
`

//https://github.com/mozilla/pdf.js/blob/d64f223d034ad74fb62571c3acff566d25eca413/web/annotation_layer_builder.css
const annotationLayerBuilderCSS = `
/* Copyright 2014 Mozilla Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

:root {
  --annotation-unfocused-field-background: url("data:image/svg+xml;charset=UTF-8,<svg width='1px' height='1px' xmlns='http://www.w3.org/2000/svg'><rect width='100%' height='100%' style='fill:rgba(0, 54, 255, 0.13);'/></svg>");
  --input-focus-border-color: Highlight;
  --input-focus-outline: 1px solid Canvas;
  --input-unfocused-border-color: transparent;
  --input-disabled-border-color: transparent;
  --input-hover-border-color: black;
  --link-outline: none;
}

@media screen and (forced-colors: active) {
  :root {
    --input-focus-border-color: CanvasText;
    --input-unfocused-border-color: ActiveText;
    --input-disabled-border-color: GrayText;
    --input-hover-border-color: Highlight;
    --link-outline: 1.5px solid LinkText;
    --hcm-highligh-filter: invert(100%);
  }
  .annotationLayer .textWidgetAnnotation :is(input, textarea):required,
  .annotationLayer .choiceWidgetAnnotation select:required,
  .annotationLayer
    .buttonWidgetAnnotation:is(.checkBox, .radioButton)
    input:required {
    outline: 1.5px solid selectedItem;
  }

  .annotationLayer .linkAnnotation:hover {
    backdrop-filter: var(--hcm-highligh-filter);
  }

  .annotationLayer .linkAnnotation > a:hover {
    opacity: 0 !important;
    background: none !important;
    box-shadow: none;
  }

  .annotationLayer .popupAnnotation .popup {
    outline: calc(1.5px * var(--scale-factor)) solid CanvasText !important;
    background-color: ButtonFace !important;
    color: ButtonText !important;
  }

  .annotationLayer .highlightArea:hover::after {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    backdrop-filter: var(--hcm-highligh-filter);
    content: "";
    pointer-events: none;
  }

  .annotationLayer .popupAnnotation.focused .popup {
    outline: calc(3px * var(--scale-factor)) solid Highlight !important;
  }
}

.annotationLayer {
  position: absolute;
  top: 0;
  left: 0;
  pointer-events: none;
  transform-origin: 0 0;
  z-index: 3;
}

.annotationLayer[data-main-rotation="90"] .norotate {
  transform: rotate(270deg) translateX(-100%);
}
.annotationLayer[data-main-rotation="180"] .norotate {
  transform: rotate(180deg) translate(-100%, -100%);
}
.annotationLayer[data-main-rotation="270"] .norotate {
  transform: rotate(90deg) translateY(-100%);
}

.annotationLayer canvas {
  position: absolute;
  width: 100%;
  height: 100%;
  pointer-events: none;
}

.annotationLayer section {
  position: absolute;
  text-align: initial;
  pointer-events: auto;
  box-sizing: border-box;
  transform-origin: 0 0;
}

.annotationLayer .linkAnnotation {
  outline: var(--link-outline);
}

.annotationLayer :is(.linkAnnotation, .buttonWidgetAnnotation.pushButton) > a {
  position: absolute;
  font-size: 1em;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.annotationLayer
  :is(.linkAnnotation, .buttonWidgetAnnotation.pushButton):not(.hasBorder)
  > a:hover {
  opacity: 0.2;
  background-color: rgb(255 255 0);
  box-shadow: 0 2px 10px rgb(255 255 0);
}

.annotationLayer .linkAnnotation.hasBorder:hover {
  background-color: rgb(255 255 0 / 0.2);
}

.annotationLayer .hasBorder {
  background-size: 100% 100%;
}

.annotationLayer .textAnnotation img {
  position: absolute;
  cursor: pointer;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea),
.annotationLayer .choiceWidgetAnnotation select,
.annotationLayer .buttonWidgetAnnotation:is(.checkBox, .radioButton) input {
  background-image: var(--annotation-unfocused-field-background);
  border: 2px solid var(--input-unfocused-border-color);
  box-sizing: border-box;
  font: calc(9px * var(--scale-factor)) sans-serif;
  height: 100%;
  margin: 0;
  vertical-align: top;
  width: 100%;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea):required,
.annotationLayer .choiceWidgetAnnotation select:required,
.annotationLayer
  .buttonWidgetAnnotation:is(.checkBox, .radioButton)
  input:required {
  outline: 1.5px solid red;
}

.annotationLayer .choiceWidgetAnnotation select option {
  padding: 0;
}

.annotationLayer .buttonWidgetAnnotation.radioButton input {
  border-radius: 50%;
}

.annotationLayer .textWidgetAnnotation textarea {
  resize: none;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea)[disabled],
.annotationLayer .choiceWidgetAnnotation select[disabled],
.annotationLayer
  .buttonWidgetAnnotation:is(.checkBox, .radioButton)
  input[disabled] {
  background: none;
  border: 2px solid var(--input-disabled-border-color);
  cursor: not-allowed;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea):hover,
.annotationLayer .choiceWidgetAnnotation select:hover,
.annotationLayer
  .buttonWidgetAnnotation:is(.checkBox, .radioButton)
  input:hover {
  border: 2px solid var(--input-hover-border-color);
}
.annotationLayer .textWidgetAnnotation :is(input, textarea):hover,
.annotationLayer .choiceWidgetAnnotation select:hover,
.annotationLayer .buttonWidgetAnnotation.checkBox input:hover {
  border-radius: 2px;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea):focus,
.annotationLayer .choiceWidgetAnnotation select:focus {
  background: none;
  border: 2px solid var(--input-focus-border-color);
  border-radius: 2px;
  outline: var(--input-focus-outline);
}

.annotationLayer .buttonWidgetAnnotation:is(.checkBox, .radioButton) :focus {
  background-image: none;
  background-color: transparent;
}

.annotationLayer .buttonWidgetAnnotation.checkBox :focus {
  border: 2px solid var(--input-focus-border-color);
  border-radius: 2px;
  outline: var(--input-focus-outline);
}

.annotationLayer .buttonWidgetAnnotation.radioButton :focus {
  border: 2px solid var(--input-focus-border-color);
  outline: var(--input-focus-outline);
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::before,
.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::after,
.annotationLayer .buttonWidgetAnnotation.radioButton input:checked::before {
  background-color: CanvasText;
  content: "";
  display: block;
  position: absolute;
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::before,
.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::after {
  height: 80%;
  left: 45%;
  width: 1px;
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::before {
  transform: rotate(45deg);
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::after {
  transform: rotate(-45deg);
}

.annotationLayer .buttonWidgetAnnotation.radioButton input:checked::before {
  border-radius: 50%;
  height: 50%;
  left: 30%;
  top: 20%;
  width: 50%;
}

.annotationLayer .textWidgetAnnotation input.comb {
  font-family: monospace;
  padding-left: 2px;
  padding-right: 0;
}

.annotationLayer .textWidgetAnnotation input.comb:focus {
  /*
   * Letter spacing is placed on the right side of each character. Hence, the
   * letter spacing of the last character may be placed outside the visible
   * area, causing horizontal scrolling. We avoid this by extending the width
   * when the element has focus and revert this when it loses focus.
   */
  width: 103%;
}

.annotationLayer .buttonWidgetAnnotation:is(.checkBox, .radioButton) input {
  appearance: none;
}

.annotationLayer .fileAttachmentAnnotation .popupTriggerArea {
  height: 100%;
  width: 100%;
}

.annotationLayer .popupAnnotation {
  position: absolute;
  font-size: calc(9px * var(--scale-factor));
  pointer-events: none;
  width: max-content;
  max-width: 45%;
  height: auto;
}

.annotationLayer .popup {
  background-color: rgb(255 255 153);
  box-shadow: 0 calc(2px * var(--scale-factor)) calc(5px * var(--scale-factor))
    rgb(136 136 136);
  border-radius: calc(2px * var(--scale-factor));
  outline: 1.5px solid rgb(255 255 74);
  padding: calc(6px * var(--scale-factor));
  cursor: pointer;
  font: message-box;
  white-space: normal;
  word-wrap: break-word;
  pointer-events: auto;
}

.annotationLayer .popupAnnotation.focused .popup {
  outline-width: 3px;
}

.annotationLayer .popup * {
  font-size: calc(9px * var(--scale-factor));
}

.annotationLayer .popup > .header {
  display: inline-block;
}

.annotationLayer .popup > .header h1 {
  display: inline;
}

.annotationLayer .popup > .header .popupDate {
  display: inline-block;
  margin-left: calc(5px * var(--scale-factor));
  width: fit-content;
}

.annotationLayer .popupContent {
  border-top: 1px solid rgb(51 51 51);
  margin-top: calc(2px * var(--scale-factor));
  padding-top: calc(2px * var(--scale-factor));
}

.annotationLayer .richText > * {
  white-space: pre-wrap;
  font-size: calc(9px * var(--scale-factor));
}

.annotationLayer .popupTriggerArea {
  cursor: pointer;
}

.annotationLayer section svg {
  position: absolute;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}

.annotationLayer .annotationTextContent {
  position: absolute;
  width: 100%;
  height: 100%;
  opacity: 0;
  color: transparent;
  user-select: none;
  pointer-events: none;
}

.annotationLayer .annotationTextContent span {
  width: 100%;
  display: inline-block;
}

.annotationLayer svg.quadrilateralsContainer {
  contain: strict;
  width: 0;
  height: 0;
  position: absolute;
  top: 0;
  left: 0;
  z-index: -1;
}
`

// Page documents keep one coordinate system whatever the bitmap resolution:
// PDF points times DOC_SCALE. Two keeps small print in the text layer above
// the minimum font size of Android WebView.
const DOC_SCALE = 2

// One page bitmap stays under 24 MiB of RGBA and WebKit's canvas limits.
const MAX_PAGE_PIXELS = 6_000_000

// Margin crops enlarge the page by about this much; render denser up front
// instead of following every crop with a sharp tile.
const CROP_DENSITY_BOOST = 1.3

// Thumbnails match the comic Pages grid and its bridge limits.
const THUMBNAIL_WIDTH = 240
const THUMBNAIL_HEIGHT = 360
const THUMBNAIL_MAX_LENGTH = 128 * 1024

// Library covers are shown small; this keeps imports fast and files light.
const COVER_MAX_WIDTH = 1200
const COVER_MAX_HEIGHT = 1800

const abortError = () => new DOMException('PDF render released', 'AbortError')

// WebKit frees canvas memory on resize, not on garbage collection.
const releaseCanvas = canvas => {
    if (canvas) canvas.width = canvas.height = 0
}

// The portrait test of the fixed-layout renderer.
const isPortraitScreen = () => (innerHeight || 1) > (innerWidth || 1) * 1.2

// Bitmap pixels per page pixel that fill the screen at page fit. Two-page
// spreads give each page half the width.
const fitDensity = (width, height, singlePages) => {
    const screenWidth = innerWidth || 1
    const screenHeight = innerHeight || 1
    const available = singlePages || isPortraitScreen() ? screenWidth : screenWidth / 2
    return Math.min(available / width, screenHeight / height) * (devicePixelRatio || 1)
}

const pageDensity = (width, height, boost, singlePages) => Math.min(
    fitDensity(width, height, singlePages) * boost,
    Math.sqrt(MAX_PAGE_PIXELS / (width * height)))

const sizedCanvas = (doc, width, height) => {
    const canvas = doc.createElement('canvas')
    canvas.width = Math.max(1, Math.round(width))
    canvas.height = Math.max(1, Math.round(height))
    return canvas
}

// Draws the page, or the part of it from (left, top) in page pixels, at
// [density] bitmap pixels per page pixel. pdf.js yields every frame while it
// draws, so background renders do not block input.
const renderInto = async (page, canvas, { density, left = 0, top = 0, signal }) => {
    if (signal?.aborted) throw abortError()
    const task = page.render({
        canvasContext: canvas.getContext('2d', { alpha: false }),
        viewport: page.getViewport({ scale: DOC_SCALE * density }),
        transform: left || top ? [1, 0, 0, 1, -left * density, -top * density] : null,
    })
    const cancel = () => task.cancel()
    signal?.addEventListener('abort', cancel, { once: true })
    try {
        await task.promise
    } finally {
        signal?.removeEventListener('abort', cancel)
    }
}

// Printed area in page pixels, read from a small copy of the bitmap.
const detectContent = (canvas, width, height) => {
    const scale = PAGE_CONTENT_SAMPLE_SIZE / Math.max(canvas.width, canvas.height)
    const sample = sizedCanvas(document, canvas.width * scale, canvas.height * scale)
    try {
        const context = sample.getContext('2d', { willReadFrequently: true })
        context.drawImage(canvas, 0, 0, sample.width, sample.height)
        const box = detectContentBox(
            context.getImageData(0, 0, sample.width, sample.height).data,
            sample.width, sample.height)
        if (!box) return null
        const x = width / sample.width
        const y = height / sample.height
        return { left: box.left * x, top: box.top * y, right: box.right * x, bottom: box.bottom * y }
    } catch {
        // A tainted or lost canvas only costs the margin crop.
        return null
    } finally {
        releaseCanvas(sample)
    }
}

// Text and link layers as HTML, and whether the page has any text to find.
const renderLayers = async (page, viewport) => {
    const textContent = await page.getTextContent()
    const container = document.createElement('div')
    container.classList.add('textLayer')
    await pdfjsLib.renderTextLayer({
        textContentSource: textContent,
        container, viewport,
    }).promise

    const div = document.createElement('div')
    div.classList.add('annotationLayer')
    await new pdfjsLib.AnnotationLayer({ page, viewport, div }).render({
        annotations: await page.getAnnotations(),
        linkService: {
            getDestinationHash: dest => JSON.stringify(dest),
            addLinkAttributes: (link, url) => link.href = url,
        },
    })
    return {
        html: container.outerHTML + div.outerHTML,
        hasText: textContent.items.some(item => item.str?.trim()),
    }
}

// One page document for display and search. Its first <body> element is the
// bitmap slot, where earlier versions had an <img>, so saved highlight CFIs
// keep pointing at the text layer; search CFIs match the displayed page.
// Sharp tiles and the highlight overlay are `cfi-inert` for the same reason.
const pageHTML = (width, height, layers) => `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
:root {
    --scale-factor: ${DOC_SCALE};
}
html, body {
    margin: 0;
    padding: 0;
}
body {
    position: relative;
    width: ${width}px;
    height: ${height}px;
    overflow: hidden;
}
.readflex-pdf-page {
    display: block;
    width: ${width}px;
    height: ${height}px;
}
.readflex-pdf-tile {
    position: absolute;
    pointer-events: none;
}
${textLayerBuilderCSS}
${annotationLayerBuilderCSS}
</style></head><body><div class="readflex-pdf-page"></div>${layers}</body></html>`

const renderCover = async page => {
    const natural = page.getViewport({ scale: 1 })
    const scale = Math.min(COVER_MAX_WIDTH / natural.width, COVER_MAX_HEIGHT / natural.height)
    const viewport = page.getViewport({ scale })
    const canvas = sizedCanvas(document, viewport.width, viewport.height)
    try {
        await page.render({ canvasContext: canvas.getContext('2d', { alpha: false }), viewport }).promise
        return await new Promise(resolve => canvas.toBlob(resolve))
    } finally {
        releaseCanvas(canvas)
    }
}

const makeTOCItem = item => ({
    label: item.title,
    href: JSON.stringify(item.dest),
    subitems: item.items.length ? item.items.map(makeTOCItem) : null,
})

export const makePDF = async file => {
    const data = new Uint8Array(await file.arrayBuffer())
    // Damaged real-world files make pdf.js warn while it repairs them; only its
    // errors reach the console, which Android WebView also writes to logcat.
    const pdf = await pdfjsLib.getDocument({
        data, verbosity: pdfjsLib.VerbosityLevel.ERRORS,
    }).promise

    // Text pages keep native selection under zoom; see readflex_page_zoom.js.
    // A portrait screen reads one page at a time: spreads would draw the
    // hidden half of every spread and prefetch only half of the next one.
    // Landscape openings (tablets) keep two-page spreads.
    const singlePages = isPortraitScreen()
    const book = { rendition: {
        layout: 'pre-paginated', zoomable: true, selectableText: true,
        ...(singlePages ? { spread: 'none' } : {}),
    } }

    const info = (await pdf.getMetadata())?.info
    book.metadata = {
        title: info?.Title,
        author: info?.Author,
    }

    const outline = await pdf.getOutline()
    book.toc = outline?.map(makeTOCItem)

    // Sent to Flutter as document features. Searchable text is unknown until a
    // page with text renders; `onFeaturesChange` is set by the reader shell.
    book.features = { format: 'pdf', hasToc: !!book.toc?.length, pageCount: pdf.numPages }
    const noteText = hasText => {
        if (!hasText || book.features.hasSearchableText) return
        book.features.hasSearchableText = true
        book.onFeaturesChange?.()
    }
    book.samplesTextDirection = false

    // Page document HTML, the same for display and search.
    const pageDocumentHTML = async page => {
        const viewport = page.getViewport({ scale: DOC_SCALE })
        const { html, hasText } = await renderLayers(page, viewport)
        noteText(hasText)
        return pageHTML(viewport.width, viewport.height, html)
    }

    let destroyed = false
    let cropMargins = false
    let colors = null
    let recoloring = null

    // One rendered page: its bitmap, the colors baked into it, and the
    // canvas-image source the fixed-layout renderer shows.
    const renderPage = async (index, signal) => {
        const page = await pdf.getPage(index + 1)
        if (signal.aborted) throw abortError()
        const { width, height } = page.getViewport({ scale: DOC_SCALE })
        const target = pageDensity(width, height, cropMargins ? CROP_DENSITY_BOOST : 1, singlePages)
        const canvas = sizedCanvas(document, width * target, height * target)
        canvas.className = 'readflex-pdf-page'
        try {
            const density = canvas.width / width
            await renderInto(page, canvas, { density, signal })
            const content = detectContent(canvas, width, height)
            const applied = colors
            applyPageColors(canvas, applied)
            const html = await pageDocumentHTML(page)
            if (signal.aborted) throw abortError()
            return {
                index, page, canvas, density, colors: applied,
                source: {
                    kind: 'canvas-image',
                    width, height, density, content, html,
                    draw: doc => doc.querySelector('.readflex-pdf-page')?.replaceWith(canvas),
                },
            }
        } catch (error) {
            releaseCanvas(canvas)
            throw error
        }
    }

    // Sharp tiles per page: the one on screen and at most one being drawn.
    const tiles = new Map()

    const dropTile = index => {
        const slot = tiles.get(index)
        if (!slot) return
        tiles.delete(index)
        slot.pending?.controller.abort()
        slot.shown?.canvas.remove()
        releaseCanvas(slot.shown?.canvas)
    }

    const renderTile = async (entry, slot, pending) => {
        const { doc, controller: { signal } } = pending
        // pdf.js registers embedded fonts with this document. A canvas made by
        // the page document would draw missing-glyph boxes; draw here, then
        // move the finished tile in, like the page bitmap.
        const canvas = sizedCanvas(document, pending.width * pending.density, pending.height * pending.density)
        canvas.className = 'readflex-pdf-tile'
        canvas.setAttribute('cfi-inert', '')
        canvas.setAttribute('aria-hidden', 'true')
        Object.assign(canvas.style, {
            left: `${pending.left}px`,
            top: `${pending.top}px`,
            width: `${pending.width}px`,
            height: `${pending.height}px`,
        })
        try {
            await renderInto(entry.page, canvas, {
                density: pending.density, left: pending.left, top: pending.top, signal,
            })
            if (signal.aborted || slot.pending !== pending || tiles.get(entry.index) !== slot
                || !entry.canvas.isConnected) throw abortError()
            applyPageColors(canvas, pending.colors)
            // Right after the bitmap: under the text layer and highlights.
            entry.canvas.after(canvas)
            const previous = slot.shown
            slot.shown = { ...pending, canvas }
            slot.pending = null
            previous?.canvas.remove()
            releaseCanvas(previous?.canvas)
        } catch {
            // Superseded, released or failed: the page bitmap stays on screen.
            releaseCanvas(canvas)
            if (slot.pending === pending) slot.pending = null
        }
    }

    const startTile = (entry, slot, { left, top, width, height, density }, doc) => {
        slot.pending?.controller.abort()
        const pending = { left, top, width, height, density, doc, colors, controller: new AbortController() }
        slot.pending = pending
        void renderTile(entry, slot, pending)
    }

    const releasePage = entry => {
        dropTile(entry.index)
        releaseCanvas(entry.canvas)
        // Deferred by pdf.js while a thumbnail or tile still draws this page.
        entry.page.cleanup()
    }

    const cache = createPdfPageCache({ count: pdf.numPages, render: renderPage, release: releasePage })

    // Colors are baked into bitmaps, so a theme change redraws the cached
    // pages offscreen, visible first, and swaps each one in a single copy.
    const recolor = async () => {
        for (const [index, entry] of cache.ready()) {
            if (destroyed) return
            if (!samePageColors(entry.colors, colors)) {
                const applied = colors
                const canvas = sizedCanvas(document, entry.canvas.width, entry.canvas.height)
                try {
                    await renderInto(entry.page, canvas, { density: entry.density })
                    if (destroyed || cache.peek(index) !== entry) continue
                    applyPageColors(canvas, applied)
                    entry.canvas.getContext('2d').drawImage(canvas, 0, 0)
                    entry.colors = applied
                } catch {
                    // The next load or theme change retries.
                } finally {
                    releaseCanvas(canvas)
                }
            }
            const slot = tiles.get(index)
            const shown = slot?.shown
            if (shown && !slot.pending && !samePageColors(shown.colors, colors)) {
                startTile(entry, slot, shown, shown.doc)
            }
        }
    }

    const scheduleRecolor = () => {
        // Changes during a pass are picked up by one more pass.
        recoloring ??= (async () => {
            try {
                let applied
                do {
                    applied = colors
                    await recolor()
                } while (!destroyed && !samePageColors(applied, colors))
            } finally {
                recoloring = null
            }
        })()
    }

    book.sections = Array.from({ length: pdf.numPages }).map((_, i) => ({
        id: i,
        load: async () => {
            const entry = await cache.load(i)
            // The theme changed while this page was drawing.
            if (!samePageColors(entry.colors, colors)) scheduleRecolor()
            return entry.source
        },
        unload: () => cache.unload(i),
        // Text-only twin of the displayed page for search: no bitmap is drawn.
        createDocument: async () => {
            if (destroyed) throw abortError()
            const page = await pdf.getPage(i + 1)
            try {
                return new DOMParser().parseFromString(await pageDocumentHTML(page), 'text/html')
            } finally {
                if (cache.peek(i) === undefined) page.cleanup()
            }
        },
        size: 1000,
    }))
    book.sections[0].pageSpread = 'right'

    // Called by the fixed-layout renderer after each navigation.
    book.prepareAdjacentPages = (visible, options) => cache.retain(visible, options)

    // Redraws the visible [region] of a page sharper, or drops its tile.
    book.sharpenPage = (index, region) => {
        const entry = cache.peek(index)
        const doc = entry?.canvas.isConnected ? entry.canvas.ownerDocument : null
        if (destroyed || !region || !doc) return dropTile(index)
        let slot = tiles.get(index)
        if (!slot) tiles.set(index, slot = { shown: null, pending: null })
        const fresh = tile => tile?.doc === doc && samePageColors(tile.colors, colors)
        if (fresh(slot.shown) && tileCovers(slot.shown, region)) {
            slot.pending?.controller.abort()
            slot.pending = null
            return
        }
        if (fresh(slot.pending) && tileCovers(slot.pending, region)) return
        const plan = tileFor(region, entry.source)
        // Within the pixel budget the tile would be no sharper than the page.
        if (plan.density <= entry.density * SHARPEN_THRESHOLD) return dropTile(index)
        startTile(entry, slot, plan, doc)
    }

    book.setCropMargins = enabled => { cropMargins = enabled === true }

    book.setPageColors = next => {
        if (samePageColors(next, colors)) return
        colors = next
        scheduleRecolor()
    }

    book.getThumbnail = async index => {
        if (destroyed || !Number.isInteger(index) || index < 0 || index >= pdf.numPages) return null
        const page = await pdf.getPage(index + 1)
        if (destroyed) return null
        const natural = page.getViewport({ scale: 1 })
        const viewport = page.getViewport({
            scale: Math.min(THUMBNAIL_WIDTH / natural.width, THUMBNAIL_HEIGHT / natural.height),
        })
        const canvas = sizedCanvas(document, viewport.width, viewport.height)
        try {
            await page.render({ canvasContext: canvas.getContext('2d', { alpha: false }), viewport }).promise
            if (destroyed) return null
            const result = canvas.toDataURL('image/jpeg', 0.72)
            return result.length <= THUMBNAIL_MAX_LENGTH ? result : null
        } finally {
            releaseCanvas(canvas)
            if (cache.peek(index) === undefined) page.cleanup()
        }
    }

    book.isExternal = uri => /^\w+:/i.test(uri)
    book.resolveHref = async href => {
        const parsed = JSON.parse(href)
        const dest = typeof parsed === 'string'
            ? await pdf.getDestination(parsed) : parsed
        const index = await pdf.getPageIndex(dest[0])
        return { index }
    }
    book.splitTOCHref = async href => {
        const parsed = JSON.parse(href)
        const dest = typeof parsed === 'string'
            ? await pdf.getDestination(parsed) : parsed
        const index = await pdf.getPageIndex(dest[0])
        return [index, null]
    }
    book.getTOCFragment = doc => doc.documentElement
    book.getCover = async () => renderCover(await pdf.getPage(1))
    book.destroy = () => {
        destroyed = true
        for (const index of [...tiles.keys()]) dropTile(index)
        cache.destroy()
        void pdf.destroy()
    }
    return book
}
