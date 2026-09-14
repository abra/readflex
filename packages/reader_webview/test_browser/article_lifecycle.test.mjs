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

test('article selection reports only fully contained saved highlights', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', '<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">The power bank keeps devices running.</span></p>')
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(call => call[0] === 'onLoadEnd'))
    await page.evaluate(() => {
        const node = document.getElementById('block-0-s0').firstChild
        window.selectHighlightTestRange = text => {
            const start = node.data.indexOf(text)
            if (start < 0) throw new Error('Missing fixture text')
            const selection = window.getSelection()
            selection.setBaseAndExtent(node, start, node, start + text.length)
            document.dispatchEvent(new Event('selectionchange'))
            return window.getCurrentTextSelection()
        }
        const saved = [['phrase', 'power bank'], ['word', 'devices']].map(([id, text]) => ({
            id, text, cfiRange: window.selectHighlightTestRange(text).cfi, color: '#FFE600',
        }))
        window.setArticleHighlights(saved)
    })
    for (const [text, ids] of [
        ['The power bank keeps', ['phrase']],
        ['power', []],
        ['power bank', ['phrase']],
        ['The power', []],
        ['bank keeps', []],
        ['The power bank keeps devices running.', ['phrase', 'word']],
        ['running.', []],
    ]) {
        const result = await page.evaluate(text => {
            window.bridgeCalls.length = 0
            const payload = window.selectHighlightTestRange(text)
            return {
                text: payload.text, ids: payload.containedHighlightIds,
                native: window.getSelection().toString(),
                edits: window.bridgeCalls.filter(([name]) => name === 'onAnnotationClick').length,
            }
        }, text)
        assert.deepEqual(result, { text, ids, native: text, edits: 0 })
    }
})

for (const renderer of ['css', 'svg']) {
    test(`article native selection is not painted twice (${renderer} highlights)`, async t => {
        const { page, routes, articleUrl } = await createHarness(t)
        if (renderer === 'svg') await page.addInitScript(() => { window.Highlight = undefined })
        routes.set('/article-content', '<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">The power bank keeps devices running.</span></p>')
        await page.goto(articleUrl())
        await page.waitForFunction(() => window.bridgeCalls.some(call => call[0] === 'onLoadEnd'))
        await page.evaluate(() => {
            const node = document.getElementById('block-0-s0').firstChild
            const selection = window.getSelection()
            const rendered = () => window.Highlight && CSS.highlights
                ? [...CSS.highlights.values()]
                : [...document.querySelector('[data-rf-highlight-overlay]').children]
            window.articleSelectionProbe = {
                select(text, backwards = false) {
                    const start = node.data.indexOf(text), end = start + text.length
                    if (start < 0) throw new Error('Missing fixture text')
                    selection.setBaseAndExtent(node, backwards ? end : start, node, backwards ? start : end)
                    document.dispatchEvent(new Event('selectionchange'))
                    return window.getCurrentTextSelection()
                },
                state: () => ({ text: selection.toString(), anchor: selection.anchorOffset,
                    focus: selection.focusOffset, rendered: rendered().length }),
                rendered,
            }
            const saved = window.articleSelectionProbe.select('devices')
            window.setArticleHighlights([{ id: 'saved', cfiRange: saved.cfi, color: '#FFE600' }])
        })
        // Include selection across a saved highlight and backward handle movement.
        for (const [text, backwards] of [['power', false], ['power bank keeps devices', false], ['bank keeps', true]]) {
            const result = await page.evaluate(({ text, backwards }) => {
                const probe = window.articleSelectionProbe
                const payload = probe.select(text, backwards)
                const before = probe.state()
                for (const color of ['#FFE600', '#00FF00', '#FF0000']) {
                    window.showSelectionHighlightPreview({ cfiRange: payload.cfi, color })
                }
                return { before, after: probe.state() }
            }, { text, backwards })
            assert.equal(result.before.text, text)
            assert.equal(result.before.rendered, 1)
            assert.deepEqual(result.after, result.before, 'preview must not layer over or alter native selection')
        }
        const fallback = await page.evaluate(() => {
            const probe = window.articleSelectionProbe
            const payload = probe.select('power')
            window.clearSelectionAfterTextAction()
            window.showSelectionHighlightPreview({ cfiRange: payload.cfi, color: '#FF0000' })
            return probe.state()
        })
        assert.equal(fallback.text, '')
        assert.equal(fallback.rendered, 2, 'fallback preview remains available without a native range')
        const restored = await page.evaluate(() => {
            const probe = window.articleSelectionProbe
            const saved = probe.rendered()[0]
            probe.select('power')
            // Repeated bridge cleanup must not rebuild or remove persisted annotations.
            window.clearSelectionHighlightPreview()
            window.clearSelectionHighlightPreview()
            return { ...probe.state(), sameSaved: saved === probe.rendered()[0],
                content: document.getElementById('block-0-s0').textContent }
        })
        assert.deepEqual(restored, { text: 'power', anchor: 4, focus: 9, rendered: 1,
            sameSaved: true, content: 'The power bank keeps devices running.' })
    })
}

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
