import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

// A render that reaches a chapter view before its document has loaded (the
// frame-coalesced ResizeObserver during a chapter swap) must leave the view
// alone: the iframe still holds about:blank, whose empty body would size it to
// 0px and make the chapter's first layout run at that width.

const chapter = `<!doctype html><html><head><title>Chapter</title></head><body>${
    Array.from({ length: 60 }, (_, i) =>
        `<p>Paragraph ${i} carries a few sentences of ordinary prose for the layout.</p>`).join('')
}</body></html>`

test('a render before the chapter loads leaves the view alone', async t => {
    const { page, origin, routes } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    routes.set('/paginator', `<!doctype html><html><body style="margin:0">
        <script type="module">
            import '/foliate-js/src/paginator.js'
            window.paginatorReady = true
        </script></body></html>`)
    let release
    const released = new Promise(resolve => { release = resolve })
    let requested
    const chapterRequested = new Promise(resolve => { requested = resolve })
    await page.route('**/chapter.html', async route => {
        requested()
        await released
        await route.fulfill({ contentType: 'text/html', body: chapter })
    })
    await page.setViewportSize({ width: 390, height: 700 })
    await page.goto(`${origin}/paginator`)
    await page.waitForFunction(() => window.paginatorReady)

    await page.evaluate(origin => {
        const paginator = document.createElement('foliate-paginator')
        paginator.style.cssText = 'display:block;width:390px;height:700px'
        // What the reader sets for a phone page.
        for (const [name, value] of Object.entries({
            flow: 'paginated', gap: '5%', 'max-inline-size': '512px',
            'max-block-size': '1440px', 'max-column-count': '1',
            'top-margin': '40px', 'bottom-margin': '40px',
        })) paginator.setAttribute(name, value)
        document.body.append(paginator)
        paginator.open({
            dir: 'ltr',
            sections: [{ linear: 'yes', size: 1, load: () => `${origin}/chapter.html` }],
        })
        window.paginator = paginator
        window.opened = paginator.goTo({ index: 0 })
    }, origin)
    await chapterRequested

    const iframeWidth = () => page.evaluate(() =>
        window.paginator.shadowRoot.querySelector('iframe').style.width)
    const before = await iframeWidth()
    await page.evaluate(() => window.paginator.render())
    assert.equal(await iframeWidth(), before, 'the blank view keeps its size')
    assert.notEqual(before, '0px')

    release()
    await page.evaluate(() => window.opened)
    const laidOut = await page.evaluate(() => {
        const iframe = window.paginator.shadowRoot.querySelector('iframe')
        return {
            width: parseFloat(iframe.style.width),
            text: iframe.contentDocument.body.textContent.includes('Paragraph 59'),
        }
    })
    assert.ok(laidOut.text, 'the chapter loaded')
    // Whole pages of the 390px window, more than one for sixty paragraphs.
    assert.ok(laidOut.width >= 390 * 2, `${laidOut.width}px`)
    assert.equal(laidOut.width % 390, 0)
})
