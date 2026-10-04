import assert from 'node:assert/strict'
import test from 'node:test'

import { search, searchMatcher } from '../assets/foliate-js/src/search.js'

const find = (parts, query, options = {}) => [...search(parts, query, options)]

test('matcher uses the default locale unless the document declares one', () => {
    const walker = (doc, visit) => visit(['I'], (...bounds) => bounds)
    const matcher = searchMatcher(walker, { defaultLocale: 'tr' })
    assert.equal([...matcher({ body: {}, documentElement: {} }, '\u0131')].length, 1)
    assert.equal([...matcher({ body: { lang: 'en' }, documentElement: {} }, '\u0131')].length, 0)
})

test('normalization reuses repeated Unicode spans without losing matches', () => {
    const original = String.prototype.toLocaleLowerCase
    let calls = 0
    String.prototype.toLocaleLowerCase = function (...args) {
        calls++
        return original.apply(this, args)
    }
    try {
        const text = '\u041a\u041d\u0418\u0413\u0410 '.repeat(5000)
        const results = find([text], '\u043a\u043d\u0438\u0433\u0430')
        assert.equal(results.length, 5000)
        assert.equal(results.at(-1).range.endOffset, text.length - 1)
        assert.ok(calls < 100, `Repeated letters must reuse normalization, got ${calls} calls`)
    } finally {
        String.prototype.toLocaleLowerCase = original
    }
})

test('bounded excerpts preserve the original whitespace and truncation contract', () => {
    const contexts = ['', ' ', 'x'.repeat(49), 'x'.repeat(50), 'x'.repeat(51),
        ' \n\t'.repeat(200), ' word \n\t'.repeat(200)]
    for (const before of contexts) for (const after of contexts) {
        const [result] = find([`${before}needle${after}`], 'needle')
        const pre = before.replace(/\s+/g, ' ').trimStart()
        const post = after.replace(/\s+/g, ' ').trimEnd()
        assert.deepEqual(result.excerpt, {
            pre: `${pre.length < 50 ? '' : '…'}${pre.slice(-50)}`,
            match: 'needle',
            post: `${post.slice(0, 50)}${post.length < 50 ? '' : '…'}`,
        })
    }
})

test('Unicode normalization preserves original positions for every inline split', () => {
    const cases = [
        ['\u0130stanbul power', 'power', 'base', 9, 14],
        ['\u0130stanbul power', 'power', 'accent', 9, 14],
        ['pre cafe\u0301 end', 'caf\u00e9', 'accent', 4, 9],
        ['pre caf\u00e9', 'cafe', 'base', 4, 8],
        ['pre cafe\u0301', 'cafe', 'base', 4, 9],
        ['\u0130', 'i', 'base', 0, 1],
    ]
    for (const [text, query, sensitivity, start, end] of cases) {
        for (let split = 0; split <= text.length; split++) {
            assertMatches([text.slice(0, split), '', text.slice(split)], query,
                [{ start, end, text: text.slice(start, end) }], { sensitivity })
        }
    }
})

test('substring options distinguish case and accents independently', () => {
    assertMatches(['Power power'], 'power', [{ start: 6, end: 11, text: 'power' }],
        { sensitivity: 'case' })
    assertMatches(['Caf\u00e9 cafe'], 'cafe', [{ start: 5, end: 9, text: 'cafe' }],
        { sensitivity: 'case' })
    assertMatches(['caf\u00e9 cafe'], 'cafe', [{ start: 5, end: 9, text: 'cafe' }],
        { sensitivity: 'accent' })
    assertMatches(['\u039f\u03a3'], '\u03bf\u03c2',
        [{ start: 0, end: 2, text: '\u039f\u03a3' }])
    assertMatches(['I\u0130'], '\u0131', [{ start: 0, end: 1, text: 'I' }],
        { locales: 'tr' })
    assertMatches(['word'], '\u0301', [], { sensitivity: 'base' })
})

function assertMatches(parts, query, expected, options = {}) {
    const results = find(parts, query, options)
    const text = parts.join('')
    const offsets = []
    let length = 0
    for (const part of parts) {
        offsets.push(length)
        length += part.length
    }
    assert.deepEqual(results.map(({ range, excerpt }) => {
        const { startIndex, startOffset, endIndex, endOffset } = range
        assert.ok(startIndex >= 0 && startIndex < parts.length)
        assert.ok(endIndex >= startIndex && endIndex < parts.length)
        assert.ok(startOffset >= 0 && startOffset <= parts[startIndex].length)
        assert.ok(endOffset >= 0 && endOffset <= parts[endIndex].length)
        const start = offsets[startIndex] + startOffset
        const end = offsets[endIndex] + endOffset
        assert.ok(end > start)
        assert.equal(excerpt.match, text.slice(start, end))
        return { start, end, text: excerpt.match }
    }), expected)
    return results
}

