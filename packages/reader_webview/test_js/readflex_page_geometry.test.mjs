import test from 'node:test'
import assert from 'node:assert/strict'
import {
    CONTENT_CROP_PADDING,
    MAX_TILE_PIXELS,
    TILE_MARGIN,
    contentCrop,
    sharpenRegion,
    tileCovers,
    tileFor,
} from '../assets/foliate-js/src/readflex_page_geometry.js'

// A4 in page pixels (points × 2) on a 390 × 844 phone.
const page = { width: 1190, height: 1684 }
const phone = { availableWidth: 390, availableHeight: 844 }
const close = (actual, expected, message) =>
    assert.ok(Math.abs(actual - expected) < 1e-6, `${message}: ${actual} != ${expected}`)

test('crop follows the ink horizontally and keeps the full height a tall screen can show', () => {
    const content = { left: 150, top: 200, right: 1040, bottom: 1500 }
    const crop = contentCrop({ ...page, content, ...phone })
    const padX = page.width * CONTENT_CROP_PADDING
    close(crop.left, 150 - padX, 'left')
    close(crop.right, 1040 + padX, 'right')
    // The phone is taller than the cropped page, so no height is cut.
    assert.equal(crop.top, 0)
    assert.equal(crop.bottom, page.height)
})

test('narrow ink fills the phone aspect from the ink top', () => {
    const content = { left: 300, top: 200, right: 900, bottom: 900 }
    const crop = contentCrop({ ...page, content, ...phone })
    const width = crop.right - crop.left
    close((crop.bottom - crop.top) / width, 844 / 390, 'aspect')
    close(crop.top, 200 - page.height * CONTENT_CROP_PADDING, 'top')
})

test('a short page keeps the scale of full pages and starts at the same top', () => {
    const full = contentCrop({ ...page, ...phone,
        content: { left: 300, top: 200, right: 900, bottom: 1500 } })
    const short = contentCrop({ ...page, ...phone,
        content: { left: 300, top: 200, right: 900, bottom: 420 } })
    close(short.right - short.left, full.right - full.left, 'same width')
    close(short.bottom - short.top, full.bottom - full.top, 'same height')
    close(short.top, full.top, 'same top')
})

test('ink near the bottom shifts the crop up instead of past the page', () => {
    const crop = contentCrop({ ...page, ...phone,
        content: { left: 300, top: 1400, right: 900, bottom: 1650 } })
    assert.equal(crop.bottom, page.height)
    assert.ok(crop.top < 1400)
})

test('ink taller than the screen aspect keeps its own height', () => {
    // Landscape spread: each page gets half of an 844 × 390 screen.
    const content = { left: 150, top: 120, right: 1040, bottom: 1560 }
    const crop = contentCrop({ ...page, content, availableWidth: 422, availableHeight: 390 })
    const padY = page.height * CONTENT_CROP_PADDING
    close(crop.top, 120 - padY, 'top')
    close(crop.bottom, 1560 + padY, 'bottom')
})

test('sparse, blank, full and invalid pages are not cropped', () => {
    const sparse = { left: 400, top: 700, right: 790, bottom: 760 }
    assert.equal(contentCrop({ ...page, ...phone, content: sparse }), null)
    assert.equal(contentCrop({ ...page, ...phone, content: null }), null)
    const bleed = { left: 0, top: 0, right: page.width, bottom: page.height }
    assert.equal(contentCrop({ ...page, ...phone, content: bleed }), null)
    assert.equal(contentCrop({ width: 0, height: 10, ...phone, content: bleed }), null)
})

test('a missing available box crops to the ink with padding only', () => {
    const content = { left: 150, top: 200, right: 1040, bottom: 1500 }
    const crop = contentCrop({ ...page, content, availableWidth: 0, availableHeight: 0 })
    close(crop.bottom, 1500 + page.height * CONTENT_CROP_PADDING, 'bottom')
})

