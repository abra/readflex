import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from '../../../reader_webview/test_browser/harness.mjs'

const themes = JSON.parse(process.env.READFLEX_TABLE_TEST_CSS)
const chapter = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Tables</title>
<style>
.publisher-table { width: 100%; max-width: 100%; border-collapse: collapse; }
.publisher-table th, .publisher-table td { border: 1px solid; padding: 4px; }
.publisher-table p { margin: 0 24px 0 0; }
</style></head><body>
<table id="prose-table" class="publisher-table" width="100%">
<colgroup><col width="15%"/><col width="85%"/></colgroup>
<tr><th><p>Category</p></th><th><p>Description</p></th></tr>
<tr><td><p id="label">Configuration</p></td><td><p>Applications coordinate asynchronous work and exchange messages between independent components.</p></td></tr>
<tr><td><div><a href="#after">Observability</a></div></td><td><p>Metrics and logs explain the behavior of a running application.</p></td></tr>
</table>
<p id="after">Text after the table remains in the current reading column.</p>
<table id="wide-table" class="publisher-table" style="width:100%; max-width:100%">
<tr>${Array.from({ length: 6 }, (_, index) => `<td><p><span>Configuration${index}</span></p></td>`).join('')}</tr>
</table>
<table id="small-table"><tr><td>Yes</td><td>No</td></tr></table>
<p id="long-prose">${'LongIdentifier'.repeat(30)}</p>
${Array.from({ length: 16 }, () => '<p>Following paragraphs still paginate normally.</p>').join('')}
</body></html>`

async function openTables(t, {
    pageTurnStyle, css, width = 390, direction = 'ltr', content = chapter,
}) {
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    const files = {
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">tables</dc:identifier><dc:title>Tables</dc:title><dc:language>en</dc:language></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
        'chapter.xhtml': content.replace('<body>', `<body dir="${direction}">`),
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
    await page.setViewportSize({ width, height: 844 })
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/tables.epub'),
        initialProgress: JSON.stringify(0.001),
        style: JSON.stringify({
            pageTurnStyle, allowScript: false, fontName: 'serif',
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
    // onLoadEnd precedes the paginator's font/ResizeObserver layout pass.
    await page.evaluate(async () => {
        await window.reader.view.renderer.getContents()[0].doc.fonts.ready
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    })
    return page
}

for (const pageTurnStyle of ['vertical', 'slide', 'scroll']) {
    test(`${pageTurnStyle}: publisher table widths do not squash words`, async t => {
        const page = await openTables(t, { pageTurnStyle, css: themes.paper })
        const result = await page.evaluate(() => {
            const doc = window.reader.view.renderer.getContents()[0].doc
            const label = doc.getElementById('label')
            const range = doc.createRange()
            range.selectNodeContents(label)
            const table = doc.getElementById('prose-table')
            const wrapper = table.parentElement
            return {
                lines: range.getClientRects().length,
                contentWidth: wrapper.scrollWidth, viewportWidth: wrapper.clientWidth,
                overflow: doc.defaultView.getComputedStyle(wrapper).overflowX,
                tableWidth: table.getBoundingClientRect().width,
                preferredWidth: 40 * parseFloat(doc.defaultView.getComputedStyle(table).fontSize),
            }
        })
        assert.equal(result.lines, 1, 'a single label must not wrap into individual letters')
        assert.ok(result.contentWidth > result.viewportWidth + 4, JSON.stringify(result))
        assert.equal(result.overflow, 'auto')
        assert.ok(result.tableWidth <= result.preferredWidth + 1, JSON.stringify(result))
    })
}

for (const nested of [false, true]) {
    test(`a ${nested ? 'nested' : 'direct'} sole table keeps its scroll container`, async t => {
        const table = '<table><tr>' + Array.from({ length: 6 }, () =>
            '<td>Configuration</td>').join('') + '</tr></table>'
        const content = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Table</title></head><body>${nested ? `<div>${table}</div>` : table}</body></html>`
        const page = await openTables(t, { pageTurnStyle: 'slide', css: themes.paper, content })
        const result = await page.evaluate(() => {
            const doc = window.reader.view.renderer.getContents()[0].doc
            const wrapper = doc.querySelector('table').parentElement
            wrapper.scrollLeft = 100
            return {
                overflow: doc.defaultView.getComputedStyle(wrapper).overflowX,
                scrolled: wrapper.scrollLeft,
            }
        })
        assert.equal(result.overflow, 'auto')
        assert.ok(result.scrolled > 0)
    })
}

