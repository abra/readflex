import http from 'node:http'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { chromium, webkit } from 'playwright'
import { zipSync } from 'fflate'
import assert from 'node:assert/strict'

const assets = fileURLToPath(new URL('../assets/', import.meta.url))

export async function createHarness(t, { assetPrefix = '' } = {}) {
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
    const page = await browser.newPage()
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
        comicHostTaps: JSON.stringify(hostTaps),
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
    return page.evaluate(({ type, x, y, id }) => {
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
        const touchType = {pointerdown: 'touchstart', pointermove: 'touchmove', pointerup: 'touchend', pointercancel: 'touchcancel'}[type]
        const event = new Event(touchType, { bubbles: true, cancelable: true })
        const touch = { identifier: id, clientX, clientY, screenX: x, screenY: y }
        Object.defineProperties(event, { touches: { value: type === 'pointerup' ? [] : [touch] }, changedTouches: { value: [touch] } })
        target.dispatchEvent(event)
    }, { type, x, y, id })
}
