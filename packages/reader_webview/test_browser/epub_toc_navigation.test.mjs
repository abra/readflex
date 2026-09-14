import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

const targets = {
    heading: { markup: '<h2 id="chapter-target" data-toc-target="">Target section</h2>' },
    'hidden inline anchor': { markup: '<h2 data-toc-target=""><span id="chapter-target" hidden="hidden"></span>Target section</h2>' },
    'hidden standalone anchor': { markup: '<span id="chapter-target" hidden="hidden"></span><h2 data-toc-target="">Target section</h2>' },
    'empty named anchor': { markup: '<h2 data-toc-target=""><a name="chapter-target"></a>Target section</h2>' },
    'display-contents anchor': { markup: '<h2 data-toc-target=""><span id="chapter-target" style="display:contents">Target section</span></h2>' },
    'terminal hidden anchor': { markup: '<h2 data-toc-target="">Target section</h2><span id="chapter-target" hidden="hidden"></span>', terminal: true },
    'chapter link without fragment': { markup: '<div><h1 data-toc-target="" style="margin-top:1200px">Target section</h1></div>', chapterStart: true },
}

async function openBook(page, origin, target, mode) {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(origin + '/blank?style=' + encodeURIComponent('{"allowScript":false}'))
    await page.evaluate(async ({ target: { markup, terminal, chapterStart }, mode }) => {
        const { EPUB } = await import('/foliate-js/src/epub.js')
        await import('/foliate-js/src/view.js')
        const paragraphs = Array.from({ length: 24 }, (_, i) =>
            `<p>Paragraph ${i}. A reader should navigate to the requested section, regardless of its anchor markup.</p>`).join('')
        const chapter = title => `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>${title}</title>
            <style>body { font: 20px/1.5 serif; } [hidden] { display: none; }</style></head>
            <body>${chapterStart ? '' : `<h1>${title}</h1>${paragraphs}`}${markup}${terminal ? '' : paragraphs}</body></html>`
        const fragment = chapterStart ? '' : '#chapter-target'
        const files = {
            'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
            'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">toc-navigation</dc:identifier><dc:title>Navigation</dc:title><dc:language>en</dc:language></metadata><manifest><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/></manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>',
            'nav.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc"><ol><li><a href="one.xhtml${fragment}">First target</a></li><li><a href="two.xhtml${fragment}">Second target</a></li></ol></nav></body></html>`,
            'one.xhtml': chapter('First chapter'),
            'two.xhtml': chapter('Second chapter'),
        }
        const book = await new EPUB({
            loadText: async name => files[name] ?? null,
            loadBlob: async name => files[name] == null ? null : new Blob([files[name]]),
            getSize: name => files[name]?.length ?? 0,
        }).init()
        const view = document.createElement('foliate-view')
        view.style.cssText = 'display:block;width:390px;height:844px'
        document.body.append(view)
        await view.open(book)
        view.renderer.setAttribute('flow', mode === 'scroll' ? 'scrolled' : 'paginated')
        view.renderer.setAttribute('page-turn-axis', mode === 'vertical' ? 'vertical' : 'horizontal')
        view.renderer.setAttribute('max-column-count', '1')
        view.renderer.setAttribute('gap', '8%')
        view.renderer.setAttribute('top-margin', '24px')
        view.renderer.setAttribute('bottom-margin', '24px')
        await view.goTo(0)
        window.testView = view
    }, { target, mode })
}

for (const mode of ['horizontal', 'vertical', 'scroll']) {
    for (const [kind, target] of Object.entries(targets)) {
        test(`${mode} TOC resolves ${kind} within and across chapters`, async t => {
            const { page, origin } = await createHarness(t)
            const errors = []
            page.on('pageerror', error => errors.push(error.message))
            await openBook(page, origin, target, mode)
            for (const index of [0, 1, 0]) {
                await page.evaluate(async index => {
                    const view = window.testView
                    await view.goTo(view.book.toc[index].href)
                    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
                }, index)
                const result = await page.evaluate(() => {
                    const view = window.testView, renderer = view.renderer
                    const { doc, index } = renderer.getContents()[0]
                    const heading = doc.querySelector('[data-toc-target]')
                    const frame = doc.defaultView.frameElement.getBoundingClientRect()
                    const viewport = view.getBoundingClientRect()
                    const visible = [...heading.getClientRects()].some(rect =>
                        rect.left + frame.left < viewport.right && rect.right + frame.left > viewport.left &&
                        rect.top + frame.top < viewport.bottom && rect.bottom + frame.top > viewport.top)
                    return { index, visible, page: renderer.page, text: heading.textContent,
                        anchorCount: doc.querySelectorAll('#chapter-target,[name="chapter-target"]').length }
                })
                assert.equal(result.index, index)
                assert.equal(result.text, 'Target section')
                assert.equal(result.anchorCount, target.chapterStart ? 0 : 1,
                    'navigation must retain the publisher anchor')
                assert.equal(result.visible, true, `TOC target must be visible: ${JSON.stringify(result)}`)
            }
            assert.deepEqual(errors, [])
        })
    }
}
