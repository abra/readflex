import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { openPdf, pointer, pointers, waitForPdfPage } from './harness.mjs'

const serifFont = () => readFile(new URL(
    '../../component_library/fonts/PTSerif-Regular.ttf', import.meta.url))

// Generated A4 page: 595 × 842 pt, page pixels are points × 2.
const PAGE_WIDTH = 1190

const pdfState = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    const frame = doc.defaultView.frameElement
    const bitmap = doc.querySelector('canvas.readflex-pdf-page')
    const tile = doc.querySelector('canvas.readflex-pdf-tile')
    return {
        index: renderer.index,
        scale: doc.scale,
        width: frame.getBoundingClientRect().width,
        left: frame.getBoundingClientRect().left,
        visible: doc.readflexVisibleRect,
        bitmap: bitmap.width,
        tile: tile && {
            density: tile.width / parseFloat(tile.style.width),
            inert: tile.hasAttribute('cfi-inert'),
            afterBitmap: tile.previousElementSibling === bitmap,
        },
        clicks: window.bridgeCalls.filter(([name]) => name === 'onClick').map(([, value]) => value),
    }
})

// CFI of the first text-layer line on the current page.
const firstLineCfi = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const { doc, index } = renderer.getContents().find(entry => entry.index === renderer.index)
    const range = doc.createRange()
    range.selectNodeContents(doc.querySelector('.textLayer span'))
    return window.reader.view.getCFI(index, range)
})

const tap = async (page, x, y) => {
    await pointer(page, 'pointerdown', x, y)
    await pointer(page, 'pointerup', x, y)
}

// Both taps in one evaluate: the reader's double-tap window is 280 ms, and
// four protocol round trips can exceed it on a loaded machine.
const doubleTap = (page, x = 195, y = 420) => pointers(page, [
    { type: 'pointerdown', x, y }, { type: 'pointerup', x, y },
    { type: 'pointerdown', x, y }, { type: 'pointerup', x, y },
])

const waitForTile = (page, present = true) => page.waitForFunction(present => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    return !!doc.querySelector('canvas.readflex-pdf-tile') === present
}, present)

// Luminance range of a rectangle on the current page bitmap.
const bitmapLuminance = (page, { x, y, width, height }) => page.evaluate(({ x, y, width, height }) => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    const canvas = doc.querySelector('canvas.readflex-pdf-page')
    const scale = canvas.width / parseFloat(getComputedStyle(canvas).width)
    const data = canvas.getContext('2d').getImageData(
        Math.round(x * scale), Math.round(y * scale),
        Math.round(width * scale), Math.round(height * scale)).data
    let min = 255
    let max = 0
    for (let i = 0; i < data.length; i += 4) {
        const value = (data[i] * 54 + data[i + 1] * 183 + data[i + 2] * 19) >> 8
        min = Math.min(min, value)
        max = Math.max(max, value)
    }
    return { min, max, first: [...data.slice(0, 3)] }
}, { x, y, width, height })

test('a PDF page is a screen-density canvas ahead of the text layer', async t => {
    const { page } = await openPdf(t)
    const structure = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return {
            body: [...doc.body.children].map(element => element.getAttribute('class') || element.localName),
            overlayInert: doc.body.lastElementChild.hasAttribute('cfi-inert'),
            scaleFactor: getComputedStyle(doc.documentElement).getPropertyValue('--scale-factor').trim(),
            text: doc.querySelector('.textLayer').textContent.slice(0, 12),
            links: doc.querySelectorAll('.annotationLayer a[href]').length,
        }
    })
    // The bitmap takes the place of the <img> earlier versions rendered, so
    // saved highlight CFIs still address the text layer as body child 2. The
    // highlight overlay comes last and stays out of CFIs.
    assert.deepEqual(structure.body, ['readflex-pdf-page', 'textLayer', 'annotationLayer', 'svg'])
    assert.equal(structure.overlayInert, true)
    assert.equal(structure.scaleFactor, '2')
    assert.equal(structure.text, 'Page 1 title')
    assert.equal(structure.links, 1)
    assert.match(await firstLineCfi(page), /!\/4\/4[,/]/)
    const state = await pdfState(page)
    // 390 CSS px at 3x: one bitmap pixel per device pixel at page fit.
    assert.equal(state.bitmap, 1170)
    assert.ok(Math.abs(state.width - 390) < 1)
    assert.equal(state.tile, null)
})

