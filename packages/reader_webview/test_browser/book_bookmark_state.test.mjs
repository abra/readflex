import test from 'node:test'
import assert from 'node:assert/strict'
import { strToU8, zipSync } from 'fflate'
import { createHarness } from './harness.mjs'

// Whether the current page holds a bookmark travels with every position.
// A book without bookmarks skips the page anchor (a CFI and a word probe per
// turn); one with a bookmark still finds it, and only on its own page.

const paragraphs = Array.from({ length: 120 }, (_, i) =>
    `<p>Paragraph ${i} carries a few sentences of ordinary prose so the chapter runs over many pages.</p>`).join('')
const epub = zipSync(Object.fromEntries(Object.entries({
    mimetype: 'application/epub+zip',
    'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="id">bookmarks</dc:identifier><dc:title>Bookmarks</dc:title><dc:language>en</dc:language>
        </metadata>
        <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
        <spine><itemref idref="chapter"/></spine></package>`,
    'chapter.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter</title></head><body>${paragraphs}</body></html>`,
}).map(([name, content]) => [name, strToU8(content)])), { level: 0 })

async function openBook(t) {
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() { return new File([Uint8Array.from(${JSON.stringify([...epub])})], 'bookmarks.epub') }
        }`,
    }))
    await page.setViewportSize({ width: 390, height: 700 })
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/bookmarks.epub'),
        importing: 'false',
        assetRevision: 'bookmark-test',
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
    return page
}

const lastBookmarkState = page => page.evaluate(() => window.bridgeCalls
    .filter(([name]) => name === 'onRelocated').at(-1)[1].bookmark)

const turnPage = async (page, direction) => {
    const before = await page.evaluate(() => window.bridgeCalls.length)
    await page.evaluate(direction => direction === 'next'
        ? reader.view.renderer.next() : reader.view.renderer.prev(), direction)
    await page.waitForFunction(before => window.bridgeCalls.slice(before)
        .some(([name]) => name === 'onRelocated'), before)
}

test('pages report a bookmark only where one is', async t => {
    const page = await openBook(t)
    // The page anchor probes words under points of the page.
    await page.evaluate(() => {
        const doc = reader.view.renderer.getContents()[0].doc
        window.wordProbes = 0
        for (const name of ['caretRangeFromPoint', 'caretPositionFromPoint']) {
            const probe = doc[name]?.bind(doc)
            if (probe) doc[name] = (...args) => { window.wordProbes++; return probe(...args) }
        }
    })
    await turnPage(page, 'next')
    assert.equal((await lastBookmarkState(page)).exists, false)
    assert.equal(await page.evaluate(() => window.wordProbes), 0,
        'no page anchor while the book has no bookmarks')

    // Bookmark this page the way the reader does: JS proposes, Dart saves
    // and sends it back as an annotation.
    await page.evaluate(() => window.addBookmarkHere())
    const detail = await page.evaluate(() => window.bridgeCalls
        .find(([name]) => name === 'handleBookmark')[1].detail)
    assert.ok(detail.cfi)
    await page.evaluate(detail => {
        window.addAnnotation({ ...detail, id: 'b1', type: 'bookmark', value: detail.cfi })
        window.refreshBookmarkState()
    }, detail)
    assert.deepEqual(await lastBookmarkState(page), { exists: true, cfi: detail.cfi, id: 'b1' })

    await turnPage(page, 'next')
    assert.equal((await lastBookmarkState(page)).exists, false, 'the next page has none')
    await turnPage(page, 'prev')
    assert.equal((await lastBookmarkState(page)).exists, true, 'back on its page')

    await page.evaluate(cfi => {
        window.removeAnnotation(cfi, false, 'b1')
        window.refreshBookmarkState()
    }, detail.cfi)
    assert.deepEqual(await lastBookmarkState(page), { exists: false, cfi: null, id: null })
})