test('substring search includes matches ending at the final character', () => {
    const results = assertMatches(['last word'], 'word', [
        { start: 5, end: 9, text: 'word' },
    ])
    assert.deepEqual(results[0].range, {
        startIndex: 0, startOffset: 5, endIndex: 0, endOffset: 9,
    })
    assert.deepEqual(results[0].excerpt, { pre: 'last ', match: 'word', post: '' })
})

test('substring boundaries skip empty nodes without advancing past the document', () => {
    const results = assertMatches(['', 'last ', '', 'word', '', ''], 'word', [
        { start: 5, end: 9, text: 'word' },
    ])
    assert.deepEqual(results[0].range, {
        startIndex: 3, startOffset: 0, endIndex: 3, endOffset: 4,
    })
})

test('excerpts retain all text between their start and end nodes', () => {
    assertMatches(['say hel', 'lo', ' world'], 'hello', [
        { start: 4, end: 9, text: 'hello' },
    ])
    assertMatches(['prefix ab', 'cd', 'ef suffix'], 'bcde', [
        { start: 8, end: 12, text: 'bcde' },
    ])
    assertMatches(['pre ', 'hel', '', 'lo'], 'hello', [
        { start: 4, end: 9, text: 'hello' },
    ])
})

test('identical strings in different nodes are not treated as a single node', () => {
    assertMatches(['ab', 'ab'], 'baba', [])
    assertMatches(['ab', 'ab'], 'bab', [{ start: 1, end: 4, text: 'bab' }])
    assertMatches(['same', 'same'], 'same', [
        { start: 0, end: 4, text: 'same' },
        { start: 4, end: 8, text: 'same' },
    ])
})

test('overlapping matches keep independent start and end positions', () => {
    assertMatches(['ab', 'aba tail'], 'aba', [
        { start: 0, end: 3, text: 'aba' },
        { start: 2, end: 5, text: 'aba' },
    ])
    assertMatches(['a', 'a', 'a', 'a'], 'aa', [
        { start: 0, end: 2, text: 'aa' },
        { start: 1, end: 3, text: 'aa' },
        { start: 2, end: 4, text: 'aa' },
    ])
})

test('empty input and absent matches produce no results', () => {
    for (const granularity of ['grapheme', 'word']) {
        for (const parts of [[], [''], ['', ''], ['some text']]) {
            assert.deepEqual(find(parts, '', { granularity }), [])
            assert.deepEqual(find(parts, 'absent', { granularity }), [])
        }
    }
})

test('substring offsets use UTF-16 positions and excerpts preserve original case', () => {
    assertMatches(['\u{1f4d6} ', '\u041a\u041d\u0418', '\u0413\u0410'], '\u043a\u043d\u0438\u0433\u0430', [
        { start: 3, end: 8, text: '\u041a\u041d\u0418\u0413\u0410' },
    ], { locales: 'ru' })
    assertMatches(['x ', '\u{10400}', ' end'], '\u{10428}', [
        { start: 2, end: 4, text: '\u{10400}' },
    ])
    assertMatches(['pre ', 'e\u0301'], 'e\u0301', [
        { start: 4, end: 6, text: 'e\u0301' },
    ], { sensitivity: 'accent' })
    assertMatches(['WORD ', 'word'], 'word', [
        { start: 5, end: 9, text: 'word' },
    ], { sensitivity: 'variant' })
})

test('whole-word search retains complete cross-node phrase excerpts', () => {
    assertMatches(['before alpha ', 'beta', ' gamma'], 'alpha beta gamma', [
        { start: 7, end: 23, text: 'alpha beta gamma' },
    ], { granularity: 'word' })
    assertMatches(['last ', 'word'], 'word', [
        { start: 5, end: 9, text: 'word' },
    ], { granularity: 'word' })
})

test('substring results do not depend on how inline text is partitioned', () => {
    const fixtures = [
        { text: 'abababa', query: 'aba', starts: [0, 2, 4] },
        { text: 'word word', query: 'word', starts: [0, 5] },
        { text: 'prefix terminal', query: 'terminal', starts: [7] },
        { text: 'entire', query: 'entire', starts: [0] },
        { text: '\u{1f4d6}abcabc', query: 'abc', starts: [2, 5] },
    ]
    for (const { text, query, starts } of fixtures) {
        const expected = starts.map(start => ({ start, end: start + query.length, text: query }))
        for (let first = 0; first <= text.length; first++) {
            for (let second = first; second <= text.length; second++) {
                assertMatches([
                    '', text.slice(0, first), '', text.slice(first, second),
                    text.slice(second), '',
                ], query, expected)
            }
        }
    }
})
