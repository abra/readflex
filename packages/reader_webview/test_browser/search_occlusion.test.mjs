import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

const marker = '[data-readflex-search-occlusion]'
const settle = page => page.evaluate(() => new Promise(resolve =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))))

test('search occlusion projects only covered, on-screen fragments and merges horizontal spans', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    const spans = await page.evaluate(async () => {
        const { occludedSearchSpans } = await import('/foliate-js/src/readflex_search_occlusion.js')
        const rect = (left, top, right, bottom) => ({ left, top, right, bottom })
        return occludedSearchSpans([
            rect(100, 710, 150, 740), rect(120, 755, 180, 785), // two covered lines
            rect(230, 685, 260, 715), // partially covered
            rect(-10, 710, 20, 740), rect(380, 710, 420, 740), // clipped horizontally
            rect(50, 660, 100, 690), // visible above panel
            rect(60, 805, 100, 840), // below viewport, not below this panel
            rect(410, 710, 430, 740), // another column/page
            rect(NaN, 710, 50, 740), rect(20, 730, 10, 750),
        ], { width: 390, height: 800 }, 0.125)
    })
    assert.deepEqual(spans, [
        { left: 0, width: 20 }, { left: 100, width: 80 },
        { left: 230, width: 30 }, { left: 380, width: 10 },
    ])
})

test('indicator coalesces scroll work, is inert when disabled and detaches on disposal', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    await page.addStyleTag({ content: 'p:empty, span:empty, div:empty:not([class]):not([id]) { display: none !important; }' })
    const result = await page.evaluate(async () => {
        const { SearchOcclusionIndicator } = await import('/foliate-js/src/readflex_search_occlusion.js')
        let reads = 0
        const indicator = new SearchOcclusionIndicator({
            getRects: () => { reads++; return [{ left: 25, right: 75, top: innerHeight - 20, bottom: innerHeight }] },
        })
        const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        const burst = () => { for (let i = 0; i < 200; i++) window.dispatchEvent(new Event('scroll')) }
        burst(); await frame()
        const idle = reads
        indicator.setBottomInset(0.2)
        await frame()
        reads = 0
        burst(); await frame()
        const active = reads
        const element = document.querySelector('[data-readflex-search-occlusion]')
        const pointerEvents = getComputedStyle(element).pointerEvents
        const rendered = element.firstElementChild.getBoundingClientRect().width
        indicator.setBottomInset(0)
        reads = 0
        burst(); await frame()
        const disabled = reads
        indicator.setBottomInset(0.2)
        indicator.destroy()
        reads = 0
        burst(); await frame()
        return { idle, active, disabled, disposed: reads, pointerEvents, rendered,
            markers: document.querySelectorAll('[data-readflex-search-occlusion]').length }
    })
    assert.deepEqual(result, { idle: 0, active: 1, disabled: 0, disposed: 0, pointerEvents: 'none', rendered: 50, markers: 0 })
})

test('article overlay follows the exact active word without changing scroll, layout or text', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    await page.setViewportSize({ width: 390, height: 844 })
    routes.set('/article-content', Array.from({ length: 40 }, (_, i) =>
        `<p data-rf-block-id="p${i}"><span id="p${i}-s0" data-rf-sentence="0">Paragraph ${i}: an early vision and a later vision help readers understand the text.</span></p>`).join(''))
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => window.startSearch(1, 'vision'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name, event]) => name === 'onSearch' && event.type === 'done'))
    await page.evaluate(() => {
        const results = window.bridgeCalls.filter(([name, event]) => name === 'onSearch' && event.type === 'results')
            .flatMap(([, event]) => event.items)
        window.goToSearchResult(results[31].cfi)
        const rect = [...CSS.highlights.get('readflex-search-active')][0].getBoundingClientRect()
        scrollBy(0, rect.top - (innerHeight - 50))
    })
    await settle(page)
    const before = await page.evaluate(() => ({ height: innerHeight, scroll: scrollY, document: document.documentElement.scrollHeight }))
    await page.evaluate(() => window.setSearchOverlayInset(0.2))
    await page.waitForSelector(marker)
    const bounds = await page.evaluate(() => {
        const word = [...CSS.highlights.get('readflex-search-active')][0].getBoundingClientRect()
        const bar = document.querySelector('[data-readflex-search-occlusion] > rect').getBoundingClientRect()
        return { word: { left: word.left, width: word.width }, bar: { left: bar.left, width: bar.width, bottom: bar.bottom }, edge: innerHeight * 0.8 }
    })
    assert.ok(Math.abs(bounds.word.left - bounds.bar.left) < 1)
    assert.ok(Math.abs(bounds.word.width - bounds.bar.width) < 1)
    assert.ok(Math.abs(bounds.bar.bottom - bounds.edge) < 1)
    await page.evaluate(() => window.setSearchOverlayInset(0))
    await settle(page)
    assert.deepEqual(await page.evaluate(() => ({ height: innerHeight, scroll: scrollY, document: document.documentElement.scrollHeight })), before)
    assert.equal(await page.locator(marker).count(), 0)
    await page.evaluate(() => { window.setSearchOverlayInset(0.2); scrollBy(0, 300) })
    await settle(page)
    assert.equal(await page.locator(marker).count(), 0, 'Visible word needs no edge indicator')
    await page.evaluate(() => { scrollBy(0, -300) })
    await page.waitForSelector(marker)
    await page.evaluate(() => window.clearSearch())
    await settle(page)
    assert.equal(await page.locator(marker).count(), 0)
    assert.deepEqual(await page.evaluate(() => ({ height: innerHeight, scroll: scrollY, document: document.documentElement.scrollHeight })), before,
        'Ending search must reveal the covered text without moving it')
    assert.equal(await page.evaluate(() => getSelection().toString()), '')
})

