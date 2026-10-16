import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

// Text columns and line length in wide windows. Flutter sends
// `maxLineWidthEm` only to wide windows; phones keep one column across the
// page. Runs the production loader, paginator and article shell.

const portrait = { width: 1032, height: 1376 }
const landscape = { width: 1376, height: 1032 }
const phone = { width: 390, height: 844 }
// What the keyboard takes off a 13-inch iPad's page, measured in each
// orientation.
const keyboardPortrait = 403
const keyboardLandscape = 498
// 18px body text: 16px × fontSize, as book.js sizes it.
const fontSize = 1.125
const measurePx = em => Math.round(em * 16 * fontSize)

const paragraphs = Array.from({ length: 40 }, (_, i) =>
    `<p id="p${i}">Paragraph ${i} carries several sentences of ordinary prose. ` +
    'Reading is easier when every line keeps a comfortable length, ' +
    'neither so short that the eye jumps nor so long that it loses its place.</p>',
).join('')
const chapter = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Columns</title></head>
<body>${paragraphs}</body></html>`

const baseStyle = {
    pageTurnStyle: 'slide', allowScript: false,
    fontName: 'serif', fontSize, textScale: 1, fontWeight: 400,
    spacing: 1.5, topMargin: 24, bottomMargin: 24, sideMargin: 8,
    maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
    fontColor: '#292521', backgroundColor: '#faf8f4',
}

async function openBook(t, { viewport, style = {} }) {
    const { page, origin } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    const files = {
        'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">columns</dc:identifier><dc:title>Columns</dc:title><dc:language>en</dc:language></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
        'chapter.xhtml': chapter,
    }
    // Replace transport only; use the production loader and paginator.
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
    await page.setViewportSize(viewport)
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/columns.epub'),
        initialProgress: JSON.stringify(0.001),
        style: JSON.stringify({ ...baseStyle, ...style }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    return page
}

// The page's layout as the paginator applied it, plus the widest paragraph.
const layout = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const { doc } = renderer.getContents()[0]
    const css = doc.defaultView.getComputedStyle(doc.documentElement)
    const size = renderer.getBoundingClientRect().width
    const columnWidth = parseFloat(css.columnWidth)
    const gap = parseFloat(css.columnGap)
    // A paragraph can break across columns: measure each line box fragment.
    const widest = Math.max(...[...doc.querySelectorAll('p')]
        .flatMap(p => [...p.getClientRects()].map(rect => rect.width)))
    return {
        attribute: renderer.getAttribute('max-inline-size'),
        columns: Math.round(size / (columnWidth + gap)),
        columnWidth,
        gap,
        size,
        widest,
    }
})

const changeStyle = (page, style) => page.evaluate(async style => {
    window.changeStyle(style)
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
}, style)

const resize = async (page, viewport) => {
    await page.setViewportSize(viewport)
    await page.evaluate(() => new Promise(resolve =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))))
}

// The iPadOS keyboard shortens the visual viewport, not the window: the shell
// (index.html) sizes the page to the visual viewport, so the page gets
// shorter while innerWidth and innerHeight keep the window's size. Takes
// `height` off the page after every resize; `rotateTo` turns the window with
// the keyboard up, so the first page the paginator sees is already short.
async function keyboard(page, height, rotateTo = null) {
    await page.evaluate(height => {
        window.testKeyboardHeight = height
        if (window.testKeyboard) return
        window.testKeyboard = () => document.documentElement.style.setProperty(
            '--readflex-viewport-height', `${innerHeight - window.testKeyboardHeight}px`)
        // Added after the shell's listeners, so it has the last word.
        window.addEventListener('resize', window.testKeyboard)
        window.visualViewport?.addEventListener('resize', window.testKeyboard)
    }, height)
    if (rotateTo) await page.setViewportSize(rotateTo)
    else await page.evaluate(() => window.testKeyboard())
    await page.evaluate(() => new Promise(resolve =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))))
}

const pageHeight = page => page.evaluate(() =>
    Math.round(window.reader.view.renderer.getBoundingClientRect().height))

test('a phone keeps one column across the page without a measure', async t => {
    const page = await openBook(t, { viewport: phone })
    const result = await layout(page)
    assert.equal(result.attribute, null)
    assert.equal(result.columns, 1)
    assert.ok(result.columnWidth > phone.width * 0.85, `${result.columnWidth} spans the page`)
})

test('Auto shows one column at the measure on a portrait tablet', async t => {
    const page = await openBook(t, {
        viewport: portrait,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    const result = await layout(page)
    assert.equal(result.attribute, `${measurePx(32)}px`)
    assert.equal(result.columns, 1)
    assert.ok(Math.abs(result.columnWidth - measurePx(32)) <= 1, `${result.columnWidth}`)
    assert.ok(result.widest <= measurePx(32) + 1, `${result.widest} stays within the measure`)
})

test('Auto turns into a spread when the tablet rotates, and back', async t => {
    const page = await openBook(t, {
        viewport: portrait,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    await resize(page, landscape)
    const spread = await layout(page)
    assert.equal(spread.columns, 2)
    assert.ok(spread.columnWidth <= measurePx(32) + 1, `${spread.columnWidth}`)

    await resize(page, portrait)
    assert.equal((await layout(page)).columns, 1)
})

test('the keyboard shortening the page keeps the Auto layout', async t => {
    // Searching opens the keyboard: the page gets wider than it is tall.
    const page = await openBook(t, {
        viewport: portrait,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    await keyboard(page, keyboardPortrait)
    assert.equal(await pageHeight(page), portrait.height - keyboardPortrait)
    assert.equal((await layout(page)).columns, 1, 'no spread while searching')
    await keyboard(page, 0)
    assert.equal((await layout(page)).columns, 1)

    await resize(page, landscape)
    assert.equal((await layout(page)).columns, 2)
    await keyboard(page, keyboardLandscape)
    assert.equal((await layout(page)).columns, 2, 'the spread stays')
})

test('rotating with the keyboard up follows the window', async t => {
    const page = await openBook(t, {
        viewport: landscape,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    await keyboard(page, keyboardLandscape)
    assert.equal((await layout(page)).columns, 2)

    await keyboard(page, keyboardPortrait, portrait)
    assert.equal(await pageHeight(page), portrait.height - keyboardPortrait)
    assert.equal((await layout(page)).columns, 1, 'no spread in portrait')
    await keyboard(page, 0)
    assert.equal((await layout(page)).columns, 1, 'one column once the keyboard closes')

    await keyboard(page, keyboardPortrait)
    await keyboard(page, keyboardLandscape, landscape)
    assert.equal((await layout(page)).columns, 2, 'the spread returns in landscape')
})

test('One keeps a single column at the measure in landscape', async t => {
    const page = await openBook(t, {
        viewport: landscape,
        style: { maxColumnCount: 1, maxLineWidthEm: 32 },
    })
    const result = await layout(page)
    assert.equal(result.columns, 1)
    assert.ok(Math.abs(result.columnWidth - measurePx(32)) <= 1, `${result.columnWidth}`)
})

test('Two shows a spread in portrait', async t => {
    const page = await openBook(t, {
        viewport: portrait,
        style: { maxColumnCount: 2, maxLineWidthEm: 32 },
    })
    assert.equal((await layout(page)).columns, 2)
})

test('larger text widens the measure and drops the Auto spread', async t => {
    const page = await openBook(t, {
        viewport: landscape,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    await changeStyle(page, { ...baseStyle, maxColumnCount: 0, maxLineWidthEm: 32, textScale: 2 })
    const result = await layout(page)
    assert.equal(result.attribute, `${measurePx(32) * 2}px`)
    assert.equal(result.columns, 1)
})

test('a window that becomes narrow loses the measure', async t => {
    const page = await openBook(t, {
        viewport: portrait,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    // Flutter sends the narrow-window style when Split View shrinks the app.
    await changeStyle(page, { ...baseStyle, maxColumnCount: 1, maxLineWidthEm: null })
    const result = await layout(page)
    assert.equal(result.attribute, null)
    assert.equal(result.columns, 1)
    assert.ok(result.columnWidth > portrait.width * 0.85, `${result.columnWidth} spans the page`)
})

test('reading position survives a change of columns', async t => {
    const page = await openBook(t, {
        viewport: portrait,
        style: { maxColumnCount: 0, maxLineWidthEm: 32 },
    })
    const onScreen = () => page.evaluate(() => {
        const { doc } = window.reader.view.renderer.getContents()[0]
        const frame = doc.defaultView.frameElement.getBoundingClientRect()
        return [...doc.getElementById('p20').getClientRects()].some(rect => {
            const left = frame.left + rect.left
            return left >= 0 && left < innerWidth
        })
    })
    await page.evaluate(() => window.reader.view.goTo('chapter.xhtml#p20'))
    await page.waitForFunction(() => {
        const { doc } = window.reader.view.renderer.getContents()[0]
        const frame = doc.defaultView.frameElement.getBoundingClientRect()
        return [...doc.getElementById('p20').getClientRects()]
            .some(rect => frame.left + rect.left >= 0 && frame.left + rect.left < innerWidth)
    })
    assert.ok(await onScreen(), 'the paragraph is on screen before rotating')
    await resize(page, landscape)
    await page.waitForTimeout(200)
    assert.ok(await onScreen(), 'the paragraph read before rotating stays on screen')
})

async function openArticle(t, { viewport, style }) {
    const { page, routes, articleUrl } = await createHarness(t)
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    routes.set('/article-content', paragraphs)
    await page.setViewportSize(viewport)
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    await changeStyle(page, style)
    return page
}

const articleWidths = page => page.evaluate(() => {
    const main = document.querySelector('main')
    const css = getComputedStyle(main)
    const content = main.getBoundingClientRect().width -
        parseFloat(css.paddingLeft) - parseFloat(css.paddingRight)
    return { main: main.getBoundingClientRect(), content, window: innerWidth }
})

test('a wide article keeps the measure and centres it', async t => {
    const page = await openArticle(t, {
        viewport: landscape,
        style: { fontSize, textScale: 1, sideMargin: 8, maxLineWidthEm: 32 },
    })
    const result = await articleWidths(page)
    assert.ok(Math.abs(result.content - measurePx(32)) <= 1, `${result.content}`)
    const left = result.main.left
    const right = result.window - result.main.right
    assert.ok(Math.abs(left - right) <= 1, `centred: ${left} vs ${right}`)
})

test('an article without a measure spans the window', async t => {
    const page = await openArticle(t, {
        viewport: landscape,
        style: { fontSize, textScale: 1, sideMargin: 8 },
    })
    const result = await articleWidths(page)
    assert.ok(Math.abs(result.main.width - landscape.width) <= 1, `${result.main.width}`)
})

// A landscape phone: the display cutout takes 62px on each side, as iOS
// reports for iPhone 17 Pro. Text keeps clear of it; the page still fills
// the window, so edge taps keep working there.
const landscapePhone = { width: 874, height: 402 }
const cutout = { safeAreaLeft: 62, safeAreaRight: 62 }

// Where the first page's text starts and ends, in window coordinates.
const firstPageText = page => page.evaluate(() => {
    const renderer = window.reader.view.renderer
    const { doc } = renderer.getContents()[0]
    const size = renderer.getBoundingClientRect().width
    const rects = [...doc.querySelectorAll('p')]
        .flatMap(p => [...p.getClientRects()])
        .filter(rect => rect.width > 0 && rect.left < size)
    const css = doc.defaultView.getComputedStyle(doc.documentElement)
    return {
        left: Math.min(...rects.map(rect => rect.left)),
        right: Math.max(...rects.map(rect => rect.right)),
        paddingLeft: parseFloat(css.paddingLeft),
        paddingRight: parseFloat(css.paddingRight),
        size,
    }
})

for (const pageTurnStyle of ['slide', 'scroll']) {
    test(`book text keeps clear of a landscape cutout (${pageTurnStyle})`, async t => {
        const style = { sideMargin: 3, pageTurnStyle }
        const page = await openBook(t, { viewport: landscapePhone, style })
        const bare = await firstPageText(page)
        assert.ok(bare.paddingLeft < 62, `without insets the margin stays the reader's: ${bare.paddingLeft}`)

        await changeStyle(page, { ...style, ...cutout })
        const safe = await firstPageText(page)
        assert.ok(safe.paddingLeft >= 62 - 0.5, `start padding ${safe.paddingLeft}`)
        assert.ok(safe.paddingRight >= 62 - 0.5, `end padding ${safe.paddingRight}`)
        assert.ok(safe.left >= 62 - 0.5, `text starts at ${safe.left}`)
        assert.ok(safe.right <= safe.size - 62 + 0.5, `text ends at ${safe.right}`)
        assert.equal(safe.size, landscapePhone.width, 'the page still fills the window')

        // Rotating back to portrait drops the insets and the wider margin.
        await changeStyle(page, { ...style, safeAreaLeft: 0, safeAreaRight: 0 })
        assert.ok(Math.abs((await firstPageText(page)).left - bare.left) < 0.5)
    })
}

