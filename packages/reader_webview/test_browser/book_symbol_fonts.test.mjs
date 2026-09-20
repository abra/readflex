import test from 'node:test'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { createHarness } from './harness.mjs'

const symbolFamily = 'Noto Sans Symbols'
const symbolFile = 'NotoSansSymbols-Regular.ttf'
const presets = [
    ['Literata', 'Literata-Variable.ttf'],
    ['PT Serif', 'PTSerif-Regular.ttf'],
    ['Open Sans', 'OpenSans-Variable.ttf'],
    ['Geist', 'Geist-Variable.ttf'],
    ['system', null],
]
const symbols = '\u267e\u267c\u278a'

async function openBook(t, { fontName = 'Literata', fontFile = presets[0][1],
    text = symbols, overrideFont = true } = {}) {
    const { page, origin } = await createHarness(t)
    const fontRequests = []
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    await page.route('**/fonts/*.ttf', async route => {
        const name = new URL(route.request().url()).pathname.split('/').at(-1)
        fontRequests.push(name)
        await route.fulfill({
            contentType: 'font/ttf',
            path: fileURLToPath(new URL(`../../component_library/fonts/${name}`, import.meta.url)),
        })
    })
    const files = {
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">symbols</dc:identifier><dc:title>Symbols</dc:title><dc:language>en</dc:language></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
        'chapter.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Symbols</title>
            <style>.publisher-symbol { font-family: "Segoe UI Symbol", sans-serif; }</style>
            </head><body><p><span id="symbols" class="publisher-symbol">${text}</span></p>
            <p id="prose">Ordinary text 0123456789</p><pre><code id="code">const count = 42;</code></pre>
            </body></html>`,
    }
    // Only transport is stubbed; chapter loading and font CSS are production code.
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() {
                return { isDirectory: true, fullPath: '', createReader: () => ({
                    readEntries: callback => callback(Object.entries(${JSON.stringify(files)}).map(([name, text]) => ({
                        isFile: true, fullPath: '/' + name,
                        file: callback => callback(new File([text], name)),
                    }))),
                }) }
            }
        }`,
    }))
    await page.setViewportSize({ width: 390, height: 844 })
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/symbols.epub'),
        initialProgress: JSON.stringify(0.001),
        style: JSON.stringify({
            pageTurnStyle: 'vertical', allowScript: false, fontName, overrideFont,
            fontPath: fontFile ? origin + '/fonts/' + fontFile : '',
            fontSize: 1.25, textScale: 1, fontWeight: 400, spacing: 1.5,
            fontColor: '#292521', backgroundColor: '#faf8f4',
            topMargin: 24, bottomMargin: 24, sideMargin: 8,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
            customCSSEnabled: true,
            customCSS: 'pre, code { font-family: ui-monospace, Menlo, monospace !important; }',
        }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => window.reader.view.renderer.getContents()[0].doc.fonts.ready.then(() => {}))
    return { page, fontRequests }
}

for (const [fontName, fontFile] of presets) {
    test(`${fontName}: book font stack includes the bundled symbol fallback`, async t => {
        const { page } = await openBook(t, { fontName, fontFile })
        const family = await page.evaluate(() => {
            const { doc } = window.reader.view.renderer.getContents()[0]
            return doc.defaultView.getComputedStyle(doc.getElementById('symbols')).fontFamily
        })
        assert.equal(family.split(',')[0].replaceAll('"', '').trim(),
            fontName === 'system' ? 'system-ui' : fontName)
        assert.ok(family.includes(symbolFamily), family)
    })
}