test('reading forward keeps at most three page bitmaps alive', async t => {
    const { page } = await openPdf(t, { pages: 9 })
    for (let index = 1; index < 8; index++) {
        await page.evaluate(() => window.reader.view.renderer.next())
        await waitForPdfPage(page, index)
    }
    await page.waitForTimeout(300)
    const live = await page.evaluate(() => window.__pageCanvases
        .filter(canvas => canvas.className === 'readflex-pdf-page' && canvas.width > 0).length)
    assert.ok(live <= 3, `${live} page bitmaps are alive`)
    const others = await page.evaluate(() => window.__pageCanvases
        .filter(canvas => !canvas.className && canvas.width > 0).length)
    assert.equal(others, 0, 'samples and recolor buffers are released')
})

test('portrait screens show one page and the next one is ready before the turn', async t => {
    const { page } = await openPdf(t)
    await page.evaluate(() => window.reader.view.renderer.next())
    await waitForPdfPage(page, 1)
    await page.waitForTimeout(600)
    const result = await page.evaluate(async () => {
        const renderer = window.reader.view.renderer
        const frames = renderer.getContents().length
        const start = performance.now()
        await window.reader.view.book.sections[2].load()
        return { frames, loadMs: performance.now() - start }
    })
    assert.equal(result.frames, 1, 'no hidden half of a spread is drawn')
    assert.ok(result.loadMs < 30, `next page was prefetched: ${result.loadMs} ms`)
})

test('landscape screens keep two-page spreads at half-width density', async t => {
    const { page } = await openPdf(t, { viewport: { width: 844, height: 390 } })
    await page.evaluate(() => window.reader.view.renderer.goTo({ index: 1 }))
    await waitForPdfPage(page, 1)
    const spread = await page.evaluate(() => window.reader.view.renderer.getContents()
        .map(({ index, doc }) => [index, doc.querySelector('canvas.readflex-pdf-page')?.width ?? 0]))
    assert.deepEqual(spread.map(([index]) => index), [1, 2])
    // Each page fits the 390 px height: 390 / 1684 × 3 bitmap pixels per page pixel.
    for (const [, width] of spread) assert.ok(Math.abs(width - 1190 * 390 / 1684 * 3) < 2, `${width}`)
})

test('double tap zooms a PDF page and a sharp tile replaces the blur', async t => {
    const { page } = await openPdf(t)
    const before = await pdfState(page)
    const cfi = await firstLineCfi(page)
    await doubleTap(page)
    await waitForTile(page)
    const zoomed = await pdfState(page)
    assert.ok(zoomed.width > before.width * 2.4, 'zoomed to 2.5x')
    assert.deepEqual(zoomed.clicks, [], 'a double tap is not a chrome tap')
    // 2.5x of one bitmap pixel per device pixel.
    assert.ok(Math.abs(zoomed.tile.density - before.bitmap / PAGE_WIDTH * 2.5) < 0.05, JSON.stringify(zoomed.tile))
    assert.equal(zoomed.tile.inert, true)
    assert.equal(zoomed.tile.afterBitmap, true, 'under the text layer and highlights')
    assert.equal(await firstLineCfi(page), cfi, 'tiles never shift highlight CFIs')
    await doubleTap(page)
    await waitForTile(page, false)
    assert.ok(Math.abs((await pdfState(page)).width - before.width) < 1)
})

