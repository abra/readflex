import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

async function contentSwipe(page, target) {
    await page.evaluate(target => {
        const dispatch = (type, y) => {
            const event = new Event(type)
            Object.defineProperty(event, 'touches', { value: [{ clientX: 350, clientY: y }] })
            document.dispatchEvent(event)
        }
        dispatch('touchstart', 600)
        dispatch('touchmove', 400)
        scrollTo(0, target)
    }, target)
}

test('article freezes selection auto-scroll but keeps touch, wheel and cleared-selection scrolling', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', Array.from({ length: 100 }, (_, i) =>
        `<p id="p${i}">A long passage with words for selection and scrolling.</p>`).join(''))
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => document.fonts.ready)
    const select = () => {
        const node = document.querySelector('#p1').firstChild
        getSelection().setBaseAndExtent(node, 2, node, 14)
        document.dispatchEvent(new Event('selectionchange'))
    }
    await page.evaluate(select)
    const original = await page.evaluate(() => getSelection().toString())
    await page.evaluate(() => scrollTo(0, 3000))
    await page.waitForTimeout(100)
    assert.equal(await page.evaluate(() => scrollY), 0, 'the viewport stays fixed while moving a native handle')
    assert.equal(await page.evaluate(() => getSelection().toString()), original)
    await contentSwipe(page, 2000)
    await page.waitForTimeout(100)
    assert.equal(await page.evaluate(() => scrollY), 2000, 'ordinary finger scrolling remains free')
    await page.evaluate(() => document.dispatchEvent(new Event('touchend')))
    await page.waitForTimeout(800)
    await page.evaluate(() => {
        document.dispatchEvent(new WheelEvent('wheel', { deltaY: -1000 }))
        scrollTo(0, 1000)
    })
    await page.waitForTimeout(100)
    assert.equal(await page.evaluate(() => scrollY), 1000)
    await page.evaluate(() => {
        getSelection().removeAllRanges()
        document.dispatchEvent(new Event('selectionchange'))
        scrollTo(0, 4000)
    })
    await page.waitForTimeout(100)
    assert.equal(await page.evaluate(() => scrollY), await page.evaluate(() =>
        Math.min(4000, document.documentElement.scrollHeight - innerHeight)))
})

for (const direction of [-1, 1]) {
    test(`article bounds handle scrolling in either direction after focus loss (${direction})`, async t => {
        const { page, routes, articleUrl } = await createHarness(t)
        routes.set('/article-content', Array.from({ length: 100 }, (_, i) =>
            `<p id="p${i}">A long passage with words for selection and scrolling.</p>`).join(''))
        await page.setViewportSize({ width: 390, height: 844 })
        await page.goto(articleUrl())
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => document.fonts.ready)
        await page.evaluate(() => goToHref('#p50'))
        await page.waitForTimeout(100)
        await page.evaluate(() => {
            const node = document.querySelector('#p51').firstChild
            getSelection().setBaseAndExtent(node, 2, node, 14)
            document.dispatchEvent(new Event('selectionchange'))
            dispatchEvent(new Event('blur'))
        })
        // Losing focus must not unlock selection-induced scrolling.
        await page.waitForTimeout(200)
        const before = await page.evaluate(() => scrollY)
        await page.evaluate(direction => scrollBy(0, direction * 1500), direction)
        await page.waitForTimeout(100)
        const after = await page.evaluate(() => scrollY)
        assert.ok((after - before) * direction >= 0)
        assert.equal(after, before)

        await page.evaluate(() => goToPercent(1))
        await page.waitForTimeout(100)
        assert.equal(await page.evaluate(() => scrollY), await page.evaluate(() =>
            document.documentElement.scrollHeight - innerHeight), 'explicit navigation is not limited')
        assert.equal(await page.evaluate(() => getSelection().toString()), 'long passage')

        await contentSwipe(page, 1000)
        await page.evaluate(() => document.dispatchEvent(new Event('touchcancel')))
        await page.waitForTimeout(100)
        assert.equal(await page.evaluate(() => scrollY), 1000, 'cancelled touch scrolling can settle')
        // Re-grabbing a handle revokes that bypass immediately.
        await page.evaluate(() => {
            const selection = getSelection(), range = selection.getRangeAt(0)
            selection.setBaseAndExtent(range.startContainer, range.startOffset,
                range.endContainer, range.endOffset + 1)
            document.dispatchEvent(new Event('selectionchange'))
            scrollTo(0, 3000)
        })
        await page.waitForTimeout(100)
        assert.equal(await page.evaluate(() => scrollY), 1000)
    })
}