test('a wide reader margin already clear of the cutout is kept', async t => {
    const style = { sideMargin: 20, ...cutout }
    const page = await openBook(t, { viewport: landscapePhone, style })
    const result = await layout(page)
    // 20% → -g / (g - 1) × size; the inset asks for less.
    assert.ok(Math.abs(result.gap - 0.2 / 0.8 * landscapePhone.width) < 1, `${result.gap}`)
})

test('article text keeps clear of a landscape cutout', async t => {
    const style = { fontSize, textScale: 1, sideMargin: 3 }
    const page = await openArticle(t, { viewport: landscapePhone, style })
    const text = () => page.evaluate(() => {
        const rects = [...document.querySelectorAll('main p')]
            .flatMap(p => [...p.getClientRects()])
        return {
            left: Math.min(...rects.map(rect => rect.left)),
            right: Math.max(...rects.map(rect => rect.right)),
        }
    })
    assert.ok((await text()).left < 62, 'without insets the margin stays the reader\'s')

    await changeStyle(page, { ...style, ...cutout })
    const safe = await text()
    assert.ok(safe.left >= 62 - 0.5, `text starts at ${safe.left}`)
    assert.ok(safe.right <= landscapePhone.width - 62 + 0.5, `text ends at ${safe.right}`)

    // With a measure the line keeps its length and stays centred.
    await changeStyle(page, { ...style, ...cutout, maxLineWidthEm: 32 })
    const measured = await articleWidths(page)
    assert.ok(Math.abs(measured.content - measurePx(32)) <= 1, `${measured.content}`)
    const left = measured.main.left
    const right = measured.window - measured.main.right
    assert.ok(Math.abs(left - right) <= 1, `centred: ${left} vs ${right}`)
})
