import test from 'node:test'
import assert from 'node:assert/strict'
import {
    pageColorsFor,
    parseHexColor,
    relativeLuminance,
    samePageColors,
} from '../assets/foliate-js/src/readflex_page_colors.js'

test('hex colors parse in short and long form and reject everything else', () => {
    assert.deepEqual(parseHexColor('#FAF8F4'), [250, 248, 244])
    assert.deepEqual(parseHexColor(' #0f1 '), [0, 255, 17])
    for (const value of ['FAF8F4', '#12345', 'rgb(0,0,0)', null, undefined]) {
        assert.equal(parseHexColor(value), null, String(value))
    }
})

test('luminance follows WCAG', () => {
    assert.equal(relativeLuminance([255, 255, 255]), 1)
    assert.equal(relativeLuminance([0, 0, 0]), 0)
    assert.ok(Math.abs(relativeLuminance([128, 128, 128]) - 0.2158605) < 1e-6)
})

test('original colors and white paper keep the page as published', () => {
    assert.equal(pageColorsFor({ mode: 'original', backgroundColor: '#0F1115', fontColor: '#BCC1CA' }), null)
    assert.equal(pageColorsFor({ mode: undefined, backgroundColor: '#0F1115', fontColor: '#BCC1CA' }), null)
    assert.equal(pageColorsFor({ mode: 'theme', backgroundColor: '#FFFFFF', fontColor: '#242424' }), null)
    assert.equal(pageColorsFor({ mode: 'theme', backgroundColor: 'transparent', fontColor: '#000' }), null)
})

test('light themes tint paper and dark themes invert into the theme colors', () => {
    assert.deepEqual(pageColorsFor({ mode: 'theme', backgroundColor: '#F3E4CF', fontColor: '#33261B' }),
        { background: 'rgb(243, 228, 207)', foreground: 'rgb(51, 38, 27)', dark: false })
    assert.deepEqual(pageColorsFor({ mode: 'theme', backgroundColor: '#242830', fontColor: '#ABB2BF' }),
        { background: 'rgb(36, 40, 48)', foreground: 'rgb(171, 178, 191)', dark: true })
    // An unreadable text color falls back to plain black or white ink.
    assert.equal(pageColorsFor({ mode: 'theme', backgroundColor: '#0F1115', fontColor: 'x' }).foreground,
        'rgb(255, 255, 255)')
})

test('page colors compare by value', () => {
    const a = pageColorsFor({ mode: 'theme', backgroundColor: '#242830', fontColor: '#ABB2BF' })
    const b = pageColorsFor({ mode: 'theme', backgroundColor: '#242830', fontColor: '#ABB2BF' })
    assert.equal(samePageColors(a, b), true)
    assert.equal(samePageColors(null, null), true)
    assert.equal(samePageColors(a, null), false)
    assert.equal(samePageColors(a, { ...b, dark: false }), false)
})
