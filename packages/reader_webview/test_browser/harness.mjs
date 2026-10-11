import http from 'node:http'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { chromium, webkit } from 'playwright'
import { zipSync } from 'fflate'
import assert from 'node:assert/strict'

const assets = fileURLToPath(new URL('../assets/', import.meta.url))

export async function createHarness(t, { assetPrefix = '', deviceScaleFactor } = {}) {
    const requests = []
    const routes = new Map([
        ['/blank', '<!doctype html><html><body></body></html>'],
    ])
    const server = http.createServer(async (req, res) => {
        const pathname = new URL(req.url, 'http://localhost').pathname
        requests.push(pathname)
        if (routes.has(pathname)) {
            res.setHeader('content-type', 'text/html')
            res.end(routes.get(pathname))
            return
        }
        try {
            if (assetPrefix && !pathname.startsWith(assetPrefix + '/')) throw new Error('Outside asset scope')
            const assetPath = pathname.slice(assetPrefix.length)
            const file = path.resolve(assets, `.${assetPath}`)
            if (!file.startsWith(assets)) throw new Error('Outside assets')
            const data = await readFile(file)
            res.setHeader('content-type', file.endsWith('.js') ? 'text/javascript' : 'text/html')
            res.end(data)
        } catch {
            res.writeHead(404).end()
        }
    })
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
    t.after(() => new Promise(resolve => server.close(resolve)))
    const engine = process.env.READER_BROWSER === 'webkit' ? webkit : chromium
    const browser = await engine.launch({
        headless: true,
        ...(process.env.READER_BROWSER_CHANNEL ? { channel: process.env.READER_BROWSER_CHANNEL } : {}),
    })
    t.after(() => browser.close())
    const page = await browser.newPage(deviceScaleFactor ? { deviceScaleFactor } : {})
    await page.addInitScript(() => {
        window.bridgeCalls = []
        window.flutter_inappwebview = { callHandler: (...args) => {
            window.bridgeCalls.push(args)
            return Promise.resolve()
        } }
    })
    const origin = `http://127.0.0.1:${server.address().port}`
    const articleUrl = (contentPath = '/article-content') =>
        `${origin}/article-html/index.html?${new URLSearchParams({
            contentUrl: JSON.stringify(origin + contentPath),
            contentBaseUrl: JSON.stringify(origin + '/saved/'),
        })}`
    return { page, origin, routes, requests, articleUrl }
}

export async function openEpub(page, origin, chapter, fixed = false) {
    await page.goto(origin + '/blank?style=' + encodeURIComponent('{"allowScript":false}'))
    return page.evaluate(async ({ chapter, fixed }) => {
        const { EPUB } = await import('/foliate-js/src/epub.js')
        await import('/foliate-js/src/view.js')
        const files = {
            'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
            'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">test</dc:identifier><dc:title>Test</dc:title><dc:language>en</dc:language>${fixed ? '<meta property="rendition:layout">pre-paginated</meta>' : ''}</metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>`,
            'chapter.xhtml': chapter,
        }
        const book = await new EPUB({
            loadText: async name => files[name] ?? null,
            loadBlob: async name => files[name] == null ? null : new Blob([files[name]]),
            getSize: name => files[name]?.length ?? 0,
        }).init()
        const view = document.createElement('foliate-view')
        view.style.cssText = 'display:block;width:800px;height:600px'
        document.body.append(view)
        await view.open(book)
        await view.goTo(0)
        window.testView = view
    }, { chapter, fixed })
}