// Mean luminance difference between the tile, scaled down to the page bitmap
// density, and the same area of the page bitmap. Missing glyphs draw boxes.
const tileDifference = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    const bitmap = doc.querySelector('canvas.readflex-pdf-page')
    const tile = doc.querySelector('canvas.readflex-pdf-tile')
    const density = bitmap.width / parseFloat(getComputedStyle(bitmap).width)
    const [left, top, width, height] = ['left', 'top', 'width', 'height']
        .map(key => Math.round(parseFloat(tile.style[key]) * density))
    const scaled = document.createElement('canvas')
    scaled.width = width
    scaled.height = height
    const context = scaled.getContext('2d')
    context.drawImage(tile, 0, 0, width, height)
    const a = context.getImageData(0, 0, width, height).data
    const b = bitmap.getContext('2d').getImageData(left, top, width, height).data
    const luminance = (data, i) => (data[i] * 54 + data[i + 1] * 183 + data[i + 2] * 19) >> 8
    let total = 0
    for (let i = 0; i < a.length; i += 4) total += Math.abs(luminance(a, i) - luminance(b, i))
    return total / (a.length / 4)
})

test('sharp tiles draw embedded fonts the same as the page', async t => {
    const { page } = await openPdf(t, { embeddedFont: await serifFont() })
    await doubleTap(page, 195, 300)
    await waitForTile(page)
    // Resampling a 2.5x denser tile leaves about 10; missing-glyph boxes
    // measure above 40 in Chromium and WebKit.
    const difference = await tileDifference(page)
    assert.ok(difference < 20, `tile differs from the page by ${difference.toFixed(2)}`)
})

test('pinch zooms a PDF page, ends sharp and leaves the location alone', async t => {
    const { page } = await openPdf(t)
    const start = await pdfState(page)
    await pointer(page, 'pointerdown', 160, 420, 1)
    await pointer(page, 'pointerdown', 220, 420, 2)
    for (let i = 1; i <= 8; i++) {
        await pointer(page, 'pointermove', 160 - i * 15, 420, 1)
        await pointer(page, 'pointermove', 220 + i * 15, 420, 2)
        await page.waitForTimeout(35)
    }
    await pointer(page, 'pointerup', 340, 420, 2)
    await pointer(page, 'pointerup', 40, 420, 1)
    await waitForTile(page)
    const pinched = await pdfState(page)
    assert.ok(pinched.width > start.width * 1.5)
    assert.equal(pinched.index, start.index)
    assert.deepEqual(pinched.clicks, [])
})

test('turning the page drops the zoomed tile with its document', async t => {
    const { page } = await openPdf(t)
    await doubleTap(page)
    await waitForTile(page)
    await page.evaluate(() => window.reader.view.renderer.next())
    await waitForPdfPage(page, 1)
    await page.waitForTimeout(250)
    const live = await page.evaluate(() => window.__pageCanvases
        .filter(canvas => canvas.className === 'readflex-pdf-tile' && canvas.width > 0).length)
    assert.equal(live, 0)
    assert.equal((await pdfState(page)).tile, null)
})

test('idle touches stay native on text so a long press can select', async t => {
    const { page } = await openPdf(t)
    const prevented = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        const span = doc.querySelector('.textLayer span')
        const touch = { identifier: 1, clientX: 50, clientY: 50, screenX: 100, screenY: 300 }
        return ['touchstart', 'touchmove'].map(type => {
            const event = new doc.defaultView.Event(type, { bubbles: true, cancelable: true })
            Object.defineProperties(event, { touches: { value: [touch] }, changedTouches: { value: [touch] } })
            span.dispatchEvent(event)
            return event.defaultPrevented
        })
    })
    assert.deepEqual(prevented, [false, false])
})

test('a text selection keeps a zoomed page still', async t => {
    const { page } = await openPdf(t)
    await doubleTap(page)
    await waitForTile(page)
    await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        doc.getSelection().selectAllChildren(doc.querySelectorAll('.textLayer span')[3])
    })
    const selected = await pdfState(page)
    await pointer(page, 'pointerdown', 200, 500)
    await pointer(page, 'pointermove', 300, 600)
    await page.waitForTimeout(40)
    await pointer(page, 'pointerup', 300, 600)
    await page.waitForTimeout(100)
    assert.equal((await pdfState(page)).left, selected.left)
})

