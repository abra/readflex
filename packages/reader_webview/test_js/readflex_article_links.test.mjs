import test from 'node:test'
import assert from 'node:assert/strict'
import { anchorFromEvent, classifyArticleLink } from '../assets/foliate-js/src/readflex_article_links.js'

const context = {
    documentUrl: 'http://127.0.0.1:4321/r/token/assets/article-html/index.html?contentUrl=%22x%22',
    baseUrl: 'http://127.0.0.1:4321/r/token/article/dir%2Fid/',
}

test('fragment links stay in the document', () => {
    assert.deepEqual(classifyArticleLink('#section-2', context), { kind: 'fragment', hash: '#section-2' })
    assert.deepEqual(classifyArticleLink(`${context.baseUrl}#section-2`, context),
        { kind: 'fragment', hash: '#section-2' })
    assert.deepEqual(classifyArticleLink(`${context.documentUrl}#section-2`, context),
        { kind: 'fragment', hash: '#section-2' })
    assert.deepEqual(classifyArticleLink('#', context), { kind: 'inert' })
})

test('external links resolve to absolute URLs for Flutter', () => {
    assert.deepEqual(classifyArticleLink('https://example.com/page#part', context),
        { kind: 'external', href: 'https://example.com/page#part' })
    assert.deepEqual(classifyArticleLink('//example.com/protocol-relative', context),
        { kind: 'external', href: 'http://example.com/protocol-relative' })
    assert.deepEqual(classifyArticleLink('mailto:someone@example.com', context),
        { kind: 'external', href: 'mailto:someone@example.com' })
})

test('loopback and unsupported schemes never leave the reader', () => {
    assert.deepEqual(classifyArticleLink('other.html', context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink('other.html#part', context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink('http://127.0.0.1:4321/r/token/book/x', context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink('javascript:alert(1)', context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink('blob:http://127.0.0.1:4321/abc', context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink('', context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink(null, context), { kind: 'inert' })
    assert.deepEqual(classifyArticleLink('http://[bad', context), { kind: 'inert' })
})

test('anchor lookup walks only the ancestor chain', () => {
    const anchor = { nodeType: 1, closest: selector => selector === 'a[href]' ? anchor : null }
    const span = { nodeType: 1, closest: selector => anchor.closest(selector) }
    const textNode = { nodeType: 3, parentElement: span }
    assert.equal(anchorFromEvent({ target: span }), anchor)
    assert.equal(anchorFromEvent({ target: textNode }), anchor)
    assert.equal(anchorFromEvent({ target: { nodeType: 1, closest: () => null } }), null)
    assert.equal(anchorFromEvent({ target: null }), null)
    assert.equal(anchorFromEvent(null), null)
})