for (const direction of ['ltr', 'rtl']) {
    test(`${direction}: wide tables scroll locally without changing text or CFI`, async t => {
        const page = await openTables(t, { pageTurnStyle: 'vertical', css: themes.paper, direction })
        const result = await page.evaluate(async direction => {
            const { doc, index } = window.reader.view.renderer.getContents()[0]
            const table = doc.getElementById('wide-table')
            const wrapper = table.parentElement
            const node = table.querySelector('span').firstChild
            const range = doc.createRange()
            range.selectNodeContents(node)
            const cfi = window.reader.view.getCFI(index, range)
            const text = doc.body.textContent
            const paragraphs = [...doc.querySelectorAll('#after, #long-prose')]
            wrapper.scrollLeft = direction === 'rtl' ? -180 : 180
            await new Promise(resolve => requestAnimationFrame(resolve))
            return {
                scrolled: Math.abs(wrapper.scrollLeft),
                sameText: doc.body.textContent === text,
                sameCfi: window.reader.view.getCFI(index, range) === cfi,
                fitsViewport: wrapper.clientWidth <= window.innerWidth,
                proseFits: paragraphs.every(p => p.scrollWidth <= p.clientWidth + 1),
                smallOverflows: doc.getElementById('small-table').parentElement.scrollWidth >
                    doc.getElementById('small-table').parentElement.clientWidth + 1,
            }
        }, direction)
        assert.ok(result.scrolled > 0, JSON.stringify(result))
        assert.equal(result.sameText, true)
        assert.equal(result.sameCfi, true)
        assert.equal(result.fitsViewport, true)
        assert.equal(result.proseFits, true)
        assert.equal(result.smallOverflows, false)
    })
}

test('theme and viewport changes retain scroll wrappers without DOM churn', async t => {
    const page = await openTables(t, { pageTurnStyle: 'slide', css: themes.paper })
    await page.evaluate(() => {
        const doc = window.reader.view.renderer.getContents()[0].doc
        window.tableTextNode = doc.getElementById('label').firstChild
    })
    for (const width of [768, 320]) {
        await page.setViewportSize({ width, height: 844 })
        await page.evaluate(async css => {
            window.changeStyle({ customCSS: css })
            await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        }, themes.night)
        const result = await page.evaluate(() => {
            const doc = window.reader.view.renderer.getContents()[0].doc
            const table = doc.getElementById('wide-table')
            return {
                sameNode: doc.getElementById('label').firstChild === window.tableTextNode,
                wrappers: doc.querySelectorAll('.readflex-wide-table').length,
                scrollable: table.parentElement.scrollWidth > table.parentElement.clientWidth + 4,
            }
        })
        assert.equal(result.sameNode, true)
        assert.equal(result.wrappers, 3)
        assert.equal(result.scrollable, true)
    }
})

test('a horizontal wheel gesture scrolls the table instead of the book', async t => {
    const content = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Scroll</title></head><body>
    <table><tr>${Array.from({ length: 6 }, () => '<td>Configuration</td>').join('')}</tr></table>
    </body></html>`
    const page = await openTables(t, { pageTurnStyle: 'slide', css: themes.paper, content })
    const start = await page.evaluate(() => {
        const doc = window.reader.view.renderer.getContents()[0].doc
        const wrapper = doc.querySelector('.readflex-wide-table')
        const rect = wrapper.getBoundingClientRect()
        const frame = doc.defaultView.frameElement.getBoundingClientRect()
        return { x: frame.x + rect.x + 50, y: frame.y + rect.y + 10,
            cfi: window.reader.view.lastLocation.cfi }
    })
    await page.mouse.move(start.x, start.y)
    await page.mouse.wheel(160, 0)
    await page.waitForFunction(() =>
        window.reader.view.renderer.getContents()[0].doc.querySelector('.readflex-wide-table').scrollLeft > 0)
    assert.equal(await page.evaluate(() => window.reader.view.lastLocation.cfi), start.cfi)
})
