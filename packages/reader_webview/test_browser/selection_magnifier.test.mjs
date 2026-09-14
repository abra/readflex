import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

async function setup(t, bridge = 'record') {
    const { page, origin } = await createHarness(t)
    await page.setViewportSize({ width: 400, height: 700 })
    await page.goto(origin + '/blank')
    await page.evaluate(async bridge => {
        const { createSelectionContinuationHandles } = await import('/foliate-js/src/readflex_selection_handles.js')
        window.lensCalls = []
        window.moves = 0
        window.crossed = false
        document.addEventListener('pointerdown', event => { window.pointerId = event.pointerId }, true)
        if (bridge !== 'absent') window.flutter_inappwebview._readerSelectionMagnifier = (...args) => {
            if (bridge === 'throw') throw Error('Unavailable')
            lensCalls.push(args)
        }
        window.controls = createSelectionContinuationHandles({
            viewport: window, labels: { start: 'Start', end: 'End' },
            getRange: () => ({}),
            rectFor: (_, end) => end
                ? { left: 210, right: 220, top: 400, bottom: 420 }
                : { left: 100, right: 110, top: 200, bottom: 220 },
            onStart() {}, onEnd() {}, onKey() {},
            onMove() { moves++; return !crossed },
        })
        controls.show()
    }, bridge)
    await page.mouse.move(220, 430)
    await page.mouse.down()
    return page
}

test('magnifies the moving text boundary, not the knob; hides on release', async t => {
    const page = await setup(t)
    assert.deepEqual(await page.evaluate(() => lensCalls), [])
    await page.mouse.move(260, 480)
    await page.waitForFunction(() => lensCalls.length > 0)
    assert.deepEqual(await page.evaluate(() => lensCalls.at(-1)), [.55, 410 / 700, true])
    await page.mouse.up()
    assert.deepEqual(await page.evaluate(() => lensCalls.at(-1)), [0, 0, false])
})

test('follows endpoint crossing and dismisses on hide without delayed resurrection', async t => {
    const page = await setup(t)
    await page.evaluate(() => { crossed = true })
    await page.mouse.move(80, 190)
    await page.waitForFunction(() => lensCalls.length > 0)
    assert.deepEqual(await page.evaluate(() => lensCalls.at(-1)), [.25, 210 / 700, true])
    await page.evaluate(() => controls.hide())
    await page.mouse.move(60, 170)
    await page.mouse.up()
    assert.deepEqual(await page.evaluate(() => lensCalls.at(-1)), [0, 0, false])
})

for (const bridge of ['absent', 'throw']) test(`selection still works when native bridge is ${bridge}`, async t => {
    const page = await setup(t, bridge)
    await page.mouse.move(260, 480)
    await page.waitForFunction(() => moves > 0)
    await page.mouse.up()
    await page.evaluate(() => controls.dispose())
    assert.equal(await page.locator('.readflex-selection-handles').count(), 0)
})

test('batches pointer movement per frame and dismisses on cancellation', async t => {
    const page = await setup(t)
    await page.evaluate(async () => {
        const button = document.querySelector('.readflex-selection-handles').shadowRoot.querySelector('[data-endpoint=end]')
        for (let i = 0; i < 30; i++) button.dispatchEvent(new PointerEvent('pointermove', {
            pointerId, clientX: 240 + i, clientY: 480, bubbles: true,
        }))
        await new Promise(requestAnimationFrame)
    })
    assert.equal(await page.evaluate(() => moves), 1)
    assert.equal(await page.evaluate(() => lensCalls.length), 1)
    await page.evaluate(() => {
        controls.refresh()
        controls.refresh()
    })
    assert.equal(await page.evaluate(() => lensCalls.length), 1)
    await page.evaluate(() => {
        document.querySelector('.readflex-selection-handles').shadowRoot.querySelector('[data-endpoint=end]')
            .dispatchEvent(new PointerEvent('pointercancel', { pointerId, bubbles: true }))
    })
    assert.deepEqual(await page.evaluate(() => lensCalls.at(-1)), [0, 0, false])
    await page.mouse.up()
})

for (const article of [false, true]) test(`${article ? 'article' : 'book'} ignores delayed long press while dragging a handle`, async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    await page.evaluate(async article => {
        document.body.innerHTML = '<p style="font:24px/2 serif;margin:100px">First second third fourth fifth.</p>'
        const node = document.querySelector('p').firstChild
        if (article) {
            const { installArticleSelection } = await import('/foliate-js/src/readflex_article_selection.js')
            window.controller = installArticleSelection({ doc: document, customHandles: true })
        } else {
            const { installSelectionNavigation } = await import('/foliate-js/src/readflex_selection_navigation.js')
            window.controller = installSelectionNavigation({
                doc: document, viewport: window, customHandles: true,
                isActive: () => true, onAdjusting() {}, onSettled() {},
                navigation: { state: () => null },
            })
        }
        getSelection().setBaseAndExtent(node, 13, node, 18)
        const glyph = document.createRange()
        glyph.setStart(node, 1); glyph.setEnd(node, 2)
        const rect = glyph.getBoundingClientRect()
        window.delayedLongPress = () => window.dispatchEvent(new CustomEvent('readflex-long-press', {
            detail: { x: (rect.left + rect.width / 2) / innerWidth, y: (rect.top + rect.height / 2) / innerHeight },
        }))
    }, article)
    const handle = page.locator('[data-readflex-selection-handles] button[data-endpoint=end]')
    await handle.waitFor({ state: 'visible' })
    const box = await handle.boundingBox()
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
    await page.mouse.down()
    await page.evaluate(() => delayedLongPress())
    assert.equal(await page.evaluate(() => getSelection().toString()), 'third')
    await page.mouse.up()
    await page.evaluate(() => delayedLongPress())
    assert.equal(await page.evaluate(() => getSelection().toString()), 'First')
    await page.evaluate(() => controller.dispose())
})
