import test from 'node:test'
import assert from 'node:assert/strict'
import { strToU8, zipSync } from 'fflate'
import { createHarness, openComic } from './harness.mjs'

// Upstream foliate-js fixes ported in 2026-10, each pinned here so a later
// re-sync cannot drop it: FB2 tables, images without a reference and
// external links; comic pages as full documents; page turns finishing while
// the app is in the background.

const FB2 = `<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>Tables</book-title>
      <author><first-name>Ann</first-name><last-name>Author</last-name></author>
      <lang>en</lang>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>One</p></title>
      <p>Before the table.</p>
      <table>
        <tr align="center"><th colspan="2">Head</th></tr>
        <tr><td>a</td><td align="right">b</td></tr>
      </table>
      <p>An image without a reference: <image/> and a <a l:href="https://example.com/page">link</a>.</p>
    </section>
  </body>
</FictionBook>`

test('FB2: tables keep their cells, an image without a reference and external links do not break', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank?style=' + encodeURIComponent('{"allowScript":false}'))
    const result = await page.evaluate(async fb2 => {
        const { makeFB2 } = await import('/foliate-js/src/fb2.js')
        const book = await makeFB2(new Blob([fb2], { type: 'application/x-fictionbook+xml' }))
        const doc = await book.sections[0].createDocument()
        const table = doc.querySelector('table')
        return {
            title: book.metadata.title,
            author: book.metadata.author?.map?.(a => a.name ?? a) ?? book.metadata.author,
            cells: Array.from(table.querySelectorAll('th, td')).map(cell => cell.textContent),
            headColspan: table.querySelector('th').getAttribute('colspan'),
            rowAlign: table.querySelector('tr').getAttribute('align'),
            imageSrc: doc.querySelector('img')?.getAttribute('src') ?? null,
            linkHref: doc.querySelector('a').getAttribute('href'),
            external: book.isExternal('https://example.com/page'),
            internal: book.isExternal('#one'),
        }
    }, FB2)
    assert.equal(result.title, 'Tables')
    assert.deepEqual(result.cells, ['Head', 'a', 'b'])
    assert.equal(result.headColspan, '2')
    assert.equal(result.rowAlign, 'center')
    assert.equal(result.imageSrc, 'data:,')
    assert.equal(result.linkHref, 'https://example.com/page')
    assert.equal(result.external, true)
    assert.equal(result.internal, false)
})

test('comic pages are full documents with no body margin', async t => {
    const { page } = await openComic(t)
    const shape = await page.evaluate(() => {
        const renderer = window.reader.view.renderer
        const doc = renderer.getContents().find(({ index }) => index === renderer.index).doc
        return {
            doctype: doc.doctype?.name ?? null,
            charset: doc.characterSet,
            margin: doc.defaultView.getComputedStyle(doc.body).margin,
            images: doc.images.length,
        }
    })
    assert.equal(shape.doctype, 'html')
    assert.equal(shape.charset.toLowerCase(), 'utf-8')
    assert.equal(shape.margin, '0px')
    assert.equal(shape.images, 1)
})

const makeEpub = () => {
    const paragraphs = Array.from({ length: 80 }, (_, i) =>
        `<p>Paragraph ${i} carries a few sentences of ordinary prose so the chapter runs over many pages.</p>`).join('')
    return zipSync(Object.fromEntries(Object.entries({
        mimetype: 'application/epub+zip',
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="id">background</dc:identifier><dc:title>Background</dc:title><dc:language>en</dc:language>
            </metadata>
            <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
            <spine><itemref idref="chapter"/></spine></package>`,
        'chapter.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter</title></head><body>${paragraphs}</body></html>`,
    }).map(([name, content]) => [name, strToU8(content)])), { level: 0 })
}

test('a page turn still finishes while the document is hidden', async t => {
    const epub = makeEpub()
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() { return new File([Uint8Array.from(${JSON.stringify([...epub])})], 'background.epub') }
        }`,
    }))
    await page.setViewportSize({ width: 390, height: 700 })
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/background.epub'),
        importing: 'false',
        assetRevision: 'background-test',
        style: JSON.stringify({ pageTurnStyle: 'slide', allowScript: false,
            fontName: 'system', overrideFont: true, fontPath: '',
            fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb' }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))

    // In the background the browser delivers no animation frames, so the
    // slide would never end; a hidden document lands on the next page at
    // once, so the turn resolves and relocates.
    const outcome = await page.evaluate(async () => {
        Object.defineProperty(document, 'hidden', { configurable: true, get: () => true })
        const frames = window.requestAnimationFrame
        window.requestAnimationFrame = () => 0
        const before = window.bridgeCalls.length
        const turned = await Promise.race([
            window.reader.view.renderer.next().then(() => 'done'),
            new Promise(resolve => setTimeout(() => resolve('hung'), 3000)),
        ])
        await new Promise(resolve => setTimeout(resolve, 50))
        const relocated = window.bridgeCalls.slice(before).some(([name]) => name === 'onRelocated')
        window.requestAnimationFrame = frames
        delete document.hidden
        return { turned, relocated }
    })
    assert.equal(outcome.turned, 'done')
    assert.equal(outcome.relocated, true)
})