test('missing glyphs use real bundled font pixels without changing prose or code', async t => {
    const { page, fontRequests } = await openBook(t)
    const result = await page.evaluate(async ({ symbolFamily, symbols }) => {
        const { doc } = window.reader.view.renderer.getContents()[0]
        const styleOf = id => doc.defaultView.getComputedStyle(doc.getElementById(id))
        const canvas = doc.createElementNS('http://www.w3.org/1999/xhtml', 'canvas')
        canvas.width = 600
        canvas.height = 100
        const ctx = canvas.getContext('2d', { willReadFrequently: true })
        const render = (family, text) => {
            ctx.clearRect(0, 0, canvas.width, canvas.height)
            ctx.font = `32px ${family}`
            ctx.fillText(text, 10, 60)
            return ctx.getImageData(0, 0, canvas.width, canvas.height).data
        }
        const same = (a, b) => a.every((value, index) => value === b[index])
        const loaded = [...doc.fonts].some(face => face.family.replaceAll('"', '') === symbolFamily && face.status === 'loaded')
        const glyphs = [...symbols].map(text => {
            const actual = render(styleOf('symbols').fontFamily, text)
            return { text, ink: actual.some(value => value !== 0),
                matchesFallback: same(actual, render(`"${symbolFamily}"`, text)) }
        })
        return {
            loaded, glyphs,
            sameProse: same(render(styleOf('prose').fontFamily, 'Ordinary text 0123456789'),
                render('Literata', 'Ordinary text 0123456789')),
            codeFamily: styleOf('code').fontFamily,
            sameCode: same(render(styleOf('code').fontFamily, 'const count = 42;'),
                render('ui-monospace, Menlo, monospace', 'const count = 42;')),
        }
    }, { symbolFamily, symbols })
    assert.equal(result.loaded, true, 'fallback must be loaded in the chapter, not only in Flutter')
    assert.ok(fontRequests.includes(symbolFile), fontRequests.join(', '))
    for (const glyph of result.glyphs) {
        assert.equal(glyph.ink, true, glyph.text)
        assert.equal(glyph.matchesFallback, true, glyph.text)
    }
    assert.equal(result.sameProse, true)
    assert.equal(result.sameCode, true)
    assert.ok(result.codeFamily.startsWith('ui-monospace'), result.codeFamily)
})

test('a chapter without missing glyphs does not fetch the symbol font', async t => {
    const { fontRequests } = await openBook(t, { text: 'Ordinary text' })
    assert.ok(!fontRequests.includes(symbolFile), fontRequests.join(', '))
})

for (const style of [{ overrideFont: false }, { fontName: 'book' }]) {
    test(`publisher font opt-out is preserved: ${JSON.stringify(style)}`, async t => {
        const { page, fontRequests } = await openBook(t, style)
        const family = await page.evaluate(() => {
            const { doc } = window.reader.view.renderer.getContents()[0]
            return doc.defaultView.getComputedStyle(doc.getElementById('symbols')).fontFamily
        })
        assert.equal(family.split(',')[0].replaceAll('"', '').trim(), 'Segoe UI Symbol')
        assert.ok(!family.includes(symbolFamily), family)
        assert.ok(!fontRequests.includes(symbolFile))
    })
}

test('switching reader fonts preserves text nodes, selection and CFI', async t => {
    const { page } = await openBook(t)
    await page.evaluate(() => {
        const { doc, index } = window.reader.view.renderer.getContents()[0]
        const node = doc.getElementById('symbols').firstChild
        const range = doc.createRange()
        range.selectNodeContents(node)
        doc.getSelection().removeAllRanges()
        doc.getSelection().addRange(range)
        window.symbolTest = { node, text: doc.body.textContent,
            cfi: window.reader.view.getCFI(index, range) }
    })
    for (const fontName of ['system', 'Literata']) {
        const result = await page.evaluate(async fontName => {
            window.changeStyle({ fontName })
            const { doc, index } = window.reader.view.renderer.getContents()[0]
            await doc.fonts.ready
            const selection = doc.getSelection()
            return {
                sameNode: doc.getElementById('symbols').firstChild === window.symbolTest.node,
                sameText: doc.body.textContent === window.symbolTest.text,
                sameCfi: selection.rangeCount > 0 &&
                    window.reader.view.getCFI(index, selection.getRangeAt(0)) === window.symbolTest.cfi,
                selected: selection.toString(),
            }
        }, fontName)
        assert.deepEqual(result, { sameNode: true, sameText: true, sameCfi: true, selected: symbols })
    }
})