const viewport = { left: 0, top: 0, right: 390, bottom: 844 }

test('a page at fit is sharp enough and needs no tile', () => {
    // 595 pt page fitted to 390 CSS px on a 3x screen, bitmap at that density.
    const frameRect = { left: 0, top: 165, width: 390, height: 552 }
    const visible = { left: 0, top: 0, width: page.width, height: page.height }
    const baseDensity = 390 * 3 / page.width
    assert.equal(sharpenRegion({ frameRect, viewport, visible, baseDensity, devicePixelRatio: 3 }), null)
    // Within the threshold still counts as sharp.
    assert.equal(sharpenRegion({ frameRect, viewport, visible,
        baseDensity: baseDensity / 1.05, devicePixelRatio: 3 }), null)
})

test('a zoomed page maps the visible screen area back to page pixels', () => {
    // Zoomed 2.5x around the page centre; the crop window starts at (100, 50).
    const frameRect = { left: -390, top: -400, width: 975, height: 1380 }
    const visible = { left: 100, top: 50, width: 990, height: 1401 }
    const baseDensity = 390 * 3 / 990
    const region = sharpenRegion({ frameRect, viewport, visible, baseDensity, devicePixelRatio: 3 })
    const cssPerPage = 975 / 990
    close(region.density, cssPerPage * 3, 'density')
    close(region.left, 100 + 390 / cssPerPage, 'left')
    close(region.top, 50 + 400 / cssPerPage, 'top')
    close(region.width, 390 / cssPerPage, 'width')
    close(region.height, 844 / cssPerPage, 'height')
})

test('a page outside the viewport or without size needs no tile', () => {
    const visible = { left: 0, top: 0, width: 100, height: 100 }
    const offscreen = { left: 500, top: 0, width: 400, height: 400 }
    assert.equal(sharpenRegion({ frameRect: offscreen, viewport, visible,
        baseDensity: 1, devicePixelRatio: 3 }), null)
    assert.equal(sharpenRegion({ frameRect: offscreen, viewport,
        visible: { ...visible, width: 0 }, baseDensity: 1 }), null)
})

test('tiles add a pan margin, stay inside the page and keep the density', () => {
    const region = { left: 300, top: 400, width: 400, height: 860, density: 2 }
    const tile = tileFor(region, page)
    assert.equal(tile.density, 2)
    assert.equal(tile.left, Math.floor(300 - 400 * TILE_MARGIN))
    assert.equal(tile.top, Math.floor(400 - 860 * TILE_MARGIN))
    assert.ok(Number.isInteger(tile.width) && Number.isInteger(tile.height))
    const edge = tileFor({ left: 0, top: 1300, width: 600, height: 384, density: 2 }, page)
    assert.equal(edge.left, 0)
    assert.equal(edge.top + edge.height, page.height)
})

test('tiles over budget drop the margin first, then density', () => {
    const region = { left: 300, top: 300, width: 400, height: 860, density: 6 }
    const noMargin = tileFor(region, page, region.width * region.height * 36 * 1.2)
    assert.equal(noMargin.left, 300)
    assert.equal(noMargin.density, 6)
    const reduced = tileFor(region, page)
    assert.ok(reduced.density < 6)
    assert.ok(reduced.width * reduced.height * reduced.density ** 2 <= MAX_TILE_PIXELS + 1)
})

test('a tile covers regions inside it at no more than its density', () => {
    const tile = { left: 100, top: 100, width: 500, height: 900, density: 3 }
    assert.equal(tileCovers(tile, { left: 120, top: 150, width: 400, height: 800, density: 3 }), true)
    assert.equal(tileCovers(tile, { left: 120, top: 150, width: 400, height: 800, density: 3.3 }), false)
    assert.equal(tileCovers(tile, { left: 80, top: 150, width: 400, height: 800, density: 3 }), false)
    assert.equal(tileCovers(null, { left: 0, top: 0, width: 1, height: 1, density: 1 }), false)
})