// Screen point at the centre of the link on the current page.
const linkPoint = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    const frame = doc.defaultView.frameElement
    const outer = frame.getBoundingClientRect()
    const inner = doc.querySelector('.annotationLayer a[href]').getBoundingClientRect()
    const scale = outer.width / frame.clientWidth
    return {
        x: outer.left + (inner.left + inner.width / 2) * scale,
        y: outer.top + (inner.top + inner.height / 2) * scale,
    }
})

test('a touch on a PDF link follows the link instead of toggling chrome', async t => {
    const { page } = await openPdf(t)
    const { x, y } = await linkPoint(page)
    await tap(page, x, y)
    await page.waitForTimeout(350)
    assert.deepEqual((await pdfState(page)).clicks, [], 'no reader tap')
    // The click that follows the touch reaches the link handler.
    await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        doc.querySelector('.annotationLayer a[href]').dispatchEvent(
            new doc.defaultView.MouseEvent('click', { bubbles: true, cancelable: true }))
    })
    await waitForPdfPage(page, 2)
    await tap(page, 195, 600)
    await page.waitForTimeout(350)
    assert.equal((await pdfState(page)).clicks.length, 1, 'other taps still reach the reader')
})

test('host-forwarded taps skip PDF links and reach the reader elsewhere', async t => {
    const { page } = await openPdf(t, { hostTaps: true })
    const { x, y } = await linkPoint(page)
    await page.evaluate(({ x, y }) => window.handlePageTouchTap(x, y), { x, y })
    await page.waitForTimeout(350)
    assert.deepEqual((await pdfState(page)).clicks, [])
    await page.evaluate(() => window.handlePageTouchTap(195, 600))
    await page.waitForTimeout(350)
    assert.equal((await pdfState(page)).clicks.length, 1)
})

// The click a browser sends after a touch, hit-tested on the page shown now.
const touchClick = (page, x, y) => page.evaluate(({ x, y }) => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    const frame = doc.defaultView.frameElement
    const rect = frame.getBoundingClientRect()
    const clientX = (x - rect.left) * frame.clientWidth / rect.width
    const clientY = (y - rect.top) * frame.clientHeight / rect.height
    ;(doc.elementFromPoint(clientX, clientY) ?? doc.body).dispatchEvent(new doc.defaultView.MouseEvent(
        'click', { bubbles: true, cancelable: true, clientX, clientY, screenX: x, screenY: y }))
}, { x, y })

// Flutter answers an edge tap with a turn, which can finish before the browser
// delivers the click of the same touch. Time stands still, so the result does
// not depend on how fast the machine turns the page.
const openForEdgeTurn = async (t, options) => {
    const { page } = await openPdf(t, { ...options, controlledClock: true })
    // A ready next page lets the turn finish without timers.
    await page.evaluate(() => window.reader.view.book.sections[1].load())
    await page.clock.pauseAt(await page.evaluate(() => Date.now() + 1000))
    return page
}

test('the click of an edge touch does not turn the next page as well', async t => {
    const page = await openForEdgeTurn(t)
    await tap(page, 380, 420)
    assert.equal((await pdfState(page)).clicks.length, 1)
    await page.evaluate(() => window.pageRight())
    assert.equal((await pdfState(page)).index, 1)
    await touchClick(page, 380, 420)
    assert.equal((await pdfState(page)).clicks.length, 1, 'the click is not another tap')
    await tap(page, 380, 420)
    assert.equal((await pdfState(page)).clicks.length, 2, 'the next touch is')
})

