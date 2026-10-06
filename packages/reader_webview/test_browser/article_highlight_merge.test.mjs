import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'
import {
    ACTIVE_SEARCH_HIGHLIGHT_COLOR,
    READFLEX_SELECTION_CLICK_SUPPRESS_MS,
} from '../assets/foliate-js/src/readflex_shell_constants.js'

// Saving a selection that shares text with saved highlights stores one
// highlight over their union. These tests check the plan the shell reports
// and that its anchor restores exactly the merged text.

const content = '<p id="block-0" data-rf-block-id="block-0">' +
    '<span id="block-0-s0" data-rf-sentence="0">The power bank keeps <em>devices</em> running. </span>' +
    '<span id="block-0-s1" data-rf-sentence="1">A second sentence follows here.</span></p>' +
    '<p id="block-1" data-rf-block-id="block-1"><span id="block-1-s0" data-rf-sentence="0">Another paragraph stays apart.</span></p>'

async function openArticle(t, renderer = 'css') {
    const { page, routes, articleUrl } = await createHarness(t)
    if (renderer === 'svg') await page.addInitScript(() => { window.Highlight = undefined })
    routes.set('/article-content', content)
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => {
        // Locate `text` in the article's concatenated text nodes.
        const rangeFor = (text, from = 0) => {
            const walker = document.createTreeWalker(document.getElementById('article-content'), NodeFilter.SHOW_TEXT)
            const nodes = []
            let full = ''
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
                nodes.push({ node, start: full.length })
                full += node.data
            }
            const start = full.indexOf(text, from)
            if (start < 0) throw new Error(`Missing fixture text: ${text}`)
            const end = start + text.length
            const first = nodes.findLast(entry => entry.start <= start)
            const last = nodes.find(entry => end > entry.start && end <= entry.start + entry.node.length)
            const range = document.createRange()
            range.setStart(first.node, start - first.start)
            range.setEnd(last.node, end - last.start)
            return range
        }
        const select = text => {
            const selection = getSelection()
            selection.removeAllRanges()
            selection.addRange(rangeFor(text))
            document.dispatchEvent(new Event('selectionchange'))
            const payload = window.getCurrentTextSelection()
            selection.removeAllRanges()
            document.dispatchEvent(new Event('selectionchange'))
            return payload
        }
        const save = list => window.setArticleHighlights(list.map(([id, text]) => ({
            id, text: select(text).text, cfiRange: select(text).cfi, color: '#FFE600',
        })))
        // Text a saved anchor restores to, read back through the shell itself.
        const restored = cfiRange => {
            window.setArticleHighlights([{ id: 'probe', text: '', cfiRange, color: '#FFE600' }])
            const highlight = window.Highlight && CSS.highlights
                ? [...CSS.highlights.entries()].find(([name]) => name.startsWith('readflex-article-highlight-'))
                : null
            return highlight ? [...highlight[1]][0].toString() : null
        }
        window.mergeProbe = { rangeFor, select, save, restored }
    })
    return page
}

test('a partial overlap across an inline element restores exactly the merged text', async t => {
    const page = await openArticle(t)
    const result = await page.evaluate(() => {
        const probe = window.mergeProbe
        probe.save([['phrase', 'power bank keeps devices']])
        const merge = probe.select('devices running').highlightMerge
        return { merge, restored: probe.restored(merge.cfi) }
    })
    assert.deepEqual(result.merge.highlightIds, ['phrase'])
    assert.equal(result.merge.text, 'power bank keeps devices running')
    assert.equal(result.restored, 'power bank keeps devices running')
})

test('a merge across sentences anchors the union to their block', async t => {
    const page = await openArticle(t)
    const result = await page.evaluate(() => {
        const probe = window.mergeProbe
        probe.save([['tail', 'running. A second']])
        const merge = probe.select('second sentence').highlightMerge
        return { merge, restored: probe.restored(merge.cfi) }
    })
    assert.deepEqual(result.merge.highlightIds, ['tail'])
    assert.equal(result.merge.text, 'running. A second sentence')
    assert.equal(result.restored, 'running. A second sentence')
})

test('a chain of legacy overlaps is absorbed whole, in document order', async t => {
    const page = await openArticle(t)
    const result = await page.evaluate(() => {
        const probe = window.mergeProbe
        // Overlapping twins saved before merging existed; the newest first,
        // as the repository lists them.
        probe.save([['newer', 'bank keeps'], ['older', 'power bank']])
        const merge = probe.select('keeps devices').highlightMerge
        return { merge, restored: probe.restored(merge.cfi) }
    })
    assert.deepEqual(result.merge.highlightIds, ['older', 'newer'])
    assert.equal(result.merge.text, 'power bank keeps devices')
    assert.equal(result.restored, 'power bank keeps devices')
})

