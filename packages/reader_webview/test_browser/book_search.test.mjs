import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

test('cancelled chapter load cannot publish or draw stale search results', async t => {
    const { page, origin } = await createHarness(t)
    await openEpub(page, origin, '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Search</title></head><body><p>vision vision</p></body></html>')
    const result = await page.evaluate(async () => {
        const view = window.testView
        const section = view.book.sections[0]
        const createDocument = section.createDocument.bind(section)
        let release
        let entered
        const started = new Promise(resolve => { entered = resolve })
        section.createDocument = async () => {
            entered()
            await new Promise(resolve => { release = resolve })
            return createDocument()
        }
        const results = []
        const search = (async () => {
            for await (const item of view.search({ query: 'vision' })) results.push(item)
        })()
        await started
        view.clearSearch()
        release()
        await search
        return { results, annotations: view.renderer.getContents().flatMap(({ overlayer }) =>
            [...overlayer.element.querySelectorAll('[data-search-active]')]).length }
    })
    assert.deepEqual(result.results, [])
    assert.equal(result.annotations, 0)
})

test('large chapter search delivers bounded batches without losing matches', async t => {
    const { page, origin } = await createHarness(t)
    await openEpub(page, origin, `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Search</title></head><body><p>${'vision '.repeat(257)}</p></body></html>`)
    const result = await page.evaluate(async () => {
        const batches = []
        for await (const item of window.testView.search({ query: 'vision' })) {
            if (item.subitems) batches.push(item.subitems.length)
        }
        window.testView.clearSearch()
        return batches
    })
    assert.equal(result.reduce((sum, count) => sum + count, 0), 257)
    assert.ok(result.every(count => count <= 64))
})

test('search matcher returns complete DOM ranges and excerpts across inline markup', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    const results = await page.evaluate(async () => {
        const { searchMatcher } = await import('/foliate-js/src/search.js')
        const { textWalker } = await import('/foliate-js/src/text-walker.js')
        const fixtures = [
            { html: '<p>last <em>word</em></p>', query: 'word', expected: ['word'] },
            { html: '<p>say hel<em>lo</em> world</p>', query: 'hello', expected: ['hello'] },
            { html: '<p><em>ab</em><strong>ab</strong></p>', query: 'bab', expected: ['bab'] },
            { html: '<p>a<em>a</em>a<strong>a</strong></p>', query: 'aa', expected: ['aa', 'aa', 'aa'] },
            { html: '<p>before alpha <em>beta</em> gamma</p>', query: 'alpha beta gamma',
                matchWholeWords: true, expected: ['alpha beta gamma'] },
            { html: '<p></p>', query: 'word', expected: [] },
        ]
        return fixtures.map(({ html, query, expected, matchWholeWords = false }) => {
            const doc = new DOMParser().parseFromString(html, 'text/html')
            const matcher = searchMatcher(textWalker, { matchWholeWords })
            return { expected, results: [...matcher(doc, query)].map(({ range, excerpt }) => ({
                range: range.toString(), excerpt: excerpt.match,
            })) }
        })
    })
    for (const { expected, results: matches } of results) {
        assert.deepEqual(matches, expected.map(text => ({ range: text, excerpt: text })))
    }
})

test('EPUB search finishes and its CFIs restore complete matches at chapter boundaries', async t => {
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    await openEpub(page, origin, '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Search</title></head><body><p>say hel<em>lo</em> world</p><p>before alpha <strong>beta</strong> gamma</p><p>last word</p></body></html>')
    for (const { query, matchWholeWords, expected } of [
        { query: 'hello', matchWholeWords: false, expected: ['hello'] },
        { query: 'word', matchWholeWords: false, expected: ['word'] },
        { query: 'alpha beta gamma', matchWholeWords: true, expected: ['alpha beta gamma'] },
        { query: 'word', matchWholeWords: true, expected: ['word'] },
    ]) {
        const result = await page.evaluate(async ({ query, matchWholeWords }) => {
            const view = window.testView
            const matches = []
            let done = false
            for await (const result of view.search({ query, matchWholeWords })) {
                if (result === 'done') done = true
                else if (result.subitems) {
                    for (const { cfi, excerpt } of result.subitems) {
                        const { index, anchor } = view.resolveCFI(cfi)
                        const doc = view.renderer.getContents().find(content => content.index === index).doc
                        matches.push({ text: anchor(doc).toString(), excerpt: excerpt.match })
                    }
                }
            }
            view.clearSearch()
            return { done, matches }
        }, { query, matchWholeWords })
        assert.equal(result.done, true)
        assert.deepEqual(result.matches, expected.map(text => ({ text, excerpt: text })))
    }
    assert.deepEqual(errors, [])
})