test('a host-forwarded edge tap turns one page when WebKit sends the touch late', async t => {
    const page = await openForEdgeTurn(t, { hostTaps: true })
    await page.evaluate(() => window.handlePageTouchTap(380, 420))
    assert.equal((await pdfState(page)).clicks.length, 1)
    await page.evaluate(() => window.pageRight())
    // The touch never reached the first page; its click lands on the next one.
    await touchClick(page, 380, 420)
    const state = await pdfState(page)
    assert.equal(state.index, 1)
    assert.equal(state.clicks.length, 1)
    await page.evaluate(() => window.handlePageTouchTap(380, 420))
    assert.equal((await pdfState(page)).clicks.length, 2, 'the next forwarded tap still counts')
})

test('the click WebKit sends to the page the touch began on is not another tap', async t => {
    const page = await openForEdgeTurn(t, { hostTaps: true })
    await tap(page, 380, 420)
    await page.evaluate(() => window.handlePageTouchTap(380, 420))
    assert.equal((await pdfState(page)).clicks.length, 1)
    // WebKit dispatches a tap's click in the document the touch began in, even
    // when that page is already animating away.
    await page.evaluate(async x => {
        const renderer = window.reader.view.renderer
        const touched = renderer.getContents().find(({ index }) => index === renderer.index).doc
        void window.pageRight()
        // Paused timers do not run; a message is a task that still does.
        const nextTask = () => new Promise(resolve => {
            const channel = new MessageChannel()
            channel.port1.onmessage = resolve
            channel.port2.postMessage(null)
        })
        while (renderer.getContents().length < 2) await nextTask()
        touched.body.dispatchEvent(new touched.defaultView.MouseEvent(
            'click', { bubbles: true, cancelable: true, clientX: x, clientY: 1200 }))
    }, PAGE_WIDTH - 20)
    assert.equal((await pdfState(page)).clicks.length, 1, 'the click is not another tap')
    await page.clock.resume()
    await waitForPdfPage(page, 1)
    await page.waitForTimeout(400)
    assert.equal((await pdfState(page)).index, 1, 'one tap turns one page')
})

test('margin crops enlarge text pages, skip sparse ones and stay sharp', async t => {
    const { page } = await openPdf(t)
    const before = await pdfState(page)
    await page.evaluate(() => window.changeStyle({ cropPageMargins: true }))
    await page.waitForFunction(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return doc.readflexVisibleRect.left > 0
    })
    const cropped = await pdfState(page)
    // Ink starts at 72 pt (144 page px); the crop keeps 2% padding.
    assert.ok(cropped.visible.left > 100 && cropped.visible.left < 144, JSON.stringify(cropped.visible))
    assert.ok(cropped.visible.width < PAGE_WIDTH * 0.85)
    assert.ok(Math.abs(cropped.scale / before.scale - PAGE_WIDTH / cropped.visible.width) < 0.01)
    // The page was drawn for the uncropped fit; a tile restores sharpness.
    await waitForTile(page)

    // Pages drawn afterwards are dense enough on their own.
    await page.evaluate(() => window.reader.view.renderer.goTo({ index: 2 }))
    await waitForPdfPage(page, 2)
    const later = await pdfState(page)
    assert.ok(later.bitmap > before.bitmap * 1.25)
    await page.waitForTimeout(250)
    assert.equal((await pdfState(page)).tile, null)

    // The closing page has a lone title and keeps its whole page.
    await page.evaluate(() => window.reader.view.renderer.goTo({ index: 5 }))
    await waitForPdfPage(page, 5)
    assert.equal((await pdfState(page)).visible.left, 0)

    await page.evaluate(() => window.changeStyle({ cropPageMargins: false }))
    await page.evaluate(() => window.reader.view.renderer.goTo({ index: 2 }))
    await waitForPdfPage(page, 2)
    assert.equal((await pdfState(page)).visible.left, 0)
})

