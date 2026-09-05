import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

test('article HTTP failure reports a terminal load failure to Flutter', async t => {
    const { page, articleUrl } = await createHarness(t)
    await page.goto(articleUrl('/missing'))
    await page.waitForFunction(() => window.bridgeCalls.some(call => call[0] === 'onJsError'))
    const calls = await page.evaluate(() => window.bridgeCalls.map(call => call[0]))
    assert.equal(calls.includes('onReaderLoadFailed'), true)
    assert.equal(calls.includes('onLoadEnd'), false)
})

test('article highlights remain visible without CSS Custom Highlight support', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    await page.addInitScript(() => { window.Highlight = undefined })
    routes.set('/article-content', '<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">Power powers devices.</span></p>')
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(call => call[0] === 'onLoadEnd'))
    const result = await page.evaluate(() => {
        const cfiRange = 'readflex-html-position:' + encodeURIComponent(JSON.stringify({
            blockId: 'block-0-s0', rangeRootId: 'block-0-s0', sentenceIndex: 0,
            sentenceText: 'Power powers devices.', matchText: 'powers', matchIndex: 6, matchLength: 6,
        }))
        const rendered = window.setArticleHighlights([{ id: 'saved', cfiRange, color: '#FFE600' }])
        window.showSelectionHighlightPreview({ cfiRange, color: '#FF0000' })
        window.clearSelectionHighlightPreview()
        return { rendered: rendered.rendered, text: document.getElementById('block-0-s0').textContent,
            rects: document.querySelectorAll('[data-rf-highlight-overlay] rect').length }
    })
    assert.equal(result.rendered, 1)
    assert.equal(result.text, 'Power powers devices.')
    assert.ok(result.rects > 0)

    // Geometry must follow reflow and document scrolling without wrapping text.
    for (const viewport of [{ width: 390, height: 844 }, { width: 1280, height: 720 }]) {
        await page.setViewportSize(viewport)
        await page.evaluate(async () => {
            document.getElementById('article-content').style.paddingTop = '1000px'
            document.getElementById('block-0-s0').scrollIntoView()
            await document.fonts.ready
            await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        })
        const geometry = await page.evaluate(() => {
            const text = document.getElementById('block-0-s0').firstChild
            const range = document.createRange()
            range.setStart(text, 6)
            range.setEnd(text, 12)
            const expected = range.getBoundingClientRect()
            const actual = document.querySelector('[data-rf-highlight-overlay] rect').getBoundingClientRect()
            return { dx: actual.x - expected.x, dy: actual.y - expected.y,
                dw: actual.width - expected.width, dh: actual.height - expected.height }
        })
        for (const delta of Object.values(geometry)) assert.ok(Math.abs(delta) < 1, JSON.stringify(geometry))
        const visible = await page.screenshot({ animations: 'disabled' })
        await page.locator('[data-rf-highlight-overlay]').evaluate(el => { el.style.visibility = 'hidden' })
        const hidden = await page.screenshot({ animations: 'disabled' })
        assert.notDeepEqual(visible, hidden, 'highlight must change visible pixels')
        await page.locator('[data-rf-highlight-overlay]').evaluate(el => { el.style.visibility = '' })
    }
})
