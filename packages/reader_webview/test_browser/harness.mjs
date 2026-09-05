import http from 'node:http'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { chromium, webkit } from 'playwright'

const assets = fileURLToPath(new URL('../assets/', import.meta.url))

export async function createHarness(t) {
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
            const file = path.resolve(assets, `.${pathname}`)
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
