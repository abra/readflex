import test from 'node:test'
import assert from 'node:assert/strict'
import {
    AUTO_SPREAD_MIN_MEASURE,
    pageColumnCount,
    pageColumnLayout,
} from '../assets/foliate-js/src/readflex_page_columns.js'

// Foliate's default --_max-inline-size, used when no measure is set.
const UPSTREAM_MAX_INLINE = 720
// Readflex's 32em measure at 18px body text.
const MEASURE = 32 * 18

// The gap foliate derives from an 8% side margin: -g / (g - 1) * size.
const gapFor = size => 0.08 / 0.92 * size

const page = ({ width, height, maxColumnCount, measure = null, gap }) => ({
    width,
    height,
    size: width,
    gap: gap ?? gapFor(width),
    maxColumnCount,
    maxInlineSize: measure ?? UPSTREAM_MAX_INLINE,
    measure,
})

const close = (actual, expected, message) =>
    assert.ok(Math.abs(actual - expected) < 1e-6, `${message}: ${actual} != ${expected}`)

const assertFillsPage = (layout, size) =>
    close(layout.columns * (layout.columnWidth + layout.gap), size, 'columns fill the page')

test('a phone without a measure keeps one column across the page', () => {
    for (const [width, height] of [[390, 844], [320, 568], [844, 390], [932, 430]]) {
        const input = page({ width, height, maxColumnCount: 1 })
        const layout = pageColumnLayout(input)
        assert.equal(layout.columns, 1, `${width}x${height}`)
        close(layout.gap, input.gap, `${width}x${height} gap`)
        close(layout.columnWidth, width - input.gap, `${width}x${height} width`)
        assertFillsPage(layout, width)
    }
})

test('without a measure Auto keeps upstream foliate behaviour', () => {
    assert.equal(pageColumnCount(page({ width: 700, height: 900, maxColumnCount: 0 })), 1)
    assert.equal(pageColumnCount(page({ width: 1032, height: 1376, maxColumnCount: 0 })), 2)
    const layout = pageColumnLayout(page({ width: 1376, height: 1032, maxColumnCount: 0 }))
    assert.equal(layout.columns, 2)
    close(layout.gap, gapFor(1376), 'gap stays the side margin')
})

test('Auto shows one capped column on a portrait tablet', () => {
    const input = page({ width: 1032, height: 1376, maxColumnCount: 0, measure: MEASURE })
    const layout = pageColumnLayout(input)
    assert.equal(layout.columns, 1)
    close(layout.columnWidth, MEASURE, 'column keeps the measure')
    close(layout.gap, 1032 - MEASURE, 'margins take the rest')
    assertFillsPage(layout, 1032)
})

test('Auto shows a spread on a landscape tablet', () => {
    for (const [width, height] of [[1376, 1032], [1194, 834], [1133, 744]]) {
        const input = page({ width, height, maxColumnCount: 0, measure: MEASURE })
        const layout = pageColumnLayout(input)
        assert.equal(layout.columns, 2, `${width}x${height}`)
        assert.ok(layout.columnWidth <= MEASURE, `${width}x${height} stays within the measure`)
        assert.ok(
            layout.columnWidth >= MEASURE * AUTO_SPREAD_MIN_MEASURE,
            `${width}x${height} keeps a readable page`,
        )
        assertFillsPage(layout, width)
    }
})

test('Auto falls back to one column when spread pages would be too narrow', () => {
    // 200% text doubles the measure; two pages would hold ~30 characters.
    const largeText = page({ width: 1376, height: 1032, maxColumnCount: 0, measure: MEASURE * 2 })
    assert.equal(pageColumnCount(largeText), 1)
    // A short landscape window, such as Stage Manager.
    const shortWindow = page({ width: 860, height: 600, maxColumnCount: 0, measure: MEASURE })
    assert.equal(pageColumnCount(shortWindow), 1)
})

test('the spread threshold is inclusive', () => {
    const width = 1376
    const gap = width / 2 - MEASURE * AUTO_SPREAD_MIN_MEASURE
    const edge = page({ width, height: 1032, maxColumnCount: 0, measure: MEASURE, gap })
    assert.equal(pageColumnCount(edge), 2)
    assert.equal(pageColumnCount({ ...edge, gap: gap + 1 }), 1)
})