test('article selection can be disposed without retaining scroll interception', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    await page.evaluate(async () => {
        document.body.innerHTML = '<p>Text for selection.</p><div style="height:8000px"></div>'
        const { installArticleSelection } = await import('/foliate-js/src/readflex_article_selection.js')
        const controller = installArticleSelection({ doc: document })
        const node = document.querySelector('p').firstChild
        getSelection().setBaseAndExtent(node, 0, node, 4)
        document.dispatchEvent(new Event('selectionchange'))
        controller.dispose()
        controller.dispose()
        scrollTo(0, 4000)
    })
    await page.waitForTimeout(100)
    assert.equal(await page.evaluate(() => scrollY), 4000)
})

for (const platform of ['Android', 'iPhone']) for (const direction of [-1, 1]) {
    test(`${platform} article continues the ${direction < 0 ? 'start' : 'end'} after a separate scroll`, async t => {
        const { page, routes, articleUrl } = await createHarness(t)
        await page.addInitScript(platform => Object.defineProperty(navigator, 'userAgent', { value: platform }), platform)
        routes.set('/article-content', Array.from({ length: 80 }, (_, i) =>
            `<p id="p${i}">Paragraph ${i}: words for a selection across many screens.</p>`).join(''))
        await page.setViewportSize({ width: 390, height: 844 })
        await page.goto(articleUrl())
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => document.fonts.ready)
        await page.evaluate(() => changeStyle({ safeAreaTop: 64, safeAreaBottom: 34 }))
        await page.evaluate(() => goToHref('#p35'))
        await page.waitForTimeout(200)
        await page.evaluate(() => {
            const node = document.querySelector('#p35').firstChild
            getSelection().setBaseAndExtent(node, 14, node, 19)
        })
        await page.waitForTimeout(250)
        if (platform === 'Android') {
            assert.equal(await page.evaluate(() => getComputedStyle(document.getElementById('article-content')).position), 'fixed')
        }
        assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), platform === 'Android' ? 2 : 0)
        const text = await page.evaluate(() => getSelection().toString())
        const target = await page.evaluate(direction => {
            return document.querySelector(`#p${direction > 0 ? 55 : 15}`).getBoundingClientRect().top + scrollY - 200
        }, direction)
        await contentSwipe(page, target)
        await page.waitForTimeout(100)
        await page.evaluate(() => document.dispatchEvent(new Event('touchend')))
        await page.waitForTimeout(250)
        assert.equal(await page.evaluate(() => getSelection().toString()), text, 'scrolling never changes endpoints')
        if (platform === 'Android') {
            assert.notEqual(await page.evaluate(() => getComputedStyle(document.getElementById('article-content')).position),
                'fixed', 'offscreen native handles must not keep the content pinned between swipes')
        }
        const end = direction > 0
        const handle = page.locator(`[data-readflex-selection-handles] button[data-endpoint="${end ? 'end' : 'start'}"]`)
        assert.equal(await handle.isVisible(), true)
        assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 1)
        const box = await handle.boundingBox()
        assert.ok(box.y >= 64, 'the touch target stays below the system status area')
        assert.ok(box.y + box.height <= 844 - 34, 'the touch target stays above system navigation')
        const fixed = await page.evaluate(end => {
            const r = getSelection().getRangeAt(0)
            return { id: (end ? r.startContainer : r.endContainer).parentElement.id,
                offset: end ? r.startOffset : r.endOffset }
        }, end)
        await page.mouse.move(box.x + 24, box.y + 24)
        await page.mouse.down()
        assert.equal(await page.evaluate(() => getSelection().toString()), text, 'grabbing alone does not expand selection')
        const destination = await page.evaluate(direction => {
            const node = document.querySelector(`#p${direction > 0 ? 55 : 15}`).firstChild
            const r = document.createRange(); r.setStart(node, 14); r.setEnd(node, 19)
            const rect = r.getBoundingClientRect()
            return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
        }, direction)
        await page.mouse.move(destination.x, destination.y, { steps: 12 })
        await page.waitForTimeout(100)
        const during = await page.evaluate(() => scrollY)
        await page.evaluate(() => scrollBy(0, 2000))
        await page.waitForTimeout(100)
        assert.equal(await page.evaluate(() => scrollY), during, 'continuation drag cannot autoscroll')
        await page.mouse.up()
        await page.waitForTimeout(250)
        const result = await page.evaluate(end => {
            const r = getSelection().getRangeAt(0)
            return { id: (end ? r.startContainer : r.endContainer).parentElement.id,
                offset: end ? r.startOffset : r.endOffset, text: r.toString(),
                payload: getCurrentTextSelection().text,
                phase: window.bridgeCalls.filter(([name]) => name === 'onSelectionInteractionChanged').at(-1)?.[1] }
        }, end)
        assert.equal(result.id, fixed.id)
        assert.equal(result.offset, fixed.offset)
        assert.ok(result.text.length > text.length)
        assert.equal(result.payload, result.text.replace(/\s+/g, ' ').trim())
        assert.equal(result.phase, false)

        // Returning toward the origin can shrink and cross the fixed boundary.
        // A scroll itself must never add or remove selected text.
        await contentSwipe(page, await page.evaluate(() =>
            document.querySelector('#p35').getBoundingClientRect().top + scrollY - 400))
        await page.waitForTimeout(100)
        await page.evaluate(() => document.dispatchEvent(new Event('touchend')))
        await page.waitForTimeout(250)
        assert.equal(await page.evaluate(() => getSelection().getRangeAt(0).toString()), result.text)
        const returnBox = await handle.boundingBox()
        assert.ok(returnBox)
        const cross = await page.evaluate(end => {
            const node = document.querySelector('#p35').firstChild
            const r = document.createRange()
            r.setStart(node, end ? 10 : 23); r.setEnd(node, end ? 11 : 24)
            const rect = r.getBoundingClientRect()
            return { x: rect.left, y: rect.top + rect.height / 2 }
        }, end)
        await page.mouse.move(returnBox.x + 24, returnBox.y + 24)
        await page.mouse.down()
        await page.mouse.move(cross.x, cross.y, { steps: 12 })
        await page.waitForTimeout(100)
        await page.mouse.up()
        await page.waitForTimeout(250)
        const reversed = await page.evaluate(end => {
            const r = getSelection().getRangeAt(0)
            return { id: (end ? r.endContainer : r.startContainer).parentElement.id,
                offset: end ? r.endOffset : r.startOffset, text: r.toString() }
        }, end)
        assert.equal(reversed.id, fixed.id)
        assert.equal(reversed.offset, fixed.offset, 'the opposite endpoint survives crossing and role reversal')
        assert.ok(reversed.text.length > 0 && reversed.text.length < result.text.length)
        // Cancel must remove both proxies and all stale-selection action state.
        await page.evaluate(() => clearSelectionAfterTextAction())
        await page.waitForTimeout(250)
        assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 0)
        assert.equal(await page.evaluate(() => getCurrentTextSelection()), null)
        assert.equal(await page.evaluate(() => document.getElementById('article-content').style.position), '')
        assert.equal(await page.evaluate(() => document.body.style.height), '')
    })
}

