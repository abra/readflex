import test from 'node:test'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { createHarness } from '../../../reader_webview/test_browser/harness.mjs'

const themes = JSON.parse(process.env.READFLEX_TYPOGRAPHY_TEST_CSS)
const chapter = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Code and annotations</title>
<style>.fm-combinumeral { font-family: "Segoe UI Symbol", sans-serif; }</style></head><body>
<pre id="listing">public class Example {
  private final String value;
  public String value() { return value; }
}</pre>
<p class="fm-code-annotation-mob" id="long"><span class="fm-combinumeral">\u2776</span> The annotation explains how this example completes asynchronous work while retaining the original execution context.</p>
<p class="fm-code-annotation-mob" id="short"><span class="fm-combinumeral">\u2777</span> A short explanation.</p>
<p id="prose">Normal reading typography.</p>
<p class="code-caption" id="caption">A lengthy listing caption provides a description of the program and should not itself become a code block.</p>
<div id="nonsemantic" class="ProgramCode">const marker = "\u278a"; <span id="code-symbol">\u278a\u278b\u278c</span> // A complete code example with symbols not supplied by the selected monospace font.</div>
<p><code id="inline-code">const count = 42; \u278a</code></p>
<p><samp id="sample">count = 42; \u278b</samp></p>
<p><kbd id="key">Ctrl \u278c</kbd></p>
</body></html>`

async function openBook(t, css) {
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    await page.route('**/fonts/*.ttf', route => {
        const name = new URL(route.request().url()).pathname.split('/').at(-1)
        return route.fulfill({ contentType: 'font/ttf',
            path: fileURLToPath(new URL(`../../../component_library/fonts/${name}`, import.meta.url)) })
    })
    const files = {
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">typography</dc:identifier><dc:title>Code and annotations</dc:title><dc:language>en</dc:language></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
        'chapter.xhtml': chapter,
    }
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
        url: JSON.stringify(origin + '/typography.epub'),
        initialProgress: JSON.stringify(0.001),
        style: JSON.stringify({
            pageTurnStyle: 'vertical', allowScript: false, fontName: 'Literata',
            fontPath: origin + '/fonts/Literata-Variable.ttf',
            fontColor: '#292521', backgroundColor: '#faf8f4',
            fontSize: 1.25, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 24, bottomMargin: 24, sideMargin: 8,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
            customCSSEnabled: true, customCSS: css,
        }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await page.evaluate(() => window.reader.view.renderer.getContents()[0].doc.fonts.ready.then(() => {}))
    return page
}

for (const [theme, css] of Object.entries(themes)) {
    test(`${theme}: code descriptions keep prose styling and markers`, async t => {
        const page = await openBook(t, css)
        const metrics = await page.evaluate(() => {
            const { doc } = window.reader.view.renderer.getContents()[0]
            return ['long', 'short', 'caption', 'prose', 'listing', 'nonsemantic'].map(id => {
                const element = doc.getElementById(id)
                const style = doc.defaultView.getComputedStyle(element)
                return { id, code: element.classList.contains('readflex-code-block'),
                    family: style.fontFamily, background: style.backgroundColor,
                    fontSize: style.fontSize,
                    markerFamily: element.firstElementChild &&
                        doc.defaultView.getComputedStyle(element.firstElementChild).fontFamily }
            })
        })
        const prose = metrics.find(item => item.id === 'prose')
        for (const id of ['long', 'short', 'caption']) {
            const actual = metrics.find(item => item.id === id)
            assert.equal(actual.code, false, id)
            assert.equal(actual.family, prose.family, id)
            assert.equal(actual.background, prose.background, id)
            assert.equal(actual.fontSize, prose.fontSize, id)
            if (id !== 'caption') assert.ok(actual.markerFamily.includes('Noto Sans Symbols'), actual.markerFamily)
        }
        assert.ok(metrics.find(item => item.id === 'listing').family.startsWith('ui-monospace'))
        assert.equal(metrics.find(item => item.id === 'nonsemantic').code, true)
    })

    test(`${theme}: code font fallbacks render symbols without replacing monospace text`, async t => {
        const page = await openBook(t, css)
        const results = await page.evaluate(() => {
            const { doc } = window.reader.view.renderer.getContents()[0]
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
            const monoText = render('ui-monospace, Menlo, monospace', 'const count = 42;')
            // Native mono families cover different symbols on different OSes.
            // Keep their valid glyphs; only missing ones should use the fallback.
            const expectedFamily = 'ui-monospace, Menlo, monospace, "Noto Sans Symbols"'
            const markers = ['\u2776', '\u2777', '\u2778', '\u278a', '\u278b', '\u278c']
            return ['listing', 'nonsemantic', 'code-symbol', 'inline-code', 'sample', 'key'].map(id => {
                const family = doc.defaultView.getComputedStyle(doc.getElementById(id)).fontFamily
                return { id, family, sameText: same(render(family, 'const count = 42;'), monoText),
                    symbols: markers.map(text => {
                        const pixels = render(family, text)
                        return { text, sameGlyph: same(pixels, render(expectedFamily, text)),
                            hasInk: pixels.some(value => value !== 0),
                            isMissing: same(pixels, render(family, '\u{10ffff}')) ||
                                same(pixels, render(family, '\ufffd')) }
                    }) }
            })
        })
        for (const result of results) {
            assert.ok(result.family.startsWith('ui-monospace'), JSON.stringify(result))
            assert.ok(result.family.includes('Noto Sans Symbols'), JSON.stringify(result))
            assert.equal(result.sameText, true, JSON.stringify(result))
            for (const symbol of result.symbols) {
                assert.equal(symbol.sameGlyph, true, JSON.stringify(result))
                assert.equal(symbol.hasInk, true, JSON.stringify(result))
                assert.equal(symbol.isMissing, false, JSON.stringify(result))
            }
        }
    })
}

test('normalization preserves annotation text, selection and CFI on repeated passes', async t => {
    const page = await openBook(t, themes.paper)
    const result = await page.evaluate(async () => {
        const { doc, index } = window.reader.view.renderer.getContents()[0]
        const { normalizeLoadedDocument } = await import('/foliate-js/src/readflex_document_normalizer.js')
        const node = doc.getElementById('long').querySelector('span').firstChild
        const range = doc.createRange()
        range.selectNodeContents(node)
        const text = doc.body.textContent
        const cfi = window.reader.view.getCFI(index, range)
        doc.getSelection().removeAllRanges()
        doc.getSelection().addRange(range)
        normalizeLoadedDocument(doc)
        normalizeLoadedDocument(doc)
        return { sameText: doc.body.textContent === text,
            sameNode: doc.getElementById('long').querySelector('span').firstChild === node,
            sameCfi: window.reader.view.getCFI(index, doc.getSelection().getRangeAt(0)) === cfi,
            selected: doc.getSelection().toString() }
    })
    assert.deepEqual(result, { sameText: true, sameNode: true, sameCfi: true, selected: '\u2776' })
})