test('a square page is not landscape', () => {
    assert.equal(
        pageColumnCount(page({ width: 1100, height: 1100, maxColumnCount: 0, measure: MEASURE })),
        1,
    )
})

test('exact counts ignore orientation and keep the measure', () => {
    const one = pageColumnLayout(page({ width: 1376, height: 1032, maxColumnCount: 1, measure: MEASURE }))
    assert.equal(one.columns, 1)
    close(one.columnWidth, MEASURE, 'One keeps the measure in landscape')
    assertFillsPage(one, 1376)

    const two = pageColumnLayout(page({ width: 1032, height: 1376, maxColumnCount: 2, measure: MEASURE }))
    assert.equal(two.columns, 2)
    assert.ok(two.columnWidth < MEASURE)
    close(two.gap, gapFor(1032), 'Two keeps the side margin when columns fit')
    assertFillsPage(two, 1032)
})

test('a measure wider than the column leaves the side margin alone', () => {
    const input = page({ width: 900, height: 1200, maxColumnCount: 1, measure: 2000 })
    const layout = pageColumnLayout(input)
    close(layout.gap, input.gap, 'gap')
    close(layout.columnWidth, 900 - input.gap, 'width')
})

test('a very wide spread caps both pages and widens the gutter', () => {
    const layout = pageColumnLayout(page({ width: 2560, height: 1440, maxColumnCount: 0, measure: MEASURE }))
    assert.equal(layout.columns, 2)
    close(layout.columnWidth, MEASURE, 'each page keeps the measure')
    close(layout.gap, 1280 - MEASURE, 'gutter')
    assertFillsPage(layout, 2560)
})

test('a height-only change keeps the Auto decision', () => {
    // The keyboard opening over a portrait tablet shrinks the page's height
    // below its width.
    const portraitPage = page({ width: 1032, height: 1376, maxColumnCount: 0, measure: MEASURE })
    const first = pageColumnLayout(portraitPage)
    assert.equal(first.columns, 1)
    assert.deepEqual(first.auto, { width: 1032, measure: MEASURE, gap: portraitPage.gap, columns: 1 })
    const keyboard = pageColumnLayout({ ...portraitPage, height: 700, previous: first.auto })
    assert.equal(keyboard.columns, 1, 'no spread while searching')

    const landscapePage = page({ width: 1376, height: 1032, maxColumnCount: 0, measure: MEASURE })
    const spread = pageColumnLayout(landscapePage)
    assert.equal(spread.columns, 2)
    assert.equal(
        pageColumnLayout({ ...landscapePage, height: 500, previous: spread.auto }).columns,
        2,
        'the spread stays while the keyboard is up',
    )
})

test('width, measure and margin changes decide Auto again', () => {
    const portraitPage = page({ width: 1032, height: 1376, maxColumnCount: 0, measure: MEASURE })
    const previous = pageColumnLayout(portraitPage).auto
    // Rotation.
    const rotated = page({ width: 1376, height: 1032, maxColumnCount: 0, measure: MEASURE })
    assert.equal(pageColumnCount({ ...rotated, previous }), 2)
    // Larger text at the same width.
    const landscape = pageColumnLayout(rotated)
    assert.equal(pageColumnCount({ ...rotated, measure: MEASURE * 2, previous: landscape.auto }), 1)
    // Wider margins at the same width.
    assert.equal(
        pageColumnCount({ ...rotated, gap: rotated.size / 2 - 1, previous: landscape.auto }),
        1,
    )
})

test('exact counts and pages without a measure keep no Auto decision', () => {
    assert.equal(pageColumnLayout(page({ width: 1376, height: 1032, maxColumnCount: 1, measure: MEASURE })).auto, null)
    assert.equal(pageColumnLayout(page({ width: 390, height: 844, maxColumnCount: 1 })).auto, null)
    assert.equal(pageColumnLayout(page({ width: 1376, height: 1032, maxColumnCount: 0 })).auto, null)
})