test('theme colors tint light pages and invert dark ones, then restore', async t => {
    const { page } = await openPdf(t)
    const margin = { x: 10, y: 10, width: 20, height: 20 }
    const title = { x: 140, y: 120, width: 300, height: 50 }
    const paper = async expected => page.waitForFunction(({ margin, expected }) => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        const canvas = doc.querySelector('canvas.readflex-pdf-page')
        const pixel = canvas.getContext('2d').getImageData(margin.x, margin.y, 1, 1).data
        return expected.every((value, i) => Math.abs(pixel[i] - value) <= 3)
    }, { margin, expected })

    await page.evaluate(() => window.changeStyle({
        pageColors: 'theme', backgroundColor: '#F3E4CF', fontColor: '#33261B' }))
    await paper([243, 228, 207])
    const warmText = await bitmapLuminance(page, title)
    assert.ok(warmText.min < 60, 'ink stays dark')

    await page.evaluate(() => window.changeStyle({
        pageColors: 'theme', backgroundColor: '#0F1115', fontColor: '#BCC1CA' }))
    await paper([15, 17, 21])
    const darkText = await bitmapLuminance(page, title)
    assert.ok(darkText.max > 150 && darkText.max < 205, `ink takes the text color: ${darkText.max}`)
    // The blue figure stays blue after inversion.
    const figure = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        const canvas = doc.querySelector('canvas.readflex-pdf-page')
        const scale = canvas.width / 1190
        return [...canvas.getContext('2d').getImageData(Math.round(600 * scale), Math.round(1300 * scale), 1, 1).data]
    })
    // Inversion alone would turn it yellow.
    assert.ok(figure[2] > figure[0] + 25 && figure[2] > figure[1] + 25, `figure ${figure}`)

    // The neighbour drawn earlier follows the theme as well.
    await page.evaluate(() => window.reader.view.renderer.next())
    await waitForPdfPage(page, 1)
    await paper([15, 17, 21])

    await page.evaluate(() => window.changeStyle({ pageColors: 'original' }))
    await paper([255, 255, 255])
})

test('PDF thumbnails are small JPEG previews and invalid pages have none', async t => {
    const { page } = await openPdf(t)
    const preview = await page.evaluate(async () => {
        const data = await window.readflexPageThumbnail(3)
        const image = new Image()
        image.src = data
        await image.decode()
        return { prefix: data.slice(0, 23), length: data.length, width: image.width, height: image.height }
    })
    assert.equal(preview.prefix, 'data:image/jpeg;base64,')
    assert.ok(preview.length <= 128 * 1024)
    assert.equal(preview.width, 240)
    assert.equal(preview.height, 340)
    for (const index of [-1, 6, 0.5]) {
        assert.equal(await page.evaluate(index => window.readflexPageThumbnail(index), index), null)
    }
    assert.equal((await pdfState(page)).index, 0)
})

test('closing a PDF frees its bitmaps and stops previews', async t => {
    const { page } = await openPdf(t)
    await doubleTap(page)
    await waitForTile(page)
    const live = await page.evaluate(async () => {
        window.reader.view.book.destroy()
        return window.__pageCanvases.filter(canvas => canvas.width > 0).length
    })
    assert.equal(live, 0)
    assert.equal(await page.evaluate(() => window.readflexPageThumbnail(1)), null)
})

const searchResults = page => page.evaluate(() => window.bridgeCalls
    .filter(([name, value]) => name === 'onSearch' && value?.type === 'results')
    .flatMap(([, value]) => value.items))

test('PDF search finds text on any page and marks the hit on that page', async t => {
    const { page } = await openPdf(t)
    await page.evaluate(() => window.startSearch(7, 'Line 7 of page 3:'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name, value]) =>
        name === 'onSearch' && value?.type === 'done'))
    const results = await searchResults(page)
    assert.equal(results.length, 1)
    assert.match(results[0].excerpt.pre + results[0].excerpt.match + results[0].excerpt.post, /Line 7 of page 3/)
    await page.evaluate(cfi => window.goToSearchResult(cfi), results[0].cfi)
    await waitForPdfPage(page, 2)
    const mark = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const { overlayer, doc } = renderer.getContents().find(({ index }) => index === renderer.index)
        const svg = doc.body.lastElementChild
        return { overlayer: !!overlayer, shapes: svg.querySelectorAll('rect').length }
    })
    assert.deepEqual(mark.overlayer, true)
    assert.ok(mark.shapes > 0, 'the hit is marked on the page')
})