async function openRepeatedMatches(t, { dark = false, flow = 'paginated' } = {}) {
    const { page, origin } = await createHarness(t)
    await openEpub(page, origin, `<html xmlns="http://www.w3.org/1999/xhtml"><head>
        <style>body { color: ${dark ? '#eee' : '#222'}; background: ${dark ? '#181818' : '#fff'}; }
        p { font: 22px/1.6 serif; }</style></head><body>
        <p>One vision, another <em>vision</em>, a third vision and the final vision.</p>
        </body></html>`)
    const cfis = await page.evaluate(async flow => {
        const view = window.testView
        view.renderer.setAttribute('flow', flow)
        view.renderer.setAttribute('gap', '8%')
        view.renderer.setAttribute('top-margin', '24px')
        view.renderer.setAttribute('bottom-margin', '24px')
        view.renderer.setAttribute('max-column-count', '1')
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        const cfis = []
        for await (const result of view.search({ query: 'vision' })) {
            for (const item of result.subitems ?? []) cfis.push(item.cfi)
        }
        return cfis
    }, flow)
    assert.equal(cfis.length, 4)
    return { page, cfis }
}

async function expectActiveMatch(page, cfi) {
    const snapshot = await page.evaluate(cfi => {
        const view = window.testView
        const { index, anchor } = view.resolveCFI(cfi)
        const { doc, overlayer } = view.renderer.getContents().find(item => item.index === index)
        const active = [...overlayer.element.querySelectorAll('[data-search-active="true"]')]
        const inactive = [...overlayer.element.querySelectorAll('[data-search-active="false"]')]
        const rect = anchor(doc).getClientRects()[0]
        const fill = active[0]?.querySelector('rect')
        const bounds = active[0]?.getBoundingClientRect()
        const viewport = view.getBoundingClientRect()
        return {
            active: active.length,
            inactive: inactive.length,
            text: anchor(doc).toString(),
            offset: fill ? Math.abs(Number(fill.getAttribute('x')) - (rect.left - 1)) : null,
            stroke: fill ? getComputedStyle(fill).stroke : null,
            outlines: active[0]?.querySelectorAll('[stroke]').length ?? 0,
            activeColor: fill ? getComputedStyle(fill).fill : null,
            inactiveColor: inactive[0] ? getComputedStyle(inactive[0]).fill : null,
            activeOpacity: Number(active[0]?.style.opacity),
            inactiveOpacity: Number(inactive[0]?.style.opacity),
            selected: doc.defaultView.getSelection().toString(),
            visible: bounds && bounds.left < viewport.right && bounds.right > viewport.left
                && bounds.top < viewport.bottom && bounds.bottom > viewport.top,
        }
    }, cfi)
    assert.equal(snapshot.active, 1, 'Exactly one match must have active feedback')
    assert.equal(snapshot.inactive, 3)
    assert.equal(snapshot.text, 'vision')
    assert.ok(snapshot.offset < 0.1, 'Active feedback must follow the exact occurrence, not the first word')
    assert.equal(snapshot.stroke, 'none', 'Active feedback must be a fill, not an outline')
    assert.equal(snapshot.outlines, 0)
    assert.equal(snapshot.activeColor, 'rgb(255, 179, 0)')
    assert.equal(snapshot.inactiveColor, 'rgb(0, 212, 216)')
    assert.ok(snapshot.activeOpacity > snapshot.inactiveOpacity)
    assert.equal(snapshot.selected, '', 'Search must not take ownership of native text selection')
    assert.equal(snapshot.visible, true, 'The active marker must be visible in the reader viewport')
}

