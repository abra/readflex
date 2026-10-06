import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

async function openArticle(t) {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', Array.from({ length: 60 }, (_, i) =>
        `<p id="p${i}">Paragraph ${i} contains text for search and scrolling.</p>`).join(''))
    await page.setViewportSize({ width: 390, height: 700 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => document.fonts.ready)
    return page
}

async function expectProgress(page, value) {
    await page.waitForFunction(value => Math.abs(
        scrollY / (document.documentElement.scrollHeight - innerHeight) - value,
    ) < 0.001, value)
}

test('article return waits for the native viewport instead of restoring against its old size', async t => {
    const page = await openArticle(t)
    for (const progress of [0.35, 0, 1]) {
        await page.setViewportSize({ width: 390, height: 700 })
        await page.evaluate(() => window.goToPercent(0.7))
        await expectProgress(page, 0.7)
        await page.evaluate(progress => window.restoreReadingProgress({ progress, viewportHeight: 844 }), progress)
        assert.equal(await page.evaluate(() => innerHeight), 700)
        await expectProgress(page, 0.7)
        await page.setViewportSize({ width: 390, height: 844 })
        await expectProgress(page, progress)
    }
})

test('article return is immediate when the native viewport is already laid out', async t => {
    const page = await openArticle(t)
    await page.evaluate(() => window.restoreReadingProgress({ progress: 0.4, viewportHeight: 700 }))
    await expectProgress(page, 0.4)
})

for (const interruption of ['navigation', 'gesture']) {
    test(`article return cannot override a newer ${interruption}`, async t => {
        const page = await openArticle(t)
        await page.evaluate(interruption => {
            window.restoreReadingProgress({ progress: 0.1, viewportHeight: 844 })
            if (interruption === 'gesture') document.dispatchEvent(new Event('touchstart'))
            else window.goToPercent(0.6)
        }, interruption)
        await page.setViewportSize({ width: 390, height: 844 })
        // Wait past the bounded fallback as well as the resize callback.
        await page.waitForTimeout(1200)
        const fraction = await page.evaluate(() => scrollY / (document.documentElement.scrollHeight - innerHeight))
        assert.ok(Math.abs(fraction - 0.1) > 0.01)
    })
}

test('article return remains usable if a resize notification never arrives', async t => {
    const page = await openArticle(t)
    await page.evaluate(() => window.restoreReadingProgress({ progress: 0.4, viewportHeight: 844 }))
    await expectProgress(page, 0.4)
})

test('article navigation paints the exact repeated occurrence without rewriting the text', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', '<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">One vision, another <em>vision</em>, a third vision and the final vision.</span></p>')
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    const dom = await page.evaluate(() => document.getElementById('article-content').innerHTML)
    await page.evaluate(() => window.startSearch(42, 'vision'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name, data]) =>
        name === 'onSearch' && data.requestId === 42 && data.type === 'done'))
    const results = await page.evaluate(() => window.bridgeCalls
        .filter(([name, data]) => name === 'onSearch' && data.requestId === 42 && data.type === 'results')
        .flatMap(([, data]) => data.items))
    assert.equal(results.length, 4)
    for (const index of [0, 1, 2, 3, 2, 0]) {
        const actual = await page.evaluate(cfi => {
            window.goToSearchResult(cfi)
            const active = [...(CSS.highlights.get('readflex-search-active') ?? [])]
            const [range] = active
            const prefix = document.createRange()
            prefix.selectNodeContents(document.getElementById('block-0-s0'))
            prefix.setEnd(range.startContainer, range.startOffset)
            return {
                count: active.length,
                inactive: CSS.highlights.get('readflex-search-matches')?.size ?? 0,
                text: range.toString(),
                prefix: prefix.toString(),
                marks: document.querySelectorAll('mark').length,
                dom: document.getElementById('article-content').innerHTML,
            }
        }, results[index].cfi)
        assert.equal(actual.count, 1)
        assert.equal(actual.inactive, 3, 'the active match is not tinted twice')
        assert.equal(actual.text, 'vision')
        assert.equal((actual.prefix.match(/vision/g) ?? []).length, index)
        assert.equal(actual.marks, 0)
        assert.equal(actual.dom, dom, 'search navigation must not rewrite the article')
    }
    const activeRule = await page.evaluate(() => [...document.styleSheets]
        .flatMap(sheet => [...sheet.cssRules]).map(rule => rule.cssText)
        .find(text => text.includes('::highlight(readflex-search-active)')))
    assert.ok(activeRule.includes('rgba(255, 179, 0, 0.36)'), activeRule)
    await page.evaluate(() => window.clearSearch())
    assert.deepEqual(await page.evaluate(() => ({
        active: CSS.highlights.has('readflex-search-active'),
        inactive: CSS.highlights.has('readflex-search-matches'),
        dom: document.getElementById('article-content').innerHTML,
    })), { active: false, inactive: false, dom })
})
