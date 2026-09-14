import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

const selectionState = () => {
    const range = getSelection().getRangeAt(0)
    return {
        start: { id: range.startContainer.parentElement.id, offset: range.startOffset },
        end: { id: range.endContainer.parentElement.id, offset: range.endOffset },
        text: range.toString(),
    }
}

// The app's prose normalization must not hide a shadow host as an empty div.
const applyReaderNormalization = () => changeStyle({ customCSSEnabled: true,
    customCSS: 'p:empty, span:empty, div:empty:not([class]):not([id]) { display:none !important; }' })

for (const platform of ['Android', 'iPhone']) {
    test(`${platform} owns the same initial article handles for forward and backward ranges`, async t => {
        const { page, routes, articleUrl } = await createHarness(t)
        await page.addInitScript(platform => Object.defineProperty(navigator, 'userAgent', { value: platform }), platform)
        routes.set('/article-content', '<p id="text">Several words for selecting a phrase, not only its first word.</p>')
        await page.setViewportSize({ width: 390, height: 844 })
        await page.goto(articleUrl())
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => document.fonts.ready)
        await page.evaluate(applyReaderNormalization)
        for (const backwards of [false, true]) {
            const expected = await page.evaluate(backwards => {
                const node = document.querySelector('#text').firstChild
                window.bridgeCalls.length = 0
                getSelection().setBaseAndExtent(node, backwards ? 27 : 8, node, backwards ? 8 : 27)
                return node.data.slice(8, 27)
            }, backwards)
            await page.waitForTimeout(250)
            assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(),
                platform === 'Android' ? 2 : 0)
            assert.deepEqual(await page.evaluate(() => ({ text: getSelection().toString(),
                anchor: getSelection().anchorOffset, focus: getSelection().focusOffset,
                clears: window.bridgeCalls.filter(([name]) => name === 'onSelectionCleared').length })),
            { text: expected, anchor: backwards ? 27 : 8, focus: backwards ? 8 : 27, clears: 0 })
            await page.evaluate(() => clearSelectionAfterTextAction())
            await page.waitForTimeout(200)
            assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 0)
        }
        assert.ok(await page.locator('[data-readflex-selection-handles]').count() <= 1, 'reuse the controls')
    })
}

for (const backwards of [true, false]) {
    test(`Android retains the visible ${backwards ? 'start' : 'end'} control when the opposite endpoint leaves the viewport`, async t => {
        const { page, routes, articleUrl } = await createHarness(t)
        await page.addInitScript(() => Object.defineProperty(navigator, 'userAgent', { value: 'Android' }))
        routes.set('/article-content', Array.from({ length: 100 }, (_, i) =>
            `<p id="p${i}">Several words in a paragraph for repeated selection.</p>`).join(''))
        await page.setViewportSize({ width: 390, height: 844 })
        await page.goto(articleUrl())
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => document.fonts.ready)
        await page.evaluate(applyReaderNormalization)
        await page.evaluate(() => goToHref('#p40'))
        await page.waitForTimeout(150)
        await page.evaluate(backwards => {
            const start = document.querySelector('#p40').firstChild, end = document.querySelector('#p50').firstChild
            getSelection().setBaseAndExtent(backwards ? end : start, backwards ? 25 : 0,
                backwards ? start : end, backwards ? 0 : 25)
        }, backwards)
        await page.waitForTimeout(250)
        const before = await page.evaluate(selectionState)
        await page.evaluate(() => { window.bridgeCalls.length = 0 })
        await page.evaluate(backwards => {
            document.dispatchEvent(new WheelEvent('wheel'))
            const element = document.querySelector(backwards ? '#p40' : '#p50')
            scrollTo(0, element.getBoundingClientRect().top + scrollY - (backwards ? 750 : 100))
        }, backwards)
        await page.waitForTimeout(450)
        assert.deepEqual(await page.evaluate(selectionState), before, 'taking over handles preserves the exact range')
        assert.deepEqual(await page.evaluate(() => window.bridgeCalls
            .filter(([name]) => name === 'onSelectionInteractionChanged').map(([, value]) => value)),
        [true, false], 'restoring the same range must not reopen the adjustment phase')
        const handle = page.locator(`[data-endpoint="${backwards ? 'start' : 'end'}"]`)
        assert.equal(await handle.isVisible(), true, 'the visible endpoint must not return to a stale native handle')
        const box = await handle.boundingBox()
        await page.evaluate(() => { window.bridgeCalls.length = 0 })
        await page.mouse.move(box.x + 24, box.y + 24)
        await page.mouse.down()
        assert.equal(await page.evaluate(() => window.bridgeCalls
            .filter(([name]) => name === 'onSelectionInteractionChanged').length), 0,
        'grabbing a continuation handle must not remove the Flutter overlay during pointerdown')
        await page.mouse.move(160, backwards ? 200 : 700, { steps: 12 })
        await page.mouse.up()
        await page.waitForTimeout(250)
        const after = await page.evaluate(selectionState)
        assert.deepEqual(backwards ? after.end : after.start, backwards ? before.end : before.start)
        assert.ok(after.text.length > before.text.length)
        assert.deepEqual(await page.evaluate(() => window.bridgeCalls
            .filter(([name]) => name === 'onSelectionInteractionChanged').map(([, value]) => value)), [true, false])
        assert.equal(await page.evaluate(() => window.bridgeCalls.filter(([name]) => name === 'onSelectionCleared').length), 0)
        await page.evaluate(() => clearSelectionAfterTextAction())
        await page.waitForTimeout(200)
        assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 0)
    })
}