test('article publishes only settled selection changes and reads live text for immediate actions', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', '<p id="text">Several words in a longer sentence for selecting.</p>')
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(async () => {
        const node = document.querySelector('#text').firstChild
        for (let i = 2; i < 30; i++) {
            getSelection().setBaseAndExtent(node, 0, node, i)
            await new Promise(resolve => setTimeout(resolve, 5))
        }
    })
    assert.equal(await page.evaluate(() => window.bridgeCalls.filter(([name]) => name === 'onSelectionEnd').length), 0)
    assert.equal(await page.evaluate(() => getCurrentTextSelection().text),
        'Several words in a longer sentence for selecting.'.slice(0, 29))
    await page.waitForTimeout(250)
    assert.equal(await page.evaluate(() => window.bridgeCalls.filter(([name]) => name === 'onSelectionEnd').length), 1)
})

test('Android pins once per adjustment without changing layout, range, or original inline styles', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    await page.addInitScript(() => Object.defineProperty(navigator, 'userAgent', { value: 'Android' }))
    routes.set('/article-content', Array.from({ length: 100 }, (_, i) =>
        `<p id="p${i}">Several words in a longer sentence for selecting across screens.</p>`).join(''))
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => document.fonts.ready)
    await page.evaluate(() => {
        document.body.style.setProperty('height', '12000px', 'important')
        const root = document.getElementById('article-content')
        root.style.position = 'relative'
        root.style.top = '0px'
        goToHref('#p30')
    })
    await page.waitForTimeout(100)
    const before = await page.evaluate(() => ({ y: scrollY,
        height: document.documentElement.scrollHeight, top: document.querySelector('#p31').getBoundingClientRect().top }))
    await page.evaluate(() => {
        const node = document.querySelector('#p31').firstChild
        getSelection().setBaseAndExtent(node, 0, node, 7)
    })
    await page.waitForTimeout(250)
    assert.deepEqual(await page.evaluate(() => ({ y: scrollY,
        height: document.documentElement.scrollHeight, top: document.querySelector('#p31').getBoundingClientRect().top })), before)
    await page.evaluate(async () => {
        window.pinMutations = 0
        const observer = new MutationObserver(records => { window.pinMutations += records.length })
        observer.observe(document.body, { attributes: true, attributeFilter: ['style'] })
        observer.observe(document.getElementById('article-content'), { attributes: true, attributeFilter: ['style'] })
        const node = document.querySelector('#p31').firstChild
        for (let i = 8; i < 30; i++) {
            getSelection().setBaseAndExtent(node, 0, node, i)
            await new Promise(resolve => setTimeout(resolve, 5))
        }
        observer.disconnect()
    })
    assert.equal(await page.evaluate(() => window.pinMutations), 0, 'handle movement must not repeatedly rewrite layout styles')
    await page.evaluate(() => clearSelectionAfterTextAction())
    await page.waitForTimeout(250)
    assert.deepEqual(await page.evaluate(() => ({ position: document.getElementById('article-content').style.position,
        top: document.getElementById('article-content').style.top, height: document.body.style.height,
        priority: document.body.style.getPropertyPriority('height'), y: scrollY })),
    { position: 'relative', top: '0px', height: '12000px', priority: 'important', y: before.y })
})

