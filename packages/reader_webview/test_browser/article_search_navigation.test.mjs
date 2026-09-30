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

test('article navigation marks the exact repeated occurrence and removes the old marker', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', '<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">One vision, another <em>vision</em>, a third vision and the final vision.</span></p>')
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => window.startSearch(42, 'vision'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name, data]) =>
        name === 'onSearch' && data.requestId === 42 && data.type === 'done'))
    const results = await page.evaluate(() => window.bridgeCalls
        .filter(([name, data]) => name === 'onSearch' && data.requestId === 42 && data.type === 'results')
        .flatMap(([, data]) => data.items))
    assert.equal(results.length, 4)
    for (const index of [0, 1, 2, 3, 2, 0]) {
        const actual = await page.evaluate(cfi => {
            window.goToCfi(cfi)
            const markers = document.querySelectorAll('mark.readflex-search-match')
            const marker = markers[0]
            const prefix = document.createRange()
            prefix.selectNodeContents(marker.closest('[data-rf-sentence]'))
            prefix.setEndBefore(marker)
            return {
                count: markers.length,
                text: marker.textContent,
                prefix: prefix.toString(),
                outline: getComputedStyle(marker).outlineStyle,
                shadow: getComputedStyle(marker).boxShadow,
                background: getComputedStyle(marker).backgroundColor,
            }
        }, results[index].cfi)
        assert.equal(actual.count, 1)
        assert.equal(actual.text, 'vision')
        assert.equal((actual.prefix.match(/vision/g) ?? []).length, index)
        assert.equal(actual.outline, 'none')
        assert.equal(actual.shadow, 'none')
        assert.equal(actual.background, 'rgba(255, 179, 0, 0.36)')
    }
    await page.evaluate(() => window.clearSearch())
    assert.equal(await page.locator('mark.readflex-search-match').count(), 0)
    assert.equal(await page.locator('#article-content').innerText(),
        'One vision, another vision, a third vision and the final vision.')
})
