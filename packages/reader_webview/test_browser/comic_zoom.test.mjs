import test from 'node:test'
import assert from 'node:assert/strict'
import { zipSync } from 'fflate'
import { createHarness, openEpub } from './harness.mjs'

async function openComic(t, { axis = 'slide', rtl = false, hostTaps = false } = {}) {
    const harness = await createHarness(t)
    const { page, origin } = harness
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(origin + '/blank')
    const images = await page.evaluate(() => Array.from({ length: 5 }, (_, index) => {
        const canvas = document.createElement('canvas')
        canvas.width = 600; canvas.height = 900
        const ctx = canvas.getContext('2d')
        ctx.fillStyle = '#ddedef'; ctx.fillRect(0, 0, 600, 900)
        ctx.fillStyle = '#40898d'; ctx.fillRect(20, 20, 560, 390)
        ctx.fillStyle = '#b76474'; ctx.fillRect(20, 430, 560, 450)
        ctx.fillStyle = '#ffffff'; ctx.font = '30px sans-serif'
        ctx.fillText('Comic page ' + index, 100, 200)
        return canvas.toDataURL().split(',')[1]
    }))
    const archive = zipSync(Object.fromEntries(images.map((image, index) =>
        [`page${index}.png`, Buffer.from(image, 'base64')])), { level: 0 })
    // Replace transport only: real archive decoding, comic loader, view and bridge.
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() {
                return new File([Uint8Array.from(${JSON.stringify([...archive])})], 'zoom.cbz');
            }
        }`,
    }))
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/zoom.cbz'),
        comicHostTaps: JSON.stringify(hostTaps),
        pageProgressionDirection: JSON.stringify(rtl ? 'rtl' : 'ltr'),
        style: JSON.stringify({ pageTurnStyle: axis, allowScript: false,
            fontName: 'serif', fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb' }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.waitForFunction(() => {
        const renderer = window.reader?.view?.renderer
        const doc = renderer?.getContents().find(({ index }) => index === renderer.index)?.doc
        return doc?.querySelector('img')?.complete && doc.defaultView.frameElement.getBoundingClientRect().width > 300
    })
    await page.waitForTimeout(50)
    await page.evaluate(() => { window.bridgeCalls.length = 0 })
    return harness
}

const state = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({index}) => index === renderer.index).doc
    const rect = doc.defaultView.frameElement.getBoundingClientRect()
    return { index: renderer.index, width: rect.width, left: rect.left, top: rect.top,
        clicks: window.bridgeCalls.filter(([name]) => name === 'onClick').map(([, value]) => value),
        positions: window.bridgeCalls.filter(([name]) => name === 'onRelocated').length }
})

async function pointer(page, type, x, y, id = 1) {
    return page.evaluate(({ type, x, y, id }) => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({index}) => index === renderer.index).doc
        const frame = doc.defaultView.frameElement
        const rect = frame.getBoundingClientRect()
        const clientX = (x - rect.left) * frame.clientWidth / rect.width
        const clientY = (y - rect.top) * frame.clientHeight / rect.height
        const target = doc.elementFromPoint(clientX, clientY) ?? doc.body
        target.dispatchEvent(new doc.defaultView.PointerEvent(type, {
            pointerId: id, pointerType: 'touch', bubbles: true, cancelable: true,
            clientX, clientY, screenX: x, screenY: y, button: 0,
        }))
        const touchType = {pointerdown: 'touchstart', pointermove: 'touchmove', pointerup: 'touchend', pointercancel: 'touchcancel'}[type]
        const event = new Event(touchType, { bubbles: true, cancelable: true })
        const touch = { identifier: id, clientX, clientY, screenX: x, screenY: y }
        Object.defineProperties(event, { touches: { value: type === 'pointerup' ? [] : [touch] }, changedTouches: { value: [touch] } })
        target.dispatchEvent(event)
    }, { type, x, y, id })
}

test('comic double tap zooms at the tapped area without toggling chrome', async t => {
    const { page } = await openComic(t)
    const before = await state(page)
    await page.mouse.click(150, 330)
    assert.equal((await state(page)).clicks.length, 0, 'first tap waits for a second tap')
    await page.waitForTimeout(80)
    await page.mouse.click(150, 330)
    await page.waitForTimeout(350)
    const zoomed = await state(page)
    assert.ok(zoomed.width > before.width * 2)
    assert.equal(zoomed.clicks.length, 0)
    assert.equal(zoomed.index, before.index)
    assert.equal(zoomed.positions, before.positions)
    await page.mouse.dblclick(150, 330, { delay: 80 })
    await page.waitForTimeout(350)
    const reset = await state(page)
    assert.ok(Math.abs(reset.width - before.width) < 1)
    assert.equal(reset.clicks.length, 0)
})

test('a single comic tap still opens chrome, including while zoomed', async t => {
    const { page } = await openComic(t)
    await page.mouse.click(195, 420)
    await page.waitForTimeout(350)
    assert.equal((await state(page)).clicks.length, 1)
    await page.mouse.dblclick(150, 330, { delay: 80 })
    await page.waitForTimeout(350)
    // Edge taps in a zoomed page must not turn it accidentally.
    await page.mouse.click(25, 400)
    await page.waitForTimeout(350)
    assert.deepEqual((await state(page)).clicks.at(-1), { x: 0.5, y: 0.5 })
})

test('touch taps zoom without compatibility clicks and suppress duplicate clicks', async t => {
    const { page } = await openComic(t)
    const before = await state(page)
    for (let i = 0; i < 2; i++) {
        await pointer(page, 'pointerdown', 150, 330)
        await pointer(page, 'pointerup', 150, 330)
        // A compatibility click, when delivered, must not become another tap.
        await page.mouse.click(150, 330)
        await page.waitForTimeout(70)
    }
    await page.waitForTimeout(350)
    const zoomed = await state(page)
    assert.ok(zoomed.width > before.width * 2)
    assert.equal(zoomed.clicks.length, 0)
    assert.equal(zoomed.index, before.index)
    await pointer(page, 'pointerdown', 25, 400)
    await pointer(page, 'pointerup', 25, 400)
    await page.waitForTimeout(350)
    assert.deepEqual((await state(page)).clicks, [{ x: 0.5, y: 0.5 }])
})

test('host-forwarded taps tolerate missing WebKit touches without duplicate actions', async t => {
    const { page } = await openComic(t, { hostTaps: true })
    const before = await state(page)
    const tap = () => page.evaluate(() => handleComicTouchTap(150, 330))
    // iOS can deliver the first touch and omit the entire second DOM sequence.
    await pointer(page, 'pointerdown', 150, 330)
    await pointer(page, 'pointerup', 150, 330)
    await tap()
    await page.mouse.click(150, 330)
    await page.waitForTimeout(80)
    await tap()
    await page.waitForTimeout(350)
    assert.ok((await state(page)).width > before.width * 2)
    assert.equal((await state(page)).clicks.length, 0)
    // On WebKit versions delivering both touches, neither is counted twice.
    for (let i = 0; i < 2; i++) {
        await pointer(page, 'pointerdown', 150, 330)
        await pointer(page, 'pointerup', 150, 330)
        await tap()
        await page.waitForTimeout(80)
    }
    await page.waitForTimeout(350)
    assert.ok(Math.abs((await state(page)).width - before.width) < 1)
    assert.equal((await state(page)).clicks.length, 0)
    await tap()
    await page.waitForTimeout(350)
    assert.equal((await state(page)).clicks.length, 1)
})

test('panning is bounded, does not click or change the comic location', async t => {
    const { page } = await openComic(t)
    await page.mouse.dblclick(195, 420, { delay: 80 })
    await page.waitForTimeout(350)
    const before = await state(page)
    await page.mouse.move(150, 330)
    await page.mouse.down()
    await page.mouse.move(340, 580, { steps: 12 })
    await page.mouse.up()
    await page.waitForTimeout(350)
    const after = await state(page)
    assert.ok(after.left > before.left + 100)
    assert.ok(after.left <= 1, 'page cannot be dragged out of the viewport')
    assert.equal(after.index, before.index)
    assert.equal(after.clicks.length, 0)
    assert.equal(after.positions, before.positions)
})

test('host taps do not dismiss an image-area draft being edited', async t => {
    const { page } = await openComic(t, { hostTaps: true })
    await page.mouse.move(195, 420)
    await page.mouse.down()
    await page.waitForTimeout(330)
    await page.mouse.up()
    assert.equal(await page.evaluate(() => __readflexImageAreaDraftActive), true)
    await page.evaluate(() => handleComicTouchTap(195, 420))
    await page.waitForTimeout(350)
    assert.equal(await page.evaluate(() => __readflexImageAreaDraftActive), true)
    assert.equal((await state(page)).clicks.length, 0)
})

test('page changes and rotation reset zoom and cancel deferred taps', async t => {
    const { page } = await openComic(t)
    const before = await state(page)
    await page.mouse.click(195, 420)
    await page.evaluate(() => window.reader.view.next())
    await page.waitForTimeout(350)
    assert.equal((await state(page)).clicks.length, 0)
    await page.mouse.dblclick(195, 420, { delay: 80 })
    await page.waitForTimeout(350)
    await page.evaluate(() => window.reader.view.next())
    await page.waitForTimeout(350)
    assert.ok(Math.abs((await state(page)).width - before.width) < 1)
    await page.mouse.dblclick(195, 420, { delay: 80 })
    await page.waitForTimeout(350)
    await page.setViewportSize({ width: 844, height: 390 })
    await page.waitForTimeout(350)
    assert.ok((await state(page)).width < 422)
})

test('fixed-layout EPUB does not acquire comic zoom or deferred taps', async t => {
    const { page, origin, requests } = await createHarness(t)
    await openEpub(page, origin, '<html xmlns="http://www.w3.org/1999/xhtml"><head><meta name="viewport" content="width=800,height=600"/></head><body>Fixed page</body></html>', true)
    assert.equal(requests.some(path => path.includes('panzoom')), false)
})

for (const axis of ['slide', 'vertical']) for (const rtl of [false, true]) {
    test(`comic ${axis} rtl=${rtl} swipes turn at fit scale but pan when zoomed`, async t => {
        const { page } = await openComic(t, { axis, rtl })
        const start = await state(page)
        await pointer(page, 'pointerdown', 290, 540)
        await pointer(page, 'pointermove', axis === 'vertical' ? 290 : 90, axis === 'vertical' ? 290 : 540)
        await pointer(page, 'pointerup', axis === 'vertical' ? 290 : 90, axis === 'vertical' ? 290 : 540)
        await page.waitForTimeout(350)
        assert.equal((await state(page)).index, start.index + 1)
        await page.mouse.dblclick(195, 420, { delay: 80 })
        await page.waitForTimeout(350)
        const zoomed = await state(page)
        await pointer(page, 'pointerdown', 290, 540)
        await pointer(page, 'pointermove', axis === 'vertical' ? 290 : 90, axis === 'vertical' ? 290 : 540)
        await page.waitForTimeout(30)
        await pointer(page, 'pointerup', axis === 'vertical' ? 290 : 90, axis === 'vertical' ? 290 : 540)
        await page.waitForTimeout(350)
        assert.equal((await state(page)).index, zoomed.index)
    })
}

test('pinch is clamped, cancels long press and permits panning after one finger lifts', async t => {
    const { page } = await openComic(t)
    const start = await state(page)
    await pointer(page, 'pointerdown', 160, 420, 1)
    await pointer(page, 'pointerdown', 220, 420, 2)
    for (let i = 1; i <= 8; i++) {
        await pointer(page, 'pointermove', 160 - i * 15, 420, 1)
        await pointer(page, 'pointermove', 220 + i * 15, 420, 2)
        await page.waitForTimeout(35)
    }
    await pointer(page, 'pointerup', 340, 420, 2)
    const pinched = await state(page)
    assert.ok(pinched.width > start.width * 1.5)
    assert.ok(pinched.width <= start.width * 4 + 1)
    await pointer(page, 'pointermove', 200, 440, 1)
    await page.waitForTimeout(50)
    await pointer(page, 'pointerup', 200, 440, 1)
    await page.waitForTimeout(450)
    const panned = await state(page)
    assert.equal(panned.index, start.index)
    assert.ok(panned.left > pinched.left)
    assert.equal(panned.clicks.length, 0)
    assert.equal(await page.evaluate(() => window.bridgeCalls.filter(([name]) => name === 'onImageAreaSelected').length), 0)
})

test('zoomed long press retains image-area coordinates and selection ownership', async t => {
    const { page } = await openComic(t)
    await page.mouse.dblclick(195, 420, { delay: 80 })
    await page.waitForTimeout(350)
    await page.mouse.move(195, 420)
    await page.mouse.down()
    await page.waitForTimeout(330)
    await page.mouse.up()
    const selection = await page.evaluate(() => window.bridgeCalls.find(([name]) => name === 'onImageAreaSelected')?.[1])
    assert.ok(selection?.rect)
    const zoomed = await state(page)
    assert.ok(Math.abs((selection.pos.left + selection.pos.right) * 390 / 2 - 195) < 2)
    assert.ok(Math.abs((selection.pos.top + selection.pos.bottom) * 844 / 2 - 420) < 2)
    await page.mouse.move(195, 420)
    await page.mouse.down()
    await page.mouse.move(245, 450, { steps: 6 })
    await page.mouse.up()
    assert.equal((await state(page)).left, zoomed.left, 'moving a highlight must not pan the page')
})

test('pointer bursts are batched and never send per-move Flutter messages', async t => {
    const { page } = await openComic(t)
    await page.mouse.dblclick(195, 420, { delay: 80 })
    await page.waitForTimeout(350)
    const result = await page.evaluate(async () => {
        const r = reader.view.renderer
        const doc = r.getContents().find(x => x.index === r.index).doc
        const frame = doc.defaultView.frameElement
        const rect = frame.getBoundingClientRect()
        const stage = frame.parentElement.parentElement
        let paints = 0
        const observer = new MutationObserver(records => { paints += records.length })
        observer.observe(stage, { attributes: true, attributeFilter: ['style'] })
        const send = (type, x) => doc.body.dispatchEvent(new PointerEvent(type, {
            bubbles: true, cancelable: true, pointerId: 1, button: 0,
            clientX: (x - rect.left) * frame.clientWidth / rect.width,
            clientY: (420 - rect.top) * frame.clientHeight / rect.height,
            screenX: x, screenY: 420,
        }))
        window.bridgeCalls.length = 0
        send('pointerdown', 195)
        for (let i = 0; i < 200; i++) send('pointermove', 195 + i * 0.5)
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        send('pointerup', 295)
        await new Promise(resolve => setTimeout(resolve, 50))
        observer.disconnect()
        return { paints, calls: window.bridgeCalls, left: frame.getBoundingClientRect().left, before: rect.left }
    })
    assert.ok(result.paints > 0 && result.paints <= 4, 'one burst must not repaint for every raw pointer move')
    assert.deepEqual(result.calls, [])
    assert.ok(result.left > result.before)
})

test('closing a comic or backgrounding it cancels a pending chrome tap', async t => {
    const { page } = await openComic(t)
    await page.mouse.click(195, 420)
    await page.evaluate(() => {
        Object.defineProperty(document, 'hasFocus', { configurable: true, value: () => false })
        window.dispatchEvent(new Event('blur'))
        delete document.hasFocus
    })
    await page.waitForTimeout(350)
    assert.equal((await state(page)).clicks.length, 0)
    await page.mouse.click(195, 420)
    await page.evaluate(() => window.reader.view.close())
    await page.waitForTimeout(350)
    assert.equal(await page.evaluate(() => window.bridgeCalls.filter(([name]) => name === 'onClick').length), 0)
})