test('opening a PDF builds no search documents', async t => {
    const { page } = await openPdf(t)
    await page.waitForTimeout(300)
    const before = await page.evaluate(() => window.__searchDocuments ?? 0)
    assert.equal(before, 0)
})

const highlightFirstLine = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const { doc, index } = renderer.getContents().find(entry => entry.index === renderer.index)
    // Like a user selection: text node boundaries, not element offsets.
    const text = doc.querySelectorAll('.textLayer span')[2].firstChild
    const range = doc.createRange()
    range.setStart(text, 0)
    range.setEnd(text, text.length)
    const cfi = window.reader.view.getCFI(index, range)
    window.addAnnotation({ id: 'h1', value: cfi, cfi, type: 'highlight', color: '#ffe600' })
    return cfi
})

const overlayShapes = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    return doc.body.lastElementChild.querySelectorAll('rect, path').length
})

test('saved PDF highlights are drawn, stay above sharp tiles and come back with the page', async t => {
    const { page } = await openPdf(t)
    await highlightFirstLine(page)
    await page.waitForFunction(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return doc.body.lastElementChild.querySelector('rect, path')
    })
    await doubleTap(page, 195, 600)
    await waitForTile(page)
    const order = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        const children = [...doc.body.children]
        return children.indexOf(doc.querySelector('.readflex-pdf-tile'))
            < children.indexOf(doc.body.lastElementChild)
    })
    assert.equal(order, true, 'the overlay paints after the tile')
    await doubleTap(page, 195, 600)
    await waitForTile(page, false)
    await page.evaluate(() => window.reader.view.renderer.goTo({ index: 1 }))
    await waitForPdfPage(page, 1)
    await page.evaluate(() => window.reader.view.renderer.goTo({ index: 0 }))
    await waitForPdfPage(page, 0)
    await page.waitForFunction(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return doc.body.lastElementChild.querySelector('rect, path')
    })
    assert.ok(await overlayShapes(page) > 0)
})

test('a touch on a saved PDF highlight opens it instead of toggling chrome', async t => {
    const { page } = await openPdf(t)
    const cfi = await highlightFirstLine(page)
    const point = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        const frame = doc.defaultView.frameElement
        const outer = frame.getBoundingClientRect()
        const inner = doc.querySelectorAll('.textLayer span')[2].getBoundingClientRect()
        const scale = outer.width / frame.clientWidth
        return { x: outer.left + (inner.left + inner.width / 2) * scale, y: outer.top + (inner.top + inner.height / 2) * scale }
    })
    await page.waitForTimeout(100)
    await tap(page, point.x, point.y)
    await page.waitForTimeout(350)
    const calls = await page.evaluate(() => window.bridgeCalls.map(([name, value]) => [name, value?.annotation?.value ?? null]))
    assert.deepEqual(calls.filter(([name]) => name === 'onAnnotationClick').map(([, value]) => value), [cfi])
    assert.equal(calls.filter(([name]) => name === 'onClick').length, 0)
})

test('a damaged PDF opens without pdf.js warnings in the console', async t => {
    // Android WebView writes console messages to logcat, release builds included.
    const { page, consoleMessages } = await openPdf(t, { brokenXref: true })
    await page.evaluate(() => window.reader.view.renderer.next())
    await waitForPdfPage(page, 1)
    assert.deepEqual(consoleMessages.filter(text => text.startsWith('Warning:')), [])
})

test('PDF reports its page count, outline and searchable text to Flutter', async t => {
    const { page } = await openPdf(t)
    await page.waitForFunction(() => window.bridgeCalls.some(([name, value]) =>
        name === 'onDocumentFeatures' && value?.hasSearchableText === true))
    const features = await page.evaluate(() => window.bridgeCalls
        .filter(([name]) => name === 'onDocumentFeatures').at(-1)[1])
    assert.deepEqual(features, { format: 'pdf', hasToc: false, pageCount: 6, hasSearchableText: true })
})