test('highlights in other paragraphs are never absorbed', async t => {
    const page = await openArticle(t)
    const merge = await page.evaluate(() => {
        const probe = window.mergeProbe
        probe.save([['phrase', 'power bank'], ['apart', 'Another paragraph']])
        return probe.select('The power').highlightMerge
    })
    assert.deepEqual(merge.highlightIds, ['phrase'])
})

for (const renderer of ['css', 'svg']) {
    test(`the merge plan does not depend on the renderer (${renderer})`, async t => {
        const page = await openArticle(t, renderer)
        const merge = await page.evaluate(() => {
            const probe = window.mergeProbe
            probe.save([['phrase', 'power bank'], ['word', 'devices']])
            return probe.select('bank keeps devi').highlightMerge
        })
        assert.deepEqual(merge.highlightIds, ['phrase', 'word'])
        assert.equal(merge.text, 'power bank keeps devices')
    })
}

// Paint order is explicit: `Highlight.priority` on the CSS path (WebKit's
// registry does not iterate in insertion order) and child order in the SVG
// fallback. Distinct fills identify each group in the overlay.
const paintOrder = () => {
    const css = window.Highlight && CSS.highlights
    if (css) {
        return [...CSS.highlights.entries()]
            .map(([name, highlight]) => ({ name, priority: highlight.priority, text: [...highlight][0].toString() }))
            .sort((a, b) => a.priority - b.priority)
            .map(({ name, text }) => name.startsWith('readflex-article-highlight-') ? text : name)
    }
    const labels = { '#FFE600': 'power bank', '#00C853': 'bank keeps' }
    const order = []
    for (const g of document.querySelector('[data-rf-highlight-overlay]').children) {
        const label = labels[g.getAttribute('fill')] ?? g.getAttribute('fill')
        if (order.at(-1) !== label) order.push(label)
    }
    return order
}

for (const renderer of ['css', 'svg']) {
    test(`legacy overlaps paint the newest highlight on top and it answers taps (${renderer})`, async t => {
        const page = await openArticle(t, renderer)
        await page.evaluate(() => {
            // Flutter sends highlights in paint order, bottom first.
            window.setArticleHighlights([
                { id: 'older', text: 'power bank', cfiRange: window.mergeProbe.select('power bank').cfi, color: '#FFE600' },
                { id: 'newer', text: 'bank keeps', cfiRange: window.mergeProbe.select('bank keeps').cfi, color: '#00C853' },
            ])
        })
        await page.waitForTimeout(READFLEX_SELECTION_CLICK_SUPPRESS_MS + 50)
        const result = await page.evaluate(paintOrder => {
            const order = new Function(`return (${paintOrder})()`)()
            const rect = window.mergeProbe.rangeFor('bank').getClientRects()[0]
            window.bridgeCalls.length = 0
            const x = rect.left + rect.width / 2
            const y = rect.top + rect.height / 2
            document.elementFromPoint(x, y)
                .dispatchEvent(new MouseEvent('click', { bubbles: true, clientX: x, clientY: y }))
            const tapped = window.bridgeCalls
                .filter(([name]) => name === 'onAnnotationClick')
                .map(([, data]) => data.annotation.id)
            return { order, tapped }
        }, paintOrder.toString())
        assert.deepEqual(result.order, ['power bank', 'bank keeps'])
        assert.deepEqual(result.tapped, ['newer'])
    })

    test(`search tints stay above saved highlights re-rendered during a search (${renderer})`, async t => {
        const page = await openArticle(t, renderer)
        await page.evaluate(() => window.setArticleHighlights([
            { id: 'older', text: 'power bank', cfiRange: window.mergeProbe.select('power bank').cfi, color: '#FFE600' },
        ]))
        await page.evaluate(() => window.startSearch(3, 'bank'))
        await page.waitForFunction(() => window.bridgeCalls.some(([name, data]) =>
            name === 'onSearch' && data.requestId === 3 && data.type === 'done'))
        const order = await page.evaluate(paintOrder => {
            const cfi = window.bridgeCalls
                .find(([name, data]) => name === 'onSearch' && data.requestId === 3 && data.type === 'results')[1].items[0].cfi
            window.goToSearchResult(cfi)
            // An edit while searching re-renders every saved highlight.
            window.setArticleHighlights([
                { id: 'older', text: 'power bank', cfiRange: window.mergeProbe.select('power bank').cfi, color: '#FFE600' },
                { id: 'newer', text: 'bank keeps', cfiRange: window.mergeProbe.select('bank keeps').cfi, color: '#00C853' },
            ])
            return new Function(`return (${paintOrder})()`)()
        }, paintOrder.toString())
        const active = order.indexOf(renderer === 'css' ? 'readflex-search-active' : ACTIVE_SEARCH_HIGHLIGHT_COLOR)
        assert.ok(active > order.indexOf('bank keeps'), JSON.stringify(order))
        assert.ok(order.indexOf('power bank') < order.indexOf('bank keeps'), JSON.stringify(order))
    })
}
