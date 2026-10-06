import test from 'node:test'
import assert from 'node:assert/strict'
import { openComic, pointer } from './harness.mjs'

const PREVIEW_ID = '__readflex-image-area-preview'

// Geometry of the draft rectangle and its corner drag zones, in screen px.
const draft = page => page.evaluate(id => {
    const renderer = window.reader.view.renderer
    const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
    const frame = doc.defaultView.frameElement
    const frameRect = frame.getBoundingClientRect()
    const scale = frameRect.width / frame.clientWidth
    const toScreen = r => ({
        left: frameRect.left + r.left * scale, top: frameRect.top + r.top * scale,
        right: frameRect.left + r.right * scale, bottom: frameRect.top + r.bottom * scale,
        width: r.width * scale, height: r.height * scale,
    })
    const preview = doc.getElementById(id)
    if (!preview) return null
    const border = parseFloat(doc.defaultView.getComputedStyle(preview).borderLeftWidth) * scale
    const handles = Array.from(preview.querySelectorAll('[data-image-area-handle]'), marker => {
        const style = doc.defaultView.getComputedStyle(marker)
        const mark = marker.querySelector('[data-image-area-corner-mark]')
        const markStyle = mark ? doc.defaultView.getComputedStyle(mark) : null
        return {
            handle: marker.dataset.imageAreaHandle,
            rect: toScreen(marker.getBoundingClientRect()),
            background: style.backgroundColor,
            mark: mark ? {
                rect: toScreen(mark.getBoundingClientRect()),
                top: parseFloat(markStyle.borderTopWidth), left: parseFloat(markStyle.borderLeftWidth),
                right: parseFloat(markStyle.borderRightWidth), bottom: parseFloat(markStyle.borderBottomWidth),
                pointerEvents: markStyle.pointerEvents,
            } : null,
        }
    })
    return { scale, rect: toScreen(preview.getBoundingClientRect()), border, handles,
        selections: window.bridgeCalls.filter(([name]) => name === 'onImageAreaSelected').map(([, value]) => value.rect) }
}, PREVIEW_ID)

const within = (inner, outer, slack = 0.5) =>
    inner.left >= outer.left - slack && inner.top >= outer.top - slack &&
    inner.right <= outer.right + slack && inner.bottom <= outer.bottom + slack

async function longPress(page, x, y) {
    await pointer(page, 'pointerdown', x, y)
    await page.waitForTimeout(360)
    await pointer(page, 'pointerup', x, y)
    await page.waitForFunction(id => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return Boolean(doc.getElementById(id))
    }, PREVIEW_ID)
}

const centreOf = rect => ({ x: (rect.left + rect.right) / 2, y: (rect.top + rect.bottom) / 2 })

async function drag(page, from, dx, dy) {
    await pointer(page, 'pointerdown', from.x, from.y)
    await pointer(page, 'pointermove', from.x + dx, from.y + dy)
    await pointer(page, 'pointerup', from.x + dx, from.y + dy)
    await page.waitForTimeout(50)
}

test('long press draws a draft whose corner zones are large, transparent and inside the rectangle', async t => {
    const { page } = await openComic(t)
    await longPress(page, 195, 422)
    const before = await draft(page)
    assert.ok(before, 'preview element exists')
    assert.equal(before.handles.length, 4)
    assert.deepEqual(before.handles.map(h => h.handle).sort(), ['ne', 'nw', 'se', 'sw'])
    const expected = Math.min(64, before.rect.width * 0.4, before.rect.height * 0.4)
    assert.ok(expected > 24, `zones stay usable on the default rectangle (${expected}px)`)
    assert.ok(Math.abs(before.border - 6) < 0.5, `border is 6 screen px (${before.border})`)
    for (const handle of before.handles) {
        assert.ok(within(handle.rect, before.rect), `${handle.handle} zone is inside the rectangle`)
        assert.ok(Math.abs(handle.rect.width - expected) < 1.5, `${handle.handle} width ${handle.rect.width} ≈ ${expected}`)
        assert.ok(Math.abs(handle.rect.height - expected) < 1.5, `${handle.handle} height ${handle.rect.height} ≈ ${expected}`)
        assert.equal(handle.background, 'rgba(0, 0, 0, 0)', 'zone is transparent')
        assert.ok(handle.mark, 'corner mark exists')
        assert.ok(within(handle.mark.rect, handle.rect), 'mark sits inside its zone')
        assert.equal(handle.mark.pointerEvents, 'none')
        const strokes = [handle.mark.top, handle.mark.right, handle.mark.bottom, handle.mark.left]
        assert.equal(strokes.filter(width => width > 0).length, 2, 'mark is an L of two strokes')
        assert.equal(handle.mark.top > 0, handle.handle.includes('n'))
        assert.equal(handle.mark.left > 0, handle.handle.includes('w'))
    }
    // Opposite zones never overlap, so the centre still moves the rectangle.
    const nw = before.handles.find(h => h.handle === 'nw').rect
    const se = before.handles.find(h => h.handle === 'se').rect
    assert.ok(nw.right < se.left && nw.bottom < se.top)
    assert.ok(before.selections.length >= 1, 'the draft was reported to Flutter')
})

