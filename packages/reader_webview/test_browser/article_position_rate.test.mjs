import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

// Article positions while scrolling: each one crosses the bridge into a reader
// state, so a fling sends one per 140ms interval and then where it stopped.

const minEmitIntervalMs = 140
const content = Array.from({ length: 200 }, (_, i) =>
    `<p id="b${i}" data-rf-block-id="b${i}">` +
    `<span id="b${i}-s0" data-rf-sentence="0">Paragraph ${i} is one sentence of ordinary prose. </span>` +
    `<span id="b${i}-s1" data-rf-sentence="1">A second one keeps the article long. </span>` +
    '</p>').join('')

async function openArticle(t) {
    const { page, routes, articleUrl } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    routes.set('/article-content', content)
    await page.setViewportSize({ width: 390, height: 700 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onArticlePositionChanged'))
    // Let the load emits settle before counting.
    await page.waitForTimeout(400)
    return page
}

const positions = page => page.evaluate(() => window.bridgeCalls
    .filter(([name]) => name === 'onArticlePositionChanged')
    .map(([, position]) => position))

// Scrolls a little every frame, the way a fling moves, and returns how long it
// took in page time.
const fling = (page, { from, to, frames }) => page.evaluate(({ from, to, frames }) =>
    new Promise(resolve => {
        const maxScroll = document.documentElement.scrollHeight - innerHeight
        const started = performance.now()
        let frame = 0
        const step = () => {
            frame++
            scrollTo({ top: maxScroll * (from + (to - from) * frame / frames), behavior: 'instant' })
            if (frame < frames) requestAnimationFrame(step)
            else resolve(performance.now() - started)
        }
        requestAnimationFrame(step)
    }), { from, to, frames })

const progress = page => page.evaluate(() =>
    scrollY / (document.documentElement.scrollHeight - innerHeight))

test('a fling sends one position per interval, then where it stopped', async t => {
    const page = await openArticle(t)
    await page.evaluate(() => { window.bridgeCalls.length = 0 })

    const elapsed = await fling(page, { from: 0, to: 0.6, frames: 60 })
    const during = (await positions(page)).length
    assert.ok(
        during <= Math.floor(elapsed / minEmitIntervalMs) + 2,
        `${during} positions in ${Math.round(elapsed)}ms of scrolling`,
    )

    await page.waitForTimeout(minEmitIntervalMs * 3)
    const sent = await positions(page)
    const last = sent.at(-1)
    assert.equal(last.reason, 'scroll')
    assert.ok(Math.abs(last.percentage - await progress(page)) < 0.001,
        `the last position ${last.percentage} is where the fling stopped`)
    assert.equal(last.atEnd, false)
})

test('reaching the end is sent at once', async t => {
    const page = await openArticle(t)
    await page.evaluate(() => { window.bridgeCalls.length = 0 })
    // Timers are held, so a deferred update never arrives; the end follows a
    // sent position within one interval.
    await page.evaluate(() => new Promise(resolve => {
        window.heldSetTimeout = window.setTimeout
        window.setTimeout = () => 0
        scrollTo({ top: (document.documentElement.scrollHeight - innerHeight) / 2, behavior: 'instant' })
        requestAnimationFrame(() => requestAnimationFrame(() => {
            scrollTo({ top: document.documentElement.scrollHeight, behavior: 'instant' })
            resolve()
        }))
    }))
    await page.waitForFunction(() => window.bridgeCalls.some(([name, position]) =>
        name === 'onArticlePositionChanged' && position.atEnd), null, { timeout: 5000 })
    await page.evaluate(() => { window.setTimeout = window.heldSetTimeout })
    assert.equal((await positions(page)).at(-1).atEnd, true)
})
