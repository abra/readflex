import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

// Minutes left in an article: remaining normalized text after the current
// sentence at 1200 characters per minute, indexed once after load.

const charsPerMinute = 1200
const paragraph = i => `Paragraph ${i} carries several sentences of ordinary prose so the article scrolls. `
const sentenceContent = Array.from({ length: 80 }, (_, i) =>
    `<p id="b${i}" data-rf-block-id="b${i}">` +
    `<span id="b${i}-s0" data-rf-sentence="0">${paragraph(i)}</span>` +
    `<span id="b${i}-s1" data-rf-sentence="1">It keeps <em>inline</em> markup inside the sentence. </span>` +
    '</p>').join('')
const legacyContent = Array.from({ length: 80 }, (_, i) => `<p>${paragraph(i)}</p>`).join('')

async function openArticle(t, content) {
    const { page, routes, articleUrl } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    routes.set('/article-content', content)
    await page.setViewportSize({ width: 390, height: 700 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onArticlePositionChanged'))
    return page
}

const latestPosition = page => page.evaluate(() => window.bridgeCalls
    .filter(([name]) => name === 'onArticlePositionChanged').at(-1)?.[1] ?? null)

async function scrollToFraction(page, fraction) {
    await page.evaluate(() => { window.bridgeCalls.length = 0 })
    await page.evaluate(value => {
        const maxScroll = document.documentElement.scrollHeight - innerHeight
        scrollTo({ top: maxScroll * value, behavior: 'instant' })
    }, fraction)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onArticlePositionChanged'))
    // WebKit can deliver the visible-sentence update a frame after the scroll
    // emit; read the settled position.
    await page.waitForTimeout(300)
    return latestPosition(page)
}

const normalizedLength = page => page.evaluate(() =>
    document.getElementById('article-content').textContent.replace(/\s+/g, ' ').length)

for (const [kind, content] of [['sentence-anchored', sentenceContent], ['legacy', legacyContent]]) {
    test(`${kind} article minutesLeft decreases while scrolling and reaches 0 at the end`, async t => {
        const page = await openArticle(t, content)
        const total = await normalizedLength(page) / charsPerMinute
        const first = await latestPosition(page)
        assert.equal(typeof first.minutesLeft, 'number')
        assert.ok(first.minutesLeft > 0, 'a fresh article has reading time left')
        assert.ok(first.minutesLeft <= total + 0.01, `${first.minutesLeft} <= ${total}`)
        assert.ok(first.minutesLeft > total * 0.8, 'the first screen leaves most of the article')

        const samples = [first.minutesLeft]
        for (const fraction of [0.25, 0.5, 0.75]) {
            const position = await scrollToFraction(page, fraction)
            assert.equal(position.atEnd, false)
            assert.ok(position.minutesLeft > 0)
            // Within a couple of sentences of the linear estimate.
            assert.ok(Math.abs(position.minutesLeft - total * (1 - fraction)) < total * 0.12,
                `${fraction}: ${position.minutesLeft} vs ${total * (1 - fraction)}`)
            samples.push(position.minutesLeft)
        }
        for (let i = 1; i < samples.length; i++) {
            assert.ok(samples[i] < samples[i - 1], `minutes must decrease: ${samples}`)
        }

        const end = await scrollToFraction(page, 1)
        assert.equal(end.atEnd, true)
        assert.equal(end.minutesLeft, 0)

        const back = await scrollToFraction(page, 0.5)
        assert.ok(back.minutesLeft > 0, 'scrolling back restores the estimate')
    })
}

test('article position emits reuse the load-time text index', async t => {
    const page = await openArticle(t, sentenceContent)
    await page.evaluate(() => {
        window.treeWalkers = 0
        const original = document.createTreeWalker.bind(document)
        document.createTreeWalker = (...args) => {
            window.treeWalkers++
            return original(...args)
        }
    })
    for (const fraction of [0.1, 0.3, 0.6, 0.9, 1]) await scrollToFraction(page, fraction)
    assert.equal(await page.evaluate(() => window.treeWalkers), 0)
})

test('the end-of-article emit is not throttled away', async t => {
    const page = await openArticle(t, sentenceContent)
    await scrollToFraction(page, 0.998)
    // A tiny final scroll moves neither the sentence nor the progress step.
    const end = await scrollToFraction(page, 1)
    assert.equal(end.atEnd, true)
    assert.equal(end.minutesLeft, 0)
})

test('an article without text reports no reading time left', async t => {
    const page = await openArticle(t, '<figure><img alt=""></figure>')
    const position = await latestPosition(page)
    assert.equal(position.minutesLeft, 0)
})
