import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

// A paginated section is sized with one swipe-overshoot buffer column on
// each side. On the first chapter the leading buffer leads nowhere, so a
// navigation anchor that resolves to it (a collapsed range at the very start
// of an image-only cover page) must land on the first content column instead
// of a blank page.
async function openCoverBook(page, origin, { mode = 'horizontal', margins = true } = {}) {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(origin + '/blank?style=' + encodeURIComponent('{"allowScript":false}'))
    await page.evaluate(async ({ mode, margins }) => {
        const { EPUB } = await import('/foliate-js/src/epub.js')
        await import('/foliate-js/src/view.js')
        const canvas = document.createElement('canvas')
        canvas.width = 300; canvas.height = 450
        const ctx = canvas.getContext('2d')
        ctx.fillStyle = '#b76474'; ctx.fillRect(0, 0, 300, 450)
        const coverBlob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
        const paragraphs = Array.from({ length: 40 }, (_, i) =>
            `<p>Paragraph ${i}. Body text after the cover keeps the book longer than one page.</p>`).join('')
        const files = {
            'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
            'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">cover-return</dc:identifier><dc:title>Cover</dc:title><dc:language>en</dc:language></metadata><manifest><item id="cover-image" href="cover.png" media-type="image/png"/><item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="cover"/><itemref idref="one"/></spine></package>',
            'cover.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Cover</title><style>body{margin:0}img{width:100%;height:auto}</style></head><body><img id="cover" src="cover.png" alt=""/></body></html>`,
            'one.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>One</title><style>body { font: 20px/1.5 serif; }</style></head><body><h1>Chapter one</h1>${paragraphs}</body></html>`,
        }
        const book = await new EPUB({
            loadText: async name => typeof files[name] === 'string' ? files[name] : null,
            loadBlob: async name => name === 'cover.png' ? coverBlob
                : files[name] == null ? null : new Blob([files[name]]),
            getSize: name => name === 'cover.png' ? coverBlob.size : files[name]?.length ?? 0,
        }).init()
        const view = document.createElement('foliate-view')
        view.style.cssText = 'display:block;width:390px;height:844px'
        document.body.append(view)
        await view.open(book)
        view.renderer.setAttribute('flow', 'paginated')
        view.renderer.setAttribute('page-turn-axis', mode === 'vertical' ? 'vertical' : 'horizontal')
        view.renderer.setAttribute('max-column-count', '1')
        view.renderer.setAttribute('gap', '8%')
        if (margins) {
            view.renderer.setAttribute('top-margin', '24px')
            view.renderer.setAttribute('bottom-margin', '24px')
        }
        await view.goTo(0)
        window.testView = view
    }, { mode, margins })
    await page.waitForFunction(() => {
        const doc = window.testView?.renderer?.getContents()[0]?.doc
        const img = doc?.getElementById('cover')
        return Boolean(img?.complete && img.naturalWidth > 0)
    })
}

const location = page => page.evaluate(() => {
    const view = window.testView
    const renderer = view.renderer
    const { doc, index } = renderer.getContents()[0]
    const img = doc.getElementById('cover')
    // The section iframe is wider than the renderer and scrolled inside it;
    // measure the image in window coordinates against the renderer box.
    const frame = doc.defaultView.frameElement.getBoundingClientRect()
    const host = renderer.getBoundingClientRect()
    const local = img ? img.getBoundingClientRect() : null
    const rect = local ? { left: frame.left + local.left, top: frame.top + local.top,
        right: frame.left + local.right, bottom: frame.top + local.bottom, width: local.width, height: local.height } : null
    const visibleWidth = rect ? Math.max(0, Math.min(rect.right, host.right) - Math.max(rect.left, host.left)) : 0
    const visibleHeight = rect ? Math.max(0, Math.min(rect.bottom, host.bottom) - Math.max(rect.top, host.top)) : 0
    return {
        index,
        page: renderer.page,
        atStart: renderer.atStart,
        cfi: view.lastLocation?.cfi ?? null,
        coverVisible: Boolean(rect && rect.width > 0 &&
            visibleWidth * visibleHeight > rect.width * rect.height * 0.5),
    }
})

for (const mode of ['horizontal', 'vertical']) {
    for (const margins of [true, false]) {
    test(`${mode}, margins=${margins}: returning to the cover by CFI lands on the cover, not the leading buffer page`, async t => {
        const { page, origin } = await createHarness(t)
        const errors = []
        page.on('pageerror', error => errors.push(error.message))
        await openCoverBook(page, origin, { mode, margins })

        const start = await location(page)
        assert.equal(start.index, 0)
        assert.equal(start.page, 1, 'opening the book shows the first content column')
        assert.equal(start.coverVisible, true)
        assert.ok(start.cfi, 'the cover page reports a CFI the app can return to')

        await page.evaluate(() => window.testView.goTo(1))
        await page.waitForFunction(() => window.testView.renderer.getContents()[0]?.index === 1)

        await page.evaluate(cfi => window.testView.goTo(cfi), start.cfi)
        await page.waitForFunction(() => window.testView.renderer.getContents()[0]?.index === 0)
        const back = await location(page)
        assert.equal(back.page, 1, 'anchor at the cover start must not resolve to the blank buffer column')
        assert.equal(back.atStart, true)
        assert.equal(back.coverVisible, true)
        assert.equal(back.index, 0)

        // Fraction 0 and the section index take the same guard.
        await page.evaluate(() => window.testView.goTo(1))
        await page.waitForFunction(() => window.testView.renderer.getContents()[0]?.index === 1)
        await page.evaluate(() => window.testView.goToFraction(0))
        await page.waitForFunction(() => window.testView.renderer.getContents()[0]?.index === 0)
        assert.equal((await location(page)).page, 1)
        assert.deepEqual(errors, [])
    })
    }
}