test('Android repeated scroll gestures and redundant selection events never repin an ongoing swipe', async t => {
    const { page, routes, articleUrl } = await createHarness(t)
    await page.addInitScript(() => Object.defineProperty(navigator, 'userAgent', { value: 'Android' }))
    routes.set('/article-content', Array.from({ length: 100 }, (_, i) =>
        `<p id="p${i}">Text for selection, separate scrolling and returning to either boundary.</p>`).join(''))
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => document.fonts.ready)
    await page.evaluate(() => {
        const node = document.querySelector('#p2').firstChild
        getSelection().setBaseAndExtent(node, 0, node, 4)
    })
    await page.waitForTimeout(250)
    for (const target of [400, 800, 1200, 1600, 1200, 800, 400, 0]) {
        await contentSwipe(page, target)
        await page.evaluate(() => document.dispatchEvent(new Event('selectionchange')))
        await page.waitForTimeout(200)
        assert.notEqual(await page.evaluate(() => getComputedStyle(document.getElementById('article-content')).position),
            'fixed', 'a redundant selection event cannot interrupt a content gesture')
        assert.equal(await page.evaluate(() => scrollY), target)
        assert.equal(await page.evaluate(() => getSelection().toString()), 'Text')
        await page.evaluate(() => document.dispatchEvent(new Event('touchend')))
        await page.waitForTimeout(250)
    }
    assert.equal(await page.evaluate(() => getComputedStyle(document.getElementById('article-content')).position),
        'fixed', 'returning to a visible native endpoint restores the drag guard')
})