test('dragging a corner zone resizes and dragging the centre moves the draft', async t => {
    const { page } = await openComic(t)
    await longPress(page, 195, 422)
    const before = await draft(page)
    await drag(page, centreOf(before.handles.find(h => h.handle === 'se').rect), 30, 24)
    const resized = await draft(page)
    assert.ok(Math.abs(resized.rect.width - before.rect.width - 30) < 2, `width grew by 30 (${resized.rect.width - before.rect.width})`)
    assert.ok(Math.abs(resized.rect.height - before.rect.height - 24) < 2, `height grew by 24 (${resized.rect.height - before.rect.height})`)
    assert.ok(Math.abs(resized.rect.left - before.rect.left) < 1, 'resizing from the corner keeps the opposite edge')
    for (const handle of resized.handles) assert.ok(within(handle.rect, resized.rect), `${handle.handle} inside after resize`)
    assert.ok(resized.selections.at(-1).width > before.selections.at(-1).width, 'Flutter receives the enlarged rectangle')

    await drag(page, centreOf(resized.rect), 20, -10)
    const moved = await draft(page)
    assert.ok(Math.abs(moved.rect.left - resized.rect.left - 20) < 2, 'moved right by 20')
    assert.ok(Math.abs(moved.rect.top - resized.rect.top + 10) < 2, 'moved up by 10')
    assert.ok(Math.abs(moved.rect.width - resized.rect.width) < 1, 'moving keeps the size')
})

test('corner zones are sized in screen pixels regardless of the page scale', async t => {
    const { page } = await openComic(t)
    await longPress(page, 195, 422)
    const before = await draft(page)
    // Enlarge until the 64px screen target, not the rectangle, is the limit.
    await drag(page, centreOf(before.handles.find(h => h.handle === 'se').rect), 160, 200)
    const large = await draft(page)
    assert.ok(large.scale < 1, `comic page is scaled down (${large.scale})`)
    for (const handle of large.handles) {
        assert.ok(Math.abs(handle.rect.width - 64) < 1.5, `${handle.handle} is 64 screen px wide (${handle.rect.width})`)
        assert.ok(Math.abs(handle.rect.height - 64) < 1.5)
        assert.ok(Math.abs(handle.mark.rect.width - 22) < 1.5, `corner mark is 22 screen px (${handle.mark.rect.width})`)
    }
})

test('finger jitter during the long press is tolerated in screen pixels', async t => {
    const { page } = await openComic(t)
    const hasDraft = () => page.evaluate(id => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return Boolean(doc.getElementById(id))
    }, PREVIEW_ID)
    // 8 screen px of drift is more than 10 document px on a scaled page, yet
    // must still count as a hold.
    await pointer(page, 'pointerdown', 195, 422)
    await page.waitForTimeout(120)
    await pointer(page, 'pointermove', 203, 428)
    await page.waitForTimeout(300)
    await pointer(page, 'pointerup', 203, 428)
    assert.equal(await hasDraft(), true, 'small drift keeps the press alive')
    await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        doc.__readflexClearImageAreaSelectionDraft?.({ allowNextTap: true })
    })
    await page.waitForTimeout(1000)
    // A real drag of 24 screen px cancels it. Move right after the press so
    // a loaded machine cannot let the 280 ms hold fire first.
    await pointer(page, 'pointerdown', 195, 422)
    await pointer(page, 'pointermove', 219, 422)
    await page.waitForTimeout(300)
    await pointer(page, 'pointerup', 219, 422)
    assert.equal(await hasDraft(), false, 'a drag past the tolerance cancels the press')
})
