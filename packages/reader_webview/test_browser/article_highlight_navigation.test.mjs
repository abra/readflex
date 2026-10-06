import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'
import { READFLEX_SELECTION_CLICK_SUPPRESS_MS } from '../assets/foliate-js/src/readflex_shell_constants.js'

// Opening a saved highlight from Contents must land on it unchanged: same
// colour, same range, same DOM. Search navigation over highlighted text must
// not erase the highlight either.

const filler = prefix => Array.from({ length: 24 }, (_, i) =>
    `<p id="${prefix}-${i}" data-rf-block-id="${prefix}-${i}"><span id="${prefix}-${i}-s0" data-rf-sentence="0">Filler paragraph ${i} keeps the target away from the first screen.</span></p>`).join('')
const longBlock = Array.from({ length: 40 }, (_, i) =>
    `<span id="long-s${i}" data-rf-sentence="${i}">Sentence ${i} of the long block carries enough words to wrap. </span>`).join('')
const content = filler('head') +
    '<p id="target" data-rf-block-id="target"><span id="target-s0" data-rf-sentence="0">The power bank keeps <em>devices</em> running all day.</span></p>' +
    `<p id="long" data-rf-block-id="long">${longBlock}</p>` +
    filler('tail')

async function openArticle(t, renderer) {
    const { page, routes, articleUrl } = await createHarness(t)
    if (renderer === 'svg') await page.addInitScript(() => { window.Highlight = undefined })
    routes.set('/article-content', content)
    await page.setViewportSize({ width: 390, height: 700 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => {
        const range = (startNode, start, endNode, end) => {
            const result = document.createRange()
            result.setStart(startNode, start)
            result.setEnd(endNode, end)
            return result
        }
        const anchorFor = expected => {
            const selection = getSelection()
            selection.removeAllRanges()
            selection.addRange(expected.cloneRange())
            document.dispatchEvent(new Event('selectionchange'))
            const payload = window.getCurrentTextSelection()
            selection.removeAllRanges()
            document.dispatchEvent(new Event('selectionchange'))
            return payload
        }
        const target = document.getElementById('target-s0').firstChild
        const first = document.getElementById('long-s0').firstChild
        const second = document.getElementById('long-s1').firstChild
        // Live ranges over the fixture text itself, independent of the shell:
        // they collapse exactly when the article DOM under them is rewritten.
        const expected = {
            power: range(target, 4, target, 14),
            spanning: range(first, 11, second, 8),
        }
        const saved = Object.entries(expected).map(([id, value], index) => {
            const payload = anchorFor(value)
            return { id, text: payload.text, cfiRange: payload.cfi, color: ['#FFE600', '#00C853'][index] }
        })
        window.setArticleHighlights(saved)
        // The shell's own live range per saved highlight (CSS renderer only).
        const painted = new Map()
        if (window.Highlight && CSS.highlights) {
            for (const [name, highlight] of CSS.highlights) {
                if (!name.startsWith('readflex-article-highlight-')) continue
                const [live] = [...highlight]
                const item = saved.find(entry => entry.text === live.toString())
                if (item) painted.set(item.id, live)
            }
        }
        window.navigationProbe = {
            saved,
            expected,
            painted,
            cfi: id => saved.find(item => item.id === id).cfiRange,
            dom: () => document.getElementById('article-content').innerHTML,
            ids: () => [...document.querySelectorAll('[id]')].map(element => element.id),
            overlayShapes: () => document.querySelectorAll('[data-rf-highlight-overlay] > *').length,
            paintedText: id => painted.get(id)?.toString() ?? null,
            onScreen(id) {
                const rect = expected[id].getClientRects()[0]
                return Boolean(rect) && rect.top >= 0 && rect.bottom <= innerHeight
            },
        }
    })
    return page
}

for (const renderer of ['css', 'svg']) {
    test(`opening a saved article highlight keeps its range, colour and the DOM (${renderer})`, async t => {
        const page = await openArticle(t, renderer)
        const before = await page.evaluate(() => ({
            dom: window.navigationProbe.dom(),
            overlay: window.navigationProbe.overlayShapes(),
            rules: document.head.textContent,
        }))
        for (const id of ['power', 'spanning', 'power']) {
            const after = await page.evaluate(async id => {
                const probe = window.navigationProbe
                window.goToCfi(probe.cfi(id))
                await new Promise(requestAnimationFrame)
                return {
                    dom: probe.dom(),
                    marks: document.querySelectorAll('mark').length,
                    activeClass: document.querySelectorAll('.readflex-search-active').length,
                    searchActive: Boolean(window.Highlight && CSS.highlights?.has('readflex-search-active')),
                    painted: probe.saved.map(item => [probe.paintedText(item.id), item.text]),
                    onScreen: probe.onScreen(id),
                }
            }, id)
            assert.equal(after.dom, before.dom, `opening ${id} must not rewrite the article`)
            assert.equal(after.marks, 0)
            assert.equal(after.activeClass, 0, 'a saved highlight is not a search hit')
            assert.equal(after.searchActive, false)
            if (renderer === 'css') {
                for (const [painted, text] of after.painted) assert.equal(painted, text)
            }
            assert.equal(after.onScreen, true, `${id} must be on screen after opening it`)
        }
        const after = await page.evaluate(() => ({
            overlay: window.navigationProbe.overlayShapes(),
            rules: document.head.textContent,
        }))
        assert.equal(after.overlay, before.overlay, 'every saved highlight is still painted')
        assert.equal(after.rules, before.rules, 'highlight colours are unchanged')
    })

    test(`search navigation over highlighted text keeps the saved highlight (${renderer})`, async t => {
        const page = await openArticle(t, renderer)
        const dom = await page.evaluate(() => window.navigationProbe.dom())
        await page.evaluate(() => window.startSearch(7, 'bank'))
        await page.waitForFunction(() => window.bridgeCalls.some(([name, data]) =>
            name === 'onSearch' && data.requestId === 7 && data.type === 'done'))
        const result = await page.evaluate(async () => {
            const items = window.bridgeCalls
                .filter(([name, data]) => name === 'onSearch' && data.requestId === 7 && data.type === 'results')
                .flatMap(([, data]) => data.items)
            const probe = window.navigationProbe
            window.goToSearchResult(items[0].cfi)
            await new Promise(requestAnimationFrame)
            const during = {
                dom: probe.dom(),
                painted: probe.paintedText('power'),
                active: window.Highlight && CSS.highlights
                    ? [...(CSS.highlights.get('readflex-search-active') ?? [])].map(range => range.toString())
                    : null,
                expected: probe.expected.power.toString(),
            }
            window.clearSearch()
            return {
                count: items.length,
                during,
                after: { dom: probe.dom(), painted: probe.paintedText('power') },
            }
        })
        assert.equal(result.count, 1)
        assert.equal(result.during.dom, dom, 'the active search match must not rewrite the article')
        assert.equal(result.during.expected, 'power bank')
        assert.equal(result.after.dom, dom)
        if (renderer === 'css') {
            assert.deepEqual(result.during.active, ['bank'])
            assert.equal(result.during.painted, 'power bank')
            assert.equal(result.after.painted, 'power bank')
        }
    })
}

test('a saved article highlight stays tappable after it was opened from Contents', async t => {
    const page = await openArticle(t, 'css')
    // Fixture setup cleared a selection; the shell ignores the tap that
    // dismisses one.
    await page.waitForTimeout(READFLEX_SELECTION_CLICK_SUPPRESS_MS + 50)
    const tapped = await page.evaluate(async () => {
        const probe = window.navigationProbe
        window.goToCfi(probe.cfi('power'))
        await new Promise(requestAnimationFrame)
        const rect = probe.expected.power.getClientRects()[0]
        window.bridgeCalls.length = 0
        const x = rect.left + rect.width / 2
        const y = rect.top + rect.height / 2
        document.elementFromPoint(x, y)
            .dispatchEvent(new MouseEvent('click', { bubbles: true, clientX: x, clientY: y }))
        return window.bridgeCalls
            .filter(([name]) => name === 'onAnnotationClick')
            .map(([, data]) => data.annotation.id)
    })
    assert.deepEqual(tapped, ['power'])
})

test('opening a highlight that spans sentences keeps element ids unique', async t => {
    const page = await openArticle(t, 'css')
    const ids = await page.evaluate(() => {
        window.goToCfi(window.navigationProbe.cfi('spanning'))
        return window.navigationProbe.ids()
    })
    assert.equal(new Set(ids).size, ids.length, 'opening a highlight must not clone sentence elements')
})
