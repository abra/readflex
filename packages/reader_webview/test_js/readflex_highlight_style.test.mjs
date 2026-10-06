import test from 'node:test'
import assert from 'node:assert/strict'
import {
    highlightDrawOptions,
    parseHexColor,
    premixHighlightColor,
} from '../assets/foliate-js/src/readflex_highlight_style.js'
import {
    READFLEX_HIGHLIGHT_OPACITY,
    READFLEX_HIGHLIGHT_RADIUS,
    READFLEX_HIGHLIGHT_VERTICAL_INSET,
} from '../assets/foliate-js/src/readflex_shell_constants.js'

test('draw options apply the shared fallbacks and pass Flutter values through', () => {
    assert.deepEqual(highlightDrawOptions({ color: '#FFE600' }), {
        color: '#FFE600',
        opacity: READFLEX_HIGHLIGHT_OPACITY,
        mixBlendMode: 'normal',
        verticalOffset: 0,
        radius: READFLEX_HIGHLIGHT_RADIUS,
        verticalInset: READFLEX_HIGHLIGHT_VERTICAL_INSET,
    })
    assert.deepEqual(highlightDrawOptions({
        color: '#1E90FF', opacity: 0.72, mixBlendMode: 'lighten', verticalOffset: 2,
    }), {
        color: '#1E90FF',
        opacity: 0.72,
        mixBlendMode: 'lighten',
        verticalOffset: 2,
        radius: READFLEX_HIGHLIGHT_RADIUS,
        verticalInset: READFLEX_HIGHLIGHT_VERTICAL_INSET,
    })
})

test('invalid payload values fall back instead of leaking into CSS', () => {
    const options = highlightDrawOptions({
        color: 'red; background: url(x)', opacity: 'NaN', mixBlendMode: 'difference', verticalOffset: 'x',
    })
    assert.equal(options.color, '#FFE600')
    assert.equal(options.opacity, READFLEX_HIGHLIGHT_OPACITY)
    assert.equal(options.mixBlendMode, 'normal')
    assert.equal(options.verticalOffset, 0)
    assert.equal(highlightDrawOptions({ opacity: 4 }).opacity, 1)
    assert.equal(highlightDrawOptions({ opacity: -1 }).opacity, 0)
    assert.equal(highlightDrawOptions(null).color, '#FFE600')
})

test('hex parsing accepts short, long and alpha forms only', () => {
    assert.deepEqual(parseHexColor('#fff'), [255, 255, 255])
    assert.deepEqual(parseHexColor('#FFE600'), [255, 230, 0])
    assert.deepEqual(parseHexColor('#FFE600cc'), [255, 230, 0])
    assert.equal(parseHexColor('rgb(1,2,3)'), null)
    assert.equal(parseHexColor(''), null)
    assert.equal(parseHexColor(undefined), null)
})

test('premixed colour matches the overlay blend on light and dark pages', () => {
    // multiply over white: 0.82 * (255,230,0) + 0.18 * white
    assert.equal(premixHighlightColor({ color: '#FFE600', opacity: 0.82, mixBlendMode: 'multiply' }, '#ffffff'),
        'rgb(255,235,46)')
    // lighten over near-black: 0.72 * max(color, page) + 0.28 * page
    assert.equal(premixHighlightColor({ color: '#FFE600', opacity: 0.72, mixBlendMode: 'lighten' }, '#121212'),
        'rgb(189,171,18)')
    // normal blend is plain alpha compositing
    assert.equal(premixHighlightColor({ color: '#0000FF', opacity: 0.5 }, '#ffffff'), 'rgb(128,128,255)')
    // multiply with a dark page darkens instead of washing out
    assert.equal(premixHighlightColor({ color: '#FFE600', opacity: 1, mixBlendMode: 'multiply' }, '#202020'),
        'rgb(32,29,0)')
})

test('an unparsable page background keeps the translucent fallback', () => {
    assert.equal(premixHighlightColor({ color: '#FFE600', opacity: 0.5 }, 'transparent'), 'rgba(255,230,0,0.5)')
    assert.equal(premixHighlightColor({ color: '#FFE600' }, undefined), `rgba(255,230,0,${READFLEX_HIGHLIGHT_OPACITY})`)
})