// Opens a five-page generated CBZ through the real comic pipeline.
export async function openComic(t, { axis = 'slide', rtl = false, hostTaps = false, controlledClock = false } = {}) {
    const harness = await createHarness(t)
    const { page, origin } = harness
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    if (controlledClock) await page.clock.install()
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(origin + '/blank')
    const images = await page.evaluate(() => Array.from({ length: 5 }, (_, index) => {
        const canvas = document.createElement('canvas')
        canvas.width = 600; canvas.height = 900
        const ctx = canvas.getContext('2d')
        ctx.fillStyle = '#ddedef'; ctx.fillRect(0, 0, 600, 900)
        ctx.fillStyle = '#40898d'; ctx.fillRect(20, 20, 560, 390)
        ctx.fillStyle = '#b76474'; ctx.fillRect(20, 430, 560, 450)
        ctx.fillStyle = '#ffffff'; ctx.font = '30px sans-serif'
        ctx.fillText('Comic page ' + index, 100, 200)
        return canvas.toDataURL().split(',')[1]
    }))
    const archive = zipSync(Object.fromEntries(images.map((image, index) =>
        [`page${index}.png`, Buffer.from(image, 'base64')])), { level: 0 })
    // Replace transport only: real archive decoding, comic loader, view and bridge.
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() {
                return new File([Uint8Array.from(${JSON.stringify([...archive])})], 'zoom.cbz');
            }
        }`,
    }))
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/zoom.cbz'),
        pageHostTaps: JSON.stringify(hostTaps),
        pageProgressionDirection: JSON.stringify(rtl ? 'rtl' : 'ltr'),
        style: JSON.stringify({ pageTurnStyle: axis, allowScript: false,
            fontName: 'serif', fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb' }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.waitForFunction(() => {
        const renderer = window.reader?.view?.renderer
        const doc = renderer?.getContents().find(({ index }) => index === renderer.index)?.doc
        return doc?.querySelector('img')?.complete && doc.defaultView.frameElement.getBoundingClientRect().width > 300
    })
    await page.waitForTimeout(50)
    await page.evaluate(() => { window.bridgeCalls.length = 0 })
    return harness
}

// Dispatches a touch-style pointer event at viewport coordinates inside the page iframe.
export async function pointer(page, type, x, y, id = 1) {
    return pointers(page, [{ type, x, y, id }])
}

// Dispatches [steps] ({type, x, y, id?}) in one evaluate, so protocol latency
// under load cannot stretch a timed gesture such as a double tap.
export async function pointers(page, steps) {
    return page.evaluate(steps => {
        const touchTypes = {pointerdown: 'touchstart', pointermove: 'touchmove', pointerup: 'touchend', pointercancel: 'touchcancel'}
        for (const { type, x, y, id = 1 } of steps) {
            const renderer = window.reader.view.renderer
            const doc = renderer.getContents().find(({index}) => index === renderer.index).doc
            const frame = doc.defaultView.frameElement
            const rect = frame.getBoundingClientRect()
            const clientX = (x - rect.left) * frame.clientWidth / rect.width
            const clientY = (y - rect.top) * frame.clientHeight / rect.height
            const target = doc.elementFromPoint(clientX, clientY) ?? doc.body
            target.dispatchEvent(new doc.defaultView.PointerEvent(type, {
                pointerId: id, pointerType: 'touch', bubbles: true, cancelable: true,
                clientX, clientY, screenX: x, screenY: y, button: 0,
            }))
            const event = new Event(touchTypes[type], { bubbles: true, cancelable: true })
            const touch = { identifier: id, clientX, clientY, screenX: x, screenY: y }
            Object.defineProperties(event, { touches: { value: type === 'pointerup' ? [] : [touch] }, changedTouches: { value: [touch] } })
            target.dispatchEvent(event)
        }
    }, steps)
}

// A4 pages in points. Each page has a title, justified-width body lines inside
// 72 pt margins and a blue figure; page 0 links to page 2; the last page holds
// only a short centred title. With [embeddedFont] (TrueType bytes) the body is
// set in that font, which pdf.js loads as a document font like real books.
export function makePdf({ pages = 6, embeddedFont = null } = {}) {
    const objects = []
    const add = body => { objects.push(body); return objects.length }
    const catalog = add(null)
    const pagesRef = add(null)
    const font = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    let bodyFont = font
    if (embeddedFont) {
        const program = add(`<< /Length ${embeddedFont.length} /Length1 ${embeddedFont.length} >>\nstream\n${embeddedFont.toString('latin1')}\nendstream`)
        const descriptor = add(`<< /Type /FontDescriptor /FontName /Embedded /Flags 32 /FontBBox [-200 -300 1200 1000] /ItalicAngle 0 /Ascent 900 /Descent -250 /CapHeight 700 /StemV 80 /FontFile2 ${program} 0 R >>`)
        bodyFont = add(`<< /Type /Font /Subtype /TrueType /BaseFont /Embedded /FirstChar 32 /LastChar 126 /Widths [${Array(95).fill(520).join(' ')}] /Encoding /WinAnsiEncoding /FontDescriptor ${descriptor} 0 R >>`)
    }
    const pageRefs = []
    const contents = []
    for (let index = 0; index < pages; index++) {
        const sparse = index === pages - 1 && pages > 1
        const lines = sparse
            ? ['BT /F1 18 Tf 250 430 Td (The End) Tj ET']
            : [
                '0 0 1 rg 72 120 451 120 re f 0 g',
                `BT /F1 18 Tf 72 760 Td (Page ${index + 1} title) Tj ET`,
                'BT /F2 11 Tf 14 TL 72 720 Td',
                ...Array.from({ length: 30 }, (_, line) =>
                    `(Line ${line + 1} of page ${index + 1}: readable body text that spans the column width.) Tj T*`),
                'ET',
            ]
        const stream = lines.join('\n')
        contents.push(add(`<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`))
        pageRefs.push(add(null))
    }
    const link = add(null)
    objects[catalog - 1] = `<< /Type /Catalog /Pages ${pagesRef} 0 R >>`
    objects[pagesRef - 1] = `<< /Type /Pages /Count ${pages} /Kids [${pageRefs.map(ref => `${ref} 0 R`).join(' ')}] >>`
    pageRefs.forEach((ref, index) => {
        const annots = index === 0 && pages > 2 ? ` /Annots [${link} 0 R]` : ''
        objects[ref - 1] = `<< /Type /Page /Parent ${pagesRef} 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 ${font} 0 R /F2 ${bodyFont} 0 R >> >> /Contents ${contents[index]} 0 R${annots} >>`
    })
    objects[link - 1] = pages > 2
        ? `<< /Type /Annot /Subtype /Link /Rect [72 755 260 780] /Border [0 0 0] /Dest [${pageRefs[2]} 0 R /XYZ 0 842 0] >>`
        : '<< >>'
    let pdf = '%PDF-1.4\n'
    const offsets = objects.map((body, index) => {
        const offset = pdf.length
        pdf += `${index + 1} 0 obj\n${body}\nendobj\n`
        return offset
    })
    const xref = pdf.length
    pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`
    for (const offset of offsets) pdf += `${String(offset).padStart(10, '0')} 00000 n \n`
    pdf += `trailer\n<< /Size ${objects.length + 1} /Root ${catalog} 0 R >>\nstartxref\n${xref}\n%%EOF\n`
    return Buffer.from(pdf, 'latin1')
}

