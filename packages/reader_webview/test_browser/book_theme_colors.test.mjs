import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

const paper = { fontColor: '#292521', backgroundColor: '#faf8f4' }
const dark = { fontColor: '#e8e4df', backgroundColor: '#17191c' }
const chapter = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Colors</title>
<meta name="viewport" content="width=390,height=844"/>
<style>
body { color: #123456; }
.caption { background-color: #000055; color: #eaeaea; font-weight: bold; }
.panel { background-color: #eeeeee; color: #222222; border: 2px solid #123456; }
.panel span, a span { color: #222222; }
td { background-color: #000055; color: #eaeaea; }
svg { color: #008800; background-color: #eeeeee; }
</style></head><body>
<p id="caption" class="caption">Listing caption</p>
<section id="panel" class="panel"><p id="prose">Nested <span id="nested">publisher text</span></p></section>
<p><a id="link" href="#caption"><span id="link-text">Caption link</span></a></p>
<blockquote id="quote"><p id="quote-text">Quoted text</p></blockquote>
<pre id="code"><code id="code-text">const value = 42;</code></pre>
<table><tbody><tr><td id="cell">A table cell</td></tr></tbody></table>
<p id="inline" style="background-color: #000055 !important; color: #222222 !important">Inline priority</p>
<svg xmlns="http://www.w3.org/2000/svg" id="art" width="40" height="40"><rect id="shape" width="40" height="40" fill="currentColor"/></svg>
</body></html>`

async function openBook(t, { style = paper, fixed = false } = {}) {
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    const files = {
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">colors</dc:identifier><dc:title>Colors</dc:title><dc:language>en</dc:language>${fixed ? '<meta property="rendition:layout">pre-paginated</meta>' : ''}</metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>`,
        'chapter.xhtml': chapter,
    }
    // Replace transport only; use the production loader, CSS and theme updates.
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
        url: JSON.stringify(origin + '/colors.epub'),
        initialProgress: JSON.stringify(0.001),
        style: JSON.stringify({
            pageTurnStyle: 'vertical', allowScript: false,
            fontName: 'serif', fontSize: 1.25, textScale: 1, fontWeight: 400,
            spacing: 1.5, topMargin: 24, bottomMargin: 24, sideMargin: 8,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
            ...style,
        }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    return page
}

const colors = (page, id) => page.evaluate(id => {
    const doc = window.reader.view.renderer.getContents()[0].doc
    const element = id == null ? doc.body : doc.getElementById(id)
    const css = doc.defaultView.getComputedStyle(element)
    return { color: css.color, background: css.backgroundColor, border: css.borderTopColor }
}, id)

const changeTheme = (page, style) => page.evaluate(async style => {
    window.changeStyle(style)
    // Contrast repair is scheduled after CSS application on the next frame.
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
}, style)

for (const [name, theme, foreground] of [
    ['paper', paper, 'rgb(41, 37, 33)'],
    ['dark', dark, 'rgb(232, 228, 223)'],
]) {
    test(`${name}: reader colors replace publisher foreground and background together`, async t => {
        const page = await openBook(t, { style: theme })
        assert.equal((await colors(page, null)).background,
            name === 'paper' ? 'rgb(250, 248, 244)' : 'rgb(23, 25, 28)')
        for (const id of ['caption', 'panel', 'prose', 'nested', 'cell']) {
            const css = await colors(page, id)
            assert.equal(css.background, 'rgba(0, 0, 0, 0)', id)
            assert.equal(css.color, foreground, id)
        }
        assert.equal((await colors(page, 'panel')).border, foreground)
        assert.deepEqual(await colors(page, 'art'), {
            color: 'rgb(0, 136, 0)', background: 'rgb(238, 238, 238)', border: 'rgb(0, 136, 0)',
        })
    })
}

test('semantic custom styles win over the color reset and propagate to children', async t => {
    const page = await openBook(t, { style: { ...paper, customCSSEnabled: true,
        customCSS: `a:link { color: #775533 !important; }
            blockquote { color: #665544 !important; }
            pre { background: #eee8df !important; border: 1px solid #998877 !important; }
            pre code { background: transparent !important; }`,
    } })
    assert.equal((await colors(page, 'link-text')).color, 'rgb(119, 85, 51)')
    assert.equal((await colors(page, 'quote-text')).color, 'rgb(102, 85, 68)')
    assert.equal((await colors(page, 'code')).background, 'rgb(238, 232, 223)')
    assert.equal((await colors(page, 'code')).border, 'rgb(153, 136, 119)')
    assert.equal((await colors(page, 'code-text')).background, 'rgba(0, 0, 0, 0)')
})

test('light theme contrast guard handles surviving inline-important backgrounds', async t => {
    const page = await openBook(t)
    assert.equal((await colors(page, 'inline')).color, 'rgb(255, 255, 255)')
    assert.equal((await colors(page, 'inline')).background, 'rgb(0, 0, 85)')
})

test('disabling color override restores publisher colors including guarded inline colors', async t => {
    const page = await openBook(t)
    await changeTheme(page, { overrideColor: false })
    assert.equal((await colors(page, 'caption')).background, 'rgb(0, 0, 85)')
    assert.equal((await colors(page, 'caption')).color, 'rgb(234, 234, 234)')
    assert.equal((await colors(page, 'inline')).color, 'rgb(34, 34, 34)')
})

test('fixed-layout EPUBs retain their publisher palette even in a dark reader theme', async t => {
    const page = await openBook(t, { style: dark, fixed: true })
    assert.equal((await colors(page, 'caption')).background, 'rgb(0, 0, 85)')
    assert.equal((await colors(page, 'panel')).color, 'rgb(34, 34, 34)')
    assert.equal((await colors(page, 'inline')).color, 'rgb(34, 34, 34)')
})

test('theme changes preserve text nodes, DOM selection and its CFI anchor', async t => {
    const page = await openBook(t)
    const before = await page.evaluate(() => {
        const { doc, index } = window.reader.view.renderer.getContents()[0]
        const node = doc.getElementById('caption').firstChild
        const range = doc.createRange()
        range.setStart(node, 0)
        range.setEnd(node, 7)
        doc.getSelection().removeAllRanges()
        doc.getSelection().addRange(range)
        window.originalThemeTextNode = node
        return { text: doc.body.textContent, cfi: window.reader.view.getCFI(index, range) }
    })
    for (const [theme, foreground] of [[dark, 'rgb(232, 228, 223)'], [paper, 'rgb(41, 37, 33)']]) {
        await changeTheme(page, theme)
        assert.equal((await colors(page, 'caption')).color, foreground)
        const after = await page.evaluate(() => {
            const { doc, index } = window.reader.view.renderer.getContents()[0]
            const selection = doc.getSelection()
            return {
                text: doc.body.textContent,
                cfi: window.reader.view.getCFI(index, selection.getRangeAt(0)),
                selected: selection.toString(),
                sameNode: doc.getElementById('caption').firstChild === window.originalThemeTextNode,
            }
        })
        assert.deepEqual(after, { ...before, selected: 'Listing', sameNode: true })
    }
})
