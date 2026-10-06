import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
    getFontFamilyToken,
    isVariableFontPath,
    readerFontFaceCSS,
    readerFontFamilyChain,
    symbolFontFaceCSS,
    symbolFontFamily,
    symbolFontURL,
} from '../assets/foliate-js/src/readflex_reader_fonts.js'

const articleShell = readFileSync(new URL('../assets/article-html/index.html', import.meta.url), 'utf8')
const bookShell = readFileSync(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8')

test('every reading family chains the bundled symbol fallback', () => {
    assert.equal(readerFontFamilyChain('Literata'), '"Literata", "Noto Sans Symbols"')
    assert.equal(readerFontFamilyChain('system'), 'system-ui, "Noto Sans Symbols"')
    assert.equal(readerFontFamilyChain('serif'), 'serif, "Noto Sans Symbols"')
    assert.equal(readerFontFamilyChain('PT "Serif"'), '"PT \\"Serif\\"", "Noto Sans Symbols"')
    assert.equal(getFontFamilyToken('Geist'), '"Geist"')
})

test('symbol font face resolves next to the extracted reader assets', () => {
    assert.ok(symbolFontURL.endsWith('/assets/fonts/NotoSansSymbols-Regular.ttf'))
    const css = symbolFontFaceCSS()
    assert.match(css, /font-family: "Noto Sans Symbols";/)
    assert.ok(css.includes(`url('${symbolFontURL}')`))
    assert.equal(symbolFontFamily, 'Noto Sans Symbols')
})

test('variable fonts declare the weight axis; static faces keep synthesized bold', () => {
    for (const file of ['Literata-Variable.ttf', 'OpenSans-Variable.ttf', 'Geist-Variable.ttf']) {
        const path = `http://127.0.0.1:1/r/t/assets/fonts/${file}`
        assert.equal(isVariableFontPath(path), true, file)
        const css = readerFontFaceCSS({ fontName: 'Family', fontPath: path })
        assert.match(css, /font-weight: 100 900;/, file)
        assert.match(css, /font-display: swap;/)
        assert.ok(css.includes(`url('${path}')`))
    }
    const staticCss = readerFontFaceCSS({
        fontName: 'PT Serif', fontPath: 'http://127.0.0.1:1/r/t/assets/fonts/PTSerif-Regular.ttf',
    })
    assert.doesNotMatch(staticCss, /font-weight/)
    assert.match(staticCss, /font-family: "PT Serif";/)
})

test('publisher and system presets declare no reader face', () => {
    assert.equal(readerFontFaceCSS({ fontName: 'book', fontPath: 'x' }), '')
    assert.equal(readerFontFaceCSS({ fontName: 'system', fontPath: 'x' }), '')
    assert.equal(readerFontFaceCSS({ fontName: 'Literata', fontPath: '' }), '')
    assert.equal(readerFontFaceCSS(), '')
})

test('both shells build their font prelude from the shared helpers', () => {
    for (const [name, source] of [['article', articleShell], ['book', bookShell]]) {
        assert.ok(source.includes("readflex_reader_fonts.js"), name)
        assert.ok(source.includes('readerFontFaceCSS('), name)
        assert.ok(source.includes('readerFontFamilyChain('), name)
        assert.ok(source.includes('symbolFontFaceCSS()'), name)
        assert.ok(!source.includes("'Noto Sans Symbols'"), `${name} must not redeclare the symbol family`)
        assert.ok(!/font-weight:\s*100 900/.test(source), `${name} must not hard-code the weight axis`)
    }
})
