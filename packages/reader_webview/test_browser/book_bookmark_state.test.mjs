import test from 'node:test'
import assert from 'node:assert/strict'
import { strToU8, zipSync } from 'fflate'
import { createHarness } from './harness.mjs'

// Whether the current page holds a bookmark travels with every position.
// A book without bookmarks skips the page anchor (a CFI and a word probe per
// turn); one with a bookmark still finds it, and only on its own page.
// New bookmarks anchor to a word on their own page, so they keep pointing at
// it when font size, flow or columns change the page count.

const makeEpub = ({ rtl = false } = {}) => {
    const paragraphs = Array.from({ length: 120 }, (_, i) =>
        `<p>Paragraph ${i} carries a few sentences of ordinary prose so the chapter runs over many pages.</p>`).join('')
    const dir = rtl ? ' dir="rtl"' : ''
    const progression = rtl ? ' page-progression-direction="rtl"' : ''
    return zipSync(Object.fromEntries(Object.entries({
        mimetype: 'application/epub+zip',
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="id">bookmarks</dc:identifier><dc:title>Bookmarks</dc:title><dc:language>en</dc:language>
            </metadata>
            <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
            <spine${progression}><itemref idref="chapter"/></spine></package>`,
        'chapter.xhtml': `<html xmlns="http://www.w3.org/1999/xhtml"${dir}><head><title>Chapter</title></head><body>${paragraphs}</body></html>`,
    }).map(([name, content]) => [name, strToU8(content)])), { level: 0 })
}

async function openBook(t, { style = {}, viewport = { width: 390, height: 700 }, rtl = false } = {}) {
    const epub = makeEpub({ rtl })
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
    await page.setViewportSize(viewport)
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/bookmarks.epub'),
        importing: 'false',
        assetRevision: 'bookmark-test',
        style: JSON.stringify({ pageTurnStyle: 'slide', allowScript: false,
            fontName: 'system', overrideFont: true, fontPath: '',
            fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
            ...style }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    return page
}

const lastBookmarkState = page => page.evaluate(() => window.bridgeCalls
    .filter(([name]) => name === 'onRelocated').at(-1)[1].bookmark)

const relocatedAfter = async (page, action) => {
    const before = await page.evaluate(() => window.bridgeCalls.length)
    await action()
    await page.waitForFunction(before => window.bridgeCalls.slice(before)
        .some(([name]) => name === 'onRelocated'), before)
}

const turnPage = (page, direction) => relocatedAfter(page, () => page.evaluate(
    direction => direction === 'next' ? reader.view.renderer.next() : reader.view.renderer.prev(),
    direction))

// Bookmark this page the way the reader does: JS proposes, Dart saves and
// sends it back as an annotation.
const bookmarkHere = async (page, id) => {
    const detail = await page.evaluate(() => {
        window.bridgeCalls = window.bridgeCalls.filter(([name]) => name !== 'handleBookmark')
        window.addBookmarkHere()
        return window.bridgeCalls.find(([name]) => name === 'handleBookmark')[1].detail
    })
    if (id) await saveBookmark(page, { ...detail, id })
    return detail
}

const saveBookmark = (page, bookmark) => page.evaluate(bookmark => {
    window.addAnnotation({ ...bookmark, type: 'bookmark', value: bookmark.cfi })
    window.refreshBookmarkState()
}, bookmark)

// Independent of the reader's own geometry: paragraphs with a line box inside
// the reader element, mapped from the section iframe to the page.
const paragraphsOnScreen = page => page.evaluate(() => {
    const renderer = reader.view.renderer
    const screen = renderer.getBoundingClientRect()
    const doc = renderer.getContents()[0].doc
    const frame = doc.defaultView.frameElement.getBoundingClientRect()
    return [...doc.querySelectorAll('p')].filter(p => [...p.getClientRects()].some(r =>
        r.width > 0 && r.height > 0 &&
        r.right + frame.left > screen.left + 1 && r.left + frame.left < screen.right - 1 &&
        r.bottom + frame.top > screen.top + 1 && r.top + frame.top < screen.bottom - 1))
        .map(p => Number(p.textContent.match(/Paragraph (\d+)/)[1]))
})

const paragraphOf = (page, cfi) => page.evaluate(cfi => {
    const doc = reader.view.renderer.getContents()[0].doc
    const range = reader.view.resolveCFI(cfi).anchor(doc)
    const p = range.startContainer.parentElement.closest('p')
    return Number(p.textContent.match(/Paragraph (\d+)/)[1])
}, cfi)

const assertAnchoredOnScreen = async (page, detail, message) => {
    const onScreen = await paragraphsOnScreen(page)
    const anchored = await paragraphOf(page, detail.cfi)
    assert.ok(onScreen.includes(anchored),
        `${message}: anchor in paragraph ${anchored}, screen shows ${onScreen.join(',')}`)
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

    const detail = await bookmarkHere(page, 'b1')
    assert.ok(detail.cfi)
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

test('every page anchors its bookmark to a word on that page', async t => {
    const page = await openBook(t)
    const total = await page.evaluate(() => reader.view.lastLocation.chapterLocation.total)
    assert.ok(total >= 6, `the chapter spans pages (got ${total})`)
    const cfis = new Set()
    for (let turn = 0; turn < total - 1; turn++) {
        if (turn > 0) await turnPage(page, 'next')
        const detail = await bookmarkHere(page)
        assert.equal(detail.anchorVersion, 2)
        assert.equal(detail.anchorSectionPage,
            await page.evaluate(() => reader.view.lastLocation.chapterLocation.current))
        await assertAnchoredOnScreen(page, detail, `page ${turn + 1}`)
        cfis.add(detail.cfi)
    }
    assert.equal(cfis.size, total - 1, 'each page has its own anchor')
})

test('a bookmark keeps its word when a bigger font repaginates the chapter', async t => {
    const page = await openBook(t)
    await turnPage(page, 'next')
    await turnPage(page, 'next')
    const before = await paragraphsOnScreen(page)
    const detail = await bookmarkHere(page, 'b1')

    await relocatedAfter(page, () => page.evaluate(() => window.changeStyle({ fontSize: 1.4 })))
    await relocatedAfter(page, () => page.evaluate(() => reader.view.goTo(0)))
    assert.equal((await lastBookmarkState(page)).exists, false, 'the chapter start is not bookmarked')

    await relocatedAfter(page, () => page.evaluate(detail => window.goToBookmark(detail), detail))
    await assertAnchoredOnScreen(page, detail, 'after repagination')
    assert.ok((await paragraphsOnScreen(page)).some(n => before.includes(n)),
        'the bookmarked text is on screen, not the same page number')
    assert.deepEqual(await lastBookmarkState(page), { exists: true, cfi: detail.cfi, id: 'b1' })

    await turnPage(page, 'next')
    assert.equal((await lastBookmarkState(page)).exists, false, 'only the page with the word')
})

test('older bookmarks without an anchor version keep their page number', async t => {
    const page = await openBook(t)
    await turnPage(page, 'next')
    const ownPage = await paragraphsOnScreen(page)
    const own = await bookmarkHere(page)
    for (let i = 0; i < 3; i++) await turnPage(page, 'next')
    const elsewhere = await bookmarkHere(page)
    // Saved before the visible-page anchor: CFI and quote from another page.
    const legacy = { ...own, id: 'old', cfi: elsewhere.cfi,
        anchorExact: elsewhere.anchorExact, anchorPrefix: elsewhere.anchorPrefix,
        anchorSuffix: elsewhere.anchorSuffix, anchorVersion: undefined }
    await saveBookmark(page, legacy)
    assert.equal((await lastBookmarkState(page)).exists, false, 'not where its CFI points')

    await relocatedAfter(page, () => page.evaluate(() => reader.view.goTo(0)))
    await relocatedAfter(page, () => page.evaluate(legacy => window.goToBookmark(legacy), legacy))
    assert.deepEqual(await paragraphsOnScreen(page), ownPage, 'opens its page number')
    assert.equal((await lastBookmarkState(page)).exists, true)
})

test('scrolled flow anchors the bookmark to the visible part of the chapter', async t => {
    const page = await openBook(t, { style: { pageTurnStyle: 'scroll' } })
    await turnPage(page, 'next')
    await turnPage(page, 'next')
    const detail = await bookmarkHere(page, 'b1')
    assert.equal(detail.anchorVersion, 2)
    await assertAnchoredOnScreen(page, detail, 'scrolled')
    assert.equal((await lastBookmarkState(page)).exists, true)
})

test('two-column spreads anchor the bookmark to the visible spread', async t => {
    const page = await openBook(t, {
        style: { maxColumnCount: 2 },
        viewport: { width: 1000, height: 700 },
    })
    await turnPage(page, 'next')
    const detail = await bookmarkHere(page)
    await assertAnchoredOnScreen(page, detail, 'spread')
})

test('right-to-left books anchor the bookmark to the visible page', async t => {
    const page = await openBook(t, { rtl: true })
    await turnPage(page, 'next')
    await turnPage(page, 'next')
    const detail = await bookmarkHere(page, 'b1')
    await assertAnchoredOnScreen(page, detail, 'rtl')
    assert.equal((await lastBookmarkState(page)).exists, true)
})