for (const flow of ['paginated', 'scrolled']) {
    test(`book overlay follows search annotations without repagination (${flow})`, async t => {
        const { page, origin } = await createHarness(t)
        await page.setViewportSize({ width: 390, height: 844 })
        await openEpub(page, origin, `<html xmlns="http://www.w3.org/1999/xhtml"><head>
            <style>body{margin:0}p{font:20px/1.5 serif;margin:0}</style></head><body>
            ${Array.from({ length: 50 }, (_, i) => `<p>Paragraph ${i}: a vision of clear and readable text, with more words on the next line.</p>`).join('')}
            </body></html>`)
        await page.evaluate(async flow => {
            document.body.style.margin = '0'
            const view = window.testView
            view.style.cssText = 'display:block;width:390px;height:844px'
            view.renderer.setAttribute('flow', flow)
            view.renderer.setAttribute('gap', '8%')
            view.renderer.setAttribute('top-margin', '24px')
            view.renderer.setAttribute('bottom-margin', '24px')
            view.renderer.setAttribute('max-column-count', '1')
            await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
            window.testMatches = []
            for await (const result of view.search({ query: 'vision' }))
                for (const item of result.subitems ?? []) window.testMatches.push(item.cfi)
        }, flow)
        await settle(page)
        await page.evaluate(async flow => {
            const view = window.testView
            const container = view.renderer.shadowRoot.querySelector('#container')
            const offset = container.scrollTop
            const target = window.testMatches.find(cfi => view.renderer.getContents().some(({ overlayer }) =>
                overlayer.getClientRects('foliate-search:' + cfi).some(rect =>
                    rect.top > 844 * 0.7 && rect.bottom < 844 && rect.left >= 0 && rect.right <= 390)))
            if (!target) throw new Error('No search match in the covered viewport band')
            await view.goToSearchResult(target)
            await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
            if (flow === 'scrolled') container.scrollTop = offset
        }, flow)
        await settle(page)
        const snapshot = () => page.evaluate(() => {
            const view = window.testView
            const active = view.renderer.getContents().flatMap(({ overlayer }) =>
                [...overlayer.element.querySelectorAll('[data-search-active="true"] rect')])[0].getBoundingClientRect()
            return { width: view.clientWidth, height: view.clientHeight, page: view.renderer.page,
                pages: view.renderer.pages, left: active.left, top: active.top, widthOfWord: active.width }
        })
        const before = await snapshot()
        assert.ok(before.top > 844 * 0.7 && before.top < 844,
            `Fixture match must be under the panel: ${JSON.stringify(before)}`)
        await page.evaluate(() => window.testView.setSearchOverlayInset(0.3))
        await page.waitForSelector(marker)
        const rect = await page.locator(`${marker} > rect`).first().boundingBox()
        assert.ok(Math.abs(rect.x - before.left) < 1)
        assert.ok(Math.abs(rect.width - before.widthOfWord) < 1)
        assert.deepEqual(await snapshot(), before)
        await page.evaluate(() => window.testView.setSearchOverlayInset(0))
        await settle(page)
        assert.deepEqual(await snapshot(), before)
        assert.equal(await page.locator(marker).count(), 0)
        await page.evaluate(() => { window.testView.setSearchOverlayInset(0.3); window.testView.clearSearch() })
        await settle(page)
        assert.equal(await page.locator(marker).count(), 0)
        assert.deepEqual(await page.evaluate(() => {
            const view = window.testView
            return { width: view.clientWidth, height: view.clientHeight, page: view.renderer.page, pages: view.renderer.pages }
        }), { width: before.width, height: before.height, page: before.page, pages: before.pages })
    })
}