// Opens a generated PDF through the real reader bootstrap on a 3x phone.
// `window.__pageCanvases` lists every canvas the page creates, so tests can
// check that released bitmaps were freed.
export async function openPdf(t, {
    pages = 6, hostTaps = false, style = {}, deviceScaleFactor = 3, viewport = { width: 390, height: 844 },
    embeddedFont = null,
} = {}) {
    const harness = await createHarness(t, { deviceScaleFactor })
    const { page, origin } = harness
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    await page.addInitScript(() => {
        window.__pageCanvases = []
        // Counts PDF page documents parsed for search, not for display.
        const parse = DOMParser.prototype.parseFromString
        DOMParser.prototype.parseFromString = function (text, type) {
            if (String(text).includes('readflex-pdf-page')) window.__searchDocuments = (window.__searchDocuments ?? 0) + 1
            return parse.call(this, text, type)
        }
        const create = Document.prototype.createElement
        Document.prototype.createElement = function (name, options) {
            const element = create.call(this, name, options)
            if (String(name).toLowerCase() === 'canvas') window.__pageCanvases.push(element)
            return element
        }
    })
    await page.setViewportSize(viewport)
    const bytes = makePdf({ pages, embeddedFont })
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() {
                const bytes = Uint8Array.from(atob('${bytes.toString('base64')}'), c => c.charCodeAt(0));
                return new File([bytes], 'test.pdf');
            }
        }`,
    }))
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/test.pdf'),
        pageHostTaps: JSON.stringify(hostTaps),
        style: JSON.stringify({ pageTurnStyle: 'slide', allowScript: false,
            fontName: 'serif', fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb', ...style }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await waitForPdfPage(page)
    await page.evaluate(() => { window.bridgeCalls.length = 0 })
    return harness
}

// Waits until the current page bitmap is drawn into a laid-out frame.
export async function waitForPdfPage(page, index) {
    await page.waitForFunction(index => {
        const renderer = window.reader?.view?.renderer
        if (index != null && renderer?.index !== index) return false
        const doc = renderer?.getContents().find(entry => entry.index === renderer.index)?.doc
        return doc?.querySelector('canvas.readflex-pdf-page')?.width > 0
            && doc.defaultView.frameElement.getBoundingClientRect().width > 150
    }, index)
}
