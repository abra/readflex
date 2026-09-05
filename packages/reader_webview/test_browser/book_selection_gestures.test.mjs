import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

const chapter = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Selection</title>
<style>body { font: 20px/1.5 serif; } p { margin: 0 0 20px; }</style></head><body>
${Array.from({ length: 60 }, (_, i) => `<p id="p${i}">Paragraph ${i}. The power bank keeps devices running. Select these words without turning the page.</p>`).join('')}
</body></html>`

async function openVerticalBook(t, { runtime = false, appleTouch = false } = {}) {
    const harness = await createHarness(t)
    const { page, origin } = harness
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, [], 'reader must not throw during selection'))
    await page.setViewportSize({ width: 390, height: 844 })
    if (appleTouch) await page.addInitScript(() => {
        Object.defineProperty(navigator, 'userAgent', { value: 'iPhone AppleWebKit' })
    })
    if (runtime) {
        // Only replace transport: exercise book.js and its actual EPUB loader
        // through the supported directory-entry interface, without a ZIP fixture.
        const files = {
            'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
            'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">selection</dc:identifier><dc:title>Selection</dc:title><dc:language>en</dc:language></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
            'chapter.xhtml': chapter,
        }
        await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
            contentType: 'text/javascript',
            body: `export class RemoteFile {
                async open() {
                    return { isDirectory: true, fullPath: '', createReader: () => ({
                        readEntries: callback => callback(Object.entries(${JSON.stringify(files)}).map(([name, text]) => ({
                            isFile: true, fullPath: '/' + name,
                            file: callback => callback(new File([text], name)),
                        }))),
                    }) }
                }
            }`,
        }))
        const params = new URLSearchParams({
            url: JSON.stringify(origin + '/selection.epub'),
            style: JSON.stringify({
                pageTurnStyle: 'vertical', allowScript: false,
                fontName: 'serif', fontColor: '#000000', backgroundColor: '#ffffff',
                fontSize: 20, textScale: 1, fontWeight: 400, spacing: 1.5,
                topMargin: 24, bottomMargin: 24, sideMargin: 8,
                maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
            }),
            readingRules: JSON.stringify({ convertChineseMode: 'none' }),
        })
        await page.goto(origin + '/foliate-js/index.html?' + params)
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => { window.testView = window.reader.view })
    } else {
        await openEpub(page, origin, chapter)
        await page.evaluate(() => {
            const view = window.testView
            view.style.cssText = 'display:block;width:390px;height:844px'
            const renderer = view.renderer
            renderer.setAttribute('flow', 'paginated')
            renderer.setAttribute('page-turn-axis', 'vertical')
            renderer.setAttribute('max-column-count', '1')
            renderer.setAttribute('gap', '8%')
            renderer.setAttribute('top-margin', '24px')
            renderer.setAttribute('bottom-margin', '24px')
        })
    }
    await page.evaluate(async () => {
        window.testView.style.cssText = 'display:block;width:390px;height:844px'
        await window.testView.goTo(0)
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        window.testView.renderer.setAttribute('animated', '')
        const doc = window.testView.renderer.getContents()[0].doc
        window.sendTouch = (type, x = 190, y = 500) => {
            const touch = { identifier: 1, target: doc.body, screenX: x, screenY: y, clientX: x, clientY: y }
            const event = new Event(type, { bubbles: true, cancelable: true })
            Object.defineProperties(event, {
                touches: { value: type === 'touchend' || type === 'touchcancel' ? [] : [touch] },
                changedTouches: { value: [touch] },
            })
            doc.body.dispatchEvent(event)
            return event.defaultPrevented
        }
        window.selectWords = () => {
            const range = doc.createRange()
            range.setStart(doc.getElementById('p0').firstChild, 0)
            range.setEnd(doc.getElementById('p0').firstChild, 12)
            doc.getSelection().removeAllRanges()
            doc.getSelection().addRange(range)
            doc.dispatchEvent(new Event('selectionchange'))
        }
        window.snapCalls = 0
        const snap = window.testView.renderer.snap.bind(window.testView.renderer)
        window.testView.renderer.snap = (...args) => { window.snapCalls++; return snap(...args) }
    })
    return harness
}

test('vertical book selection at the page boundary does not schedule a page turn', async t => {
    const { page } = await openVerticalBook(t, { runtime: true })
    const original = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        doc.dispatchEvent(new Event('selectstart'))
        const range = view.lastLocation.range.cloneRange()
        doc.getSelection().addRange(range)
        doc.dispatchEvent(new Event('selectionchange'))
        return { page: view.renderer.page, text: doc.getSelection().toString() }
    })
    assert.ok(original.text.length > 0)
    // Exceed the old one-second auto-page timer, including its animation.
    await page.waitForTimeout(1500)
    assert.deepEqual(await page.evaluate(() => ({
        page: window.testView.renderer.page,
        text: window.testView.renderer.getContents()[0].doc.getSelection().toString(),
    })), original)
})

test('iOS keeps the native range without a second preview, and saved highlights still render', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: true })
    const original = await page.evaluate(() => {
        window.selectWords()
        const reader = window.reader
        const { doc, index } = reader.view.renderer.getContents()[0]
        const range = doc.getSelection().getRangeAt(0)
        const cfi = reader.view.getCFI(index, range)
        window.selectionTestCfi = cfi
        reader.showSelectionHighlightPreview({ cfi, color: '#ffff00' })
        return range.toString()
    })
    assert.equal(await page.evaluate(() => window.reader.annotationsById
        .has('__readflex-selection-preview-highlight')), false)
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
        .doc.getSelection().toString()), original)
    await page.evaluate(() => {
        window.reader.clearSelectionAfterTextAction()
        window.reader.addAnnotation({
            id: 'saved', type: 'highlight', value: window.selectionTestCfi,
            color: '#00ff00',
        })
    })
    await page.waitForFunction(() => window.testView.renderer.getContents()[0]
        .overlayer.element.querySelector('rect'))
    assert.equal(await page.evaluate(() => window.reader.annotationsById.get('saved').color), '#00ff00')
})

test('iOS removes a fallback preview when the native selection reappears', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: true })
    await page.evaluate(() => {
        const reader = window.reader
        const { doc, index } = reader.view.renderer.getContents()[0]
        const range = doc.createRange()
        range.setStart(doc.getElementById('p0').firstChild, 0)
        range.setEnd(doc.getElementById('p0').firstChild, 12)
        reader.showSelectionHighlightPreview({ cfi: reader.view.getCFI(index, range), color: '#ffff00' })
    })
    await page.waitForFunction(() => window.testView.renderer.getContents()[0]
        .overlayer.element.querySelector('rect'))
    await page.evaluate(() => window.selectWords())
    assert.equal(await page.evaluate(() => window.reader.annotationsById
        .has('__readflex-selection-preview-highlight')), false)
    await page.waitForFunction(() => !window.testView.renderer.getContents()[0]
        .overlayer.element.querySelector('rect'))
})

test('dragging an existing selection belongs to the iframe, not the page swipe handler', async t => {
    const { page } = await openVerticalBook(t)
    const result = await page.evaluate(() => {
        window.selectWords()
        window.sendTouch('touchstart')
        const prevented = window.sendTouch('touchmove', 190, 100)
        const doc = window.testView.renderer.getContents()[0].doc
        const transform = doc.defaultView.frameElement.parentElement.style.transform
        window.sendTouch('touchend', 190, 100)
        return { prevented, transform, page: window.testView.renderer.page }
    })
    await page.waitForTimeout(600)
    assert.equal(result.prevented, false, 'native selection must retain the gesture')
    assert.equal(result.transform, '')
    assert.equal(await page.evaluate(() => window.testView.renderer.page), result.page)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('a long press that starts selection cannot snap on release, even if the range collapses', async t => {
    const { page } = await openVerticalBook(t)
    await page.evaluate(() => {
        window.sendTouch('touchstart')
        window.selectWords()
        const doc = window.testView.renderer.getContents()[0].doc
        doc.getSelection().removeAllRanges()
        doc.dispatchEvent(new Event('selectionchange'))
        window.sendTouch('touchend')
    })
    await page.waitForTimeout(600)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('selection created after touchend cancels the pending snap frame', async t => {
    const { page } = await openVerticalBook(t)
    await page.evaluate(() => {
        window.sendTouch('touchstart')
        window.sendTouch('touchend')
        window.selectWords()
    })
    await page.waitForTimeout(600)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('a selection appearing during a vertical release animation stops that page turn', async t => {
    const { page } = await openVerticalBook(t)
    const originalPage = await page.evaluate(() => {
        const page = window.testView.renderer.page
        window.sendTouch('touchstart')
        window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchend', 190, 100)
        window.selectWords()
        return page
    })
    await page.waitForTimeout(600)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), originalPage)
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
        .doc.defaultView.frameElement.parentElement.style.transform), '')
})

test('cancelled vertical swipes leave no preview and a fresh swipe still turns one page', async t => {
    const { page } = await openVerticalBook(t)
    await page.evaluate(() => {
        window.sendTouch('touchstart')
        window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchcancel', 190, 100)
    })
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
        .doc.defaultView.frameElement.parentElement.style.transform), '')
    const originalPage = await page.evaluate(() => {
        window.selectWords()
        const doc = window.testView.renderer.getContents()[0].doc
        doc.getSelection().removeAllRanges()
        doc.dispatchEvent(new Event('selectionchange'))
        const originalPage = window.testView.renderer.page
        window.sendTouch('touchstart')
        window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchend', 190, 100)
        return originalPage
    })
    await page.waitForFunction(original => window.testView.renderer.page === original + 1, originalPage)
    await page.waitForTimeout(300)
    await page.evaluate(() => {
        window.sendTouch('touchstart', 190, 100)
        window.sendTouch('touchmove', 190, 500)
        window.sendTouch('touchend', 190, 500)
    })
    await page.waitForFunction(original => window.testView.renderer.page === original, originalPage)
})

test('backward multi-page selection keeps its complete text and CFI for reader actions', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: true })
    const result = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        const start = doc.getElementById('p0').firstChild
        const end = doc.getElementById('p12').firstChild
        const selection = doc.getSelection()
        selection.setBaseAndExtent(end, end.length, start, 0)
        doc.dispatchEvent(new Event('selectionchange'))
        const payload = window.getCurrentTextSelection()
        return {
            expected: selection.getRangeAt(0).toString(), actual: payload.text,
            restored: view.resolveCFI(payload.cfi).anchor(doc).toString(),
            backward: selection.focusNode === start, page: view.renderer.page,
        }
    })
    assert.ok(result.expected.includes('Paragraph 12.'))
    assert.equal(result.backward, true)
    assert.equal(result.actual, result.expected)
    assert.equal(result.restored, result.expected)
    await page.waitForTimeout(1500)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), result.page)
})

test('book continuous scroll keeps native movement and skips page snapping', async t => {
    const { page } = await openVerticalBook(t)
    const prevented = await page.evaluate(() => {
        window.testView.renderer.setAttribute('flow', 'scrolled')
        window.sendTouch('touchstart')
        const prevented = window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchend', 190, 100)
        return prevented
    })
    await page.waitForTimeout(600)
    assert.equal(prevented, false)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('selection cancels a horizontal reader pull gesture without leaving content shifted', async t => {
    const { page } = await openVerticalBook(t, { runtime: true })
    await page.evaluate(() => {
        window.changeStyle({ pageTurnStyle: 'slide' })
        window.sendTouch('touchstart', 190, 100)
        window.sendTouch('touchmove', 190, 300)
    })
    assert.notEqual(await page.evaluate(() => window.testView.renderer.style.transform), '')
    await page.evaluate(() => {
        window.selectWords()
        window.sendTouch('touchend', 190, 300)
    })
    assert.equal(await page.evaluate(() => window.testView.renderer.style.transform), '')
})