for (const platform of ['Android', 'iPhone']) for (const backwards of [true, false]) {
    test(`${platform} preserves the fixed endpoint through repeated ${backwards ? 'upward' : 'downward'} continuations`, async t => {
        const { page, routes, articleUrl } = await createHarness(t)
        await page.addInitScript(platform => Object.defineProperty(navigator, 'userAgent', { value: platform }), platform)
        routes.set('/article-content', Array.from({ length: 160 }, (_, i) =>
            `<p id="p${i}">Paragraph ${i}: several words for selection across screens. ` +
            'A longer passage makes each scroll leave both endpoints behind while preserving the selected text.</p>').join(''))
        await page.setViewportSize({ width: 390, height: 844 })
        await page.goto(articleUrl())
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => document.fonts.ready)
        await page.evaluate(applyReaderNormalization)
        await page.evaluate(() => goToHref('#p80'))
        await page.waitForTimeout(200)
        await page.evaluate(() => {
            const node = document.querySelector('#p80').firstChild
            getSelection().setBaseAndExtent(node, 14, node, 21)
        })
        await page.waitForTimeout(250)
        const original = await page.evaluate(selectionState)
        const fixedEnd = backwards ? 'end' : 'start'
        let previous = original
        for (let cycle = 1; cycle <= 4; cycle++) {
            const paragraph = 80 + (backwards ? -1 : 1) * cycle * 16
            await page.evaluate(paragraph => {
                const dispatch = (type, y) => {
                    const event = new Event(type)
                    Object.defineProperty(event, 'touches', { value: [{ clientX: 350, clientY: y }] })
                    document.dispatchEvent(event)
                }
                dispatch('touchstart', 400)
                dispatch('touchmove', 500)
                scrollTo(0, document.querySelector(`#p${paragraph}`).getBoundingClientRect().top + scrollY - 300)
            }, paragraph)
            await page.waitForTimeout(100)
            await page.evaluate(() => document.dispatchEvent(new Event('touchend')))
            await page.waitForTimeout(250)
            assert.deepEqual(await page.evaluate(selectionState), previous, `cycle ${cycle}: scrolling preserves both endpoints`)
            const handle = page.locator(`[data-readflex-selection-handles] button[data-endpoint="${backwards ? 'start' : 'end'}"]`)
            const box = await handle.boundingBox({ timeout: 1000 })
            assert.ok(box, `cycle ${cycle}: the moving endpoint remains reachable`)
            await page.mouse.move(box.x + 24, box.y + 24)
            await page.mouse.down()
            assert.deepEqual(await page.evaluate(selectionState), previous, `cycle ${cycle}: grabbing is not a new selection`)
            const destination = await page.evaluate(paragraph => {
                const node = document.querySelector(`#p${paragraph}`).firstChild
                const range = document.createRange()
                range.setStart(node, 14); range.setEnd(node, 21)
                const rect = range.getBoundingClientRect()
                return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
            }, paragraph)
            await page.mouse.move(destination.x, destination.y, { steps: 10 })
            await page.mouse.up()
            await page.waitForTimeout(250)
            const current = await page.evaluate(selectionState)
            assert.deepEqual(current[fixedEnd], original[fixedEnd], `cycle ${cycle}: the opposite boundary never moves`)
            assert.ok(current.text.length > previous.text.length, `cycle ${cycle}: extension never replaces the range`)
            previous = current
        }
    })
}
