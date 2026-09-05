import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

for (const fixed of [false, true]) {
    test(`EPUB blocks publisher scripts before ${fixed ? 'fixed' : 'reflow'} section load`, async t => {
        const { page, origin, requests } = await createHarness(t)
        await openEpub(page, origin, `<html xmlns="http://www.w3.org/1999/xhtml"><head>
            <meta name="viewport" content="width=800,height=600"/>
            <title>Chapter</title><style>#passage { color: rgb(15, 90, 45) }</style>
            <script>parent.publisherExecuted = true</script>
            <script src="${origin}/external.js"></script>
            </head><body onload="parent.publisherExecuted = true">
            <p id="passage">Readable <em>text</em> and power.</p>
            <img src="missing.png" onerror="parent.publisherExecuted = true"/>
            <iframe srcdoc="&lt;script>parent.parent.publisherExecuted=true&lt;/script>"></iframe>
            <svg xmlns="http://www.w3.org/2000/svg" onload="parent.publisherExecuted = true"><text>Diagram</text></svg>
            <a href="javascript:parent.publisherExecuted=true">Unsafe</a>
            </body></html>`, fixed)
        const result = await page.evaluate(() => {
            const doc = window.testView.renderer.getContents()[0].doc
            const range = doc.createRange()
            const passage = doc.getElementById('passage')
            range.setStart(passage.firstChild, 0)
            range.setEnd(passage.lastChild, passage.lastChild.length)
            const cfi = window.testView.getCFI(0, range)
            const restored = window.testView.resolveCFI(cfi).anchor(doc)
            return {
                executed: Boolean(window.publisherExecuted),
                scripts: doc.querySelectorAll('script,iframe,[onload],[onerror],a[href^="javascript:"]').length,
                selected: range.toString(),
                restored: restored.toString(),
                color: doc.defaultView.getComputedStyle(doc.getElementById('passage')).color,
            }
        })
        assert.equal(result.executed, false)
        assert.equal(result.scripts, 0)
        assert.equal(result.selected, 'Readable text and power.')
        assert.equal(result.restored, result.selected)
        assert.equal(result.color, 'rgb(15, 90, 45)')
        assert.equal(requests.includes('/external.js'), false)
    })
}

test('stored article cannot retry remote images outside the guarded downloader', async t => {
    const { page, origin, requests, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', `<p id="block-0">Readable article.</p>
        <img src="${origin}/private-image"/>
        <img src="images/local.png" alt="Local"/>
        <img srcset="${origin}/private-srcset 2x"/>
        <img src="../private-traversal"/>`)
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(call => call[0] === 'onLoadEnd'))
    assert.equal(requests.includes('/private-image'), false)
    assert.equal(requests.includes('/private-srcset'), false)
    assert.equal(requests.includes('/private-traversal'), false)
    assert.equal(requests.includes('/saved/images/local.png'), true)
})

test('article filtering preserves tables, code and sentence anchor attributes', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', `<h2 id="section-1">Data</h2>
        <div id="block-0" data-rf-block-id="block-0" class="rf-table-scroll"><table><tbody><tr><td>Cell</td></tr></tbody></table></div>
        <p id="block-1" data-rf-block-id="block-1"><span id="block-1-s0" data-rf-sentence="0">A sentence.</span></p>
        <pre id="block-2"><code>const a = 1 &lt; 2;</code></pre>`)
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(call => call[0] === 'onLoadEnd'))
    assert.equal(await page.locator('.rf-table-scroll table td').textContent(), 'Cell')
    assert.equal(await page.locator('#block-1-s0').getAttribute('data-rf-sentence'), '0')
    assert.equal(await page.locator('pre code').textContent(), 'const a = 1 < 2;')
})