for (const dark of [false, true]) {
    for (const flow of ['paginated', 'scrolled']) {
        test(`EPUB active match moves between repeated words dark=${dark} flow=${flow}`, async t => {
            const { page, cfis } = await openRepeatedMatches(t, { dark, flow })
            for (const index of [0, 1, 2, 3, 2, 1, 0]) {
                assert.equal(await page.evaluate(cfi => window.testView.goToSearchResult(cfi), cfis[index]), true)
                await expectActiveMatch(page, cfis[index])
            }
            await page.evaluate(() => {
                const view = window.testView
                view.style.width = '390px'
                for (const { overlayer } of view.renderer.getContents()) overlayer.redraw()
            })
            await page.waitForTimeout(150)
            await expectActiveMatch(page, cfis[0])
            await page.evaluate(() => window.testView.clearSearch())
            assert.equal(await page.evaluate(() => window.testView.renderer.getContents()
                .flatMap(({ overlayer }) => [...overlayer.element.querySelectorAll('[data-search-active]')]).length), 0)
        })
    }
}

test('EPUB stale navigation cannot restore the active match after a newer result or clear', async t => {
    const { page, cfis } = await openRepeatedMatches(t)
    await page.evaluate(async cfis => {
        const view = window.testView
        const goTo = view.goTo.bind(view)
        let release
        const pending = new Promise(resolve => { release = resolve })
        view.goTo = async cfi => cfi === cfis[0] ? pending : goTo(cfi)
        const older = view.goToSearchResult(cfis[0])
        await view.goToSearchResult(cfis[2])
        release(view.resolveCFI(cfis[0]))
        await older
        view.goTo = goTo
    }, cfis)
    await expectActiveMatch(page, cfis[2])
    const activeAfterClear = await page.evaluate(async cfi => {
        const view = window.testView
        const goTo = view.goTo.bind(view)
        let release
        view.goTo = () => new Promise(resolve => { release = resolve })
        const pending = view.goToSearchResult(cfi)
        view.clearSearch()
        release(view.resolveCFI(cfi))
        await pending
        view.goTo = goTo
        return view.renderer.getContents().flatMap(({ overlayer }) =>
            [...overlayer.element.querySelectorAll('[data-search-active]')]).length
    }, cfis[1])
    assert.equal(activeAfterClear, 0)
})

test('changing the active EPUB match repaints only two results and preserves saved highlights', async t => {
    const { page, cfis } = await openRepeatedMatches(t)
    const result = await page.evaluate(async cfis => {
        const view = window.testView
        const { Overlayer } = await import('/foliate-js/src/overlayer.js')
        view.addEventListener('draw-annotation', ({ detail }) =>
            detail.draw(Overlayer.highlight, { color: '#ffeb3b' }))
        await view.addAnnotation({ value: 'saved-highlight', cfi: cfis[0] })
        await view.goToSearchResult(cfis[0])
        const { doc, overlayer } = view.renderer.getContents()[0]
        const saved = overlayer.element.querySelector('g[fill="#ffeb3b"]')
        const text = doc.body.textContent
        const mutations = []
        const observer = new MutationObserver(records => mutations.push(...records))
        observer.observe(overlayer.element, { childList: true })
        await view.goToSearchResult(cfis[1])
        mutations.push(...observer.takeRecords())
        observer.disconnect()
        view.clearSearch()
        await Promise.resolve()
        return {
            added: mutations.reduce((count, record) => count + record.addedNodes.length, 0),
            removed: mutations.reduce((count, record) => count + record.removedNodes.length, 0),
            savedIntact: saved === overlayer.element.firstElementChild && overlayer.element.children.length === 1,
            textIntact: doc.body.textContent === text,
        }
    }, cfis)
    assert.deepEqual(result, { added: 2, removed: 2, savedIntact: true, textIntact: true })
})
