import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

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
