import test from 'node:test'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { strToU8, zipSync } from 'fflate'
import { createHarness } from './harness.mjs'

const epubFiles = {
    mimetype: 'application/epub+zip',
    'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="id">startup</dc:identifier><dc:title>Startup book</dc:title><dc:language>en</dc:language>
        </metadata>
        <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        <item id="next" href="next.xhtml" media-type="application/xhtml+xml"/></manifest>
        <spine><itemref idref="chapter"/><itemref idref="next"/></spine></package>`,
    'chapter.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Startup</title></head><body><p>Readable EPUB content.</p></body></html>',
    'next.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Next chapter</title></head><body><p>Next chapter content.</p></body></html>',
}
const createEpub = (overrides = {}) => zipSync(Object.fromEntries(
    Object.entries({ ...epubFiles, ...overrides }).map(([name, content]) => [name, strToU8(content)])), { level: 0 })
const epub = createEpub()
const fixedEpub = createEpub({ 'content.opf': epubFiles['content.opf'].replace('</metadata>',
    '<meta property="rendition:layout">pre-paginated</meta></metadata>') })

const comic = zipSync({
    'page.png': Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9AAAAABJRU5ErkJggg==', 'base64'),
}, { level: 0 })

const fb2 = strToU8(`<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
    <description><title-info><genre>science</genre><book-title>Startup FB2</book-title>
    <lang>en</lang></title-info></description>
    <body><section><title><p>Startup FB2</p></title><p>Readable FB2 content.</p></section></body>
    </FictionBook>`)

// [padding] adds an unreferenced stream of that many bytes after the page,
// standing in for the rest of a large book.
function createPdf({ padding = 0 } = {}) {
    const drawing = '0.2 0.5 0.7 rg 0 0 300 400 re f\n'
    const objects = [
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << >> /Contents 4 0 R >>',
        `<< /Length ${drawing.length} >>\nstream\n${drawing}endstream`,
    ]
    if (padding) objects.push(`<< /Length ${padding} >>\nstream\n${'x'.repeat(padding)}\nendstream`)
    let document = '%PDF-1.4\n'
    const offsets = objects.map((object, index) => {
        const offset = document.length
        document += `${index + 1} 0 obj\n${object}\nendobj\n`
        return offset
    })
    const xref = document.length
    document += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`
    for (const offset of offsets) document += `${String(offset).padStart(10, '0')} 00000 n \n`
    document += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`
    return Buffer.from(document)
}

// [recordReads] logs every byte range read from the book in
// `window.__fileReads`; [failRangesAfter] makes reads starting past that
// offset fail, as a broken transport would.
async function openBook(t, { bytes, name, importing = false, traceStartup = false,
    assetPrefix = '', fontName = 'system', fontFile, overrideFont = true,
    fontStatus = 200, initialCfi, initialProgress, recordReads = false,
    failRangesAfter = null } = {}) {
    const harness = await createHarness(t, { assetPrefix })
    const { page, origin } = harness
    const errors = []
    const timings = []
    const fontRequests = []
    page.on('request', request => {
        if (new URL(request.url()).pathname.endsWith('.ttf')) fontRequests.push(request.url())
    })
    await page.route('**/fonts/*.ttf', route => {
        const file = new URL(route.request().url()).pathname.split('/').at(-1)
        return route.fulfill(fontStatus === 200 ? {
            contentType: 'font/ttf',
            path: fileURLToPath(new URL(`../../component_library/fonts/${file}`, import.meta.url)),
        } : { status: fontStatus, body: '' })
    })
    page.on('console', message => {
        const prefix = '[reader-startup] '
        if (message.text().startsWith(prefix)) timings.push(JSON.parse(message.text().slice(prefix.length)))
    })
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    // Replace transport only; exercise the production bootstrap, format sniffing and rendering.
    const reads = recordReads || failRangesAfter != null ? `
        window.__fileReads = [];
        const slice = file.slice.bind(file);
        file.slice = (start = 0, end = file.size, type) => {
            window.__fileReads.push([start, Math.min(end, file.size)]);
            if (${failRangesAfter ?? 'Infinity'} < start) {
                return { size: end - start, arrayBuffer: () => Promise.reject(new Error('range failed')) };
            }
            return slice(start, end, type);
        };
        const arrayBuffer = file.arrayBuffer.bind(file);
        file.arrayBuffer = () => {
            window.__fileReads.push([0, file.size]);
            return arrayBuffer();
        };` : ''
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() {
                const bytes = Uint8Array.from(atob('${Buffer.from(bytes).toString('base64')}'), c => c.charCodeAt(0));
                const file = new File([bytes], ${JSON.stringify(name)});
                ${reads}
                return file;
            }
        }`,
    }))
    const consoleMessages = []
    page.on('console', message => consoleMessages.push(message.text()))
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/' + name),
        importing: JSON.stringify(importing),
        assetRevision: 'startup-test',
        traceStartup: JSON.stringify(traceStartup),
        style: JSON.stringify({ pageTurnStyle: 'slide', allowScript: false,
            fontName, overrideFont, fontPath: fontFile ? origin + assetPrefix + '/fonts/' + fontFile : '',
            fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb' }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    if (initialCfi) params.set('initialCfi', JSON.stringify(initialCfi))
    if (initialProgress != null) params.set('initialProgress', JSON.stringify(initialProgress))
    await page.goto(origin + assetPrefix + '/foliate-js/index.html?' + params)
    const ready = importing ? 'onMetadata' : 'onLoadEnd'
    const failures = ['onReaderLoadFailed', 'onImportError', 'onJsError']
    await page.waitForFunction(({ ready, failures }) =>
        window.bridgeCalls.some(([name]) => name === ready || failures.includes(name)),
    { ready, failures })
    const calls = await page.evaluate(() => window.bridgeCalls)
    assert.deepEqual(calls.filter(([name]) => failures.includes(name)), [])
    assert.ok(calls.some(([name]) => name === ready), `Expected ${ready}`)
    if (!importing) {
        const firstPosition = calls.findIndex(([name]) => name === 'onRelocated')
        assert.ok(firstPosition >= 0 && firstPosition < calls.findIndex(([name]) => name === 'onLoadEnd'),
            'onLoadEnd must not precede the first rendered position')
        await page.waitForFunction(() => reader.view.renderer.getContents().some(({ doc }) =>
            doc?.readyState === 'complete' && doc.body?.childElementCount > 0))
    }
    if (traceStartup) {
        assert.equal(timings.length, 1)
        const report = timings[0]
        assert.equal(report.stages.at(-1).stage, importing ? 'metadata-ready' : 'location-ready')
        assert.equal(report.stages.at(-1).elapsedMs, report.totalMs)
        let previous = 0
        for (const { elapsedMs, durationMs } of report.stages) {
            assert.ok(Number.isFinite(elapsedMs) && elapsedMs >= previous)
            assert.equal(durationMs, elapsedMs - previous)
            previous = elapsedMs
        }
    } else assert.deepEqual(timings, [])
    return { ...harness, timings, fontRequests, consoleMessages }
}

const readBytes = page => page.evaluate(() => window.__fileReads
    .reduce((total, [start, end]) => total + end - start, 0))

for (const importing of [false, true]) {
    for (const { format, bytes, name } of [
        { format: 'EPUB', bytes: epub, name: 'startup.epub' },
        { format: 'CBZ', bytes: comic, name: 'startup.cbz' },
        { format: 'FB2', bytes: fb2, name: 'startup.fb2' },
        { format: 'FBZ', bytes: zipSync({ 'book.fb2': fb2 }), name: 'startup.fb2.zip' },
    ]) {
        test(`${format} ${importing ? 'metadata' : 'reader'} startup does not load the PDF engine`, async t => {
            const { page, requests } = await openBook(t, { bytes, name, importing })
            assert.deepEqual(requests.filter(path => /\/pdf(?:\.worker)?\.js$/.test(path)), [])
            assert.equal(await page.evaluate(() => typeof globalThis.pdfjsLib), 'undefined')
            assert.equal(await page.evaluate(() => reader.view.book.supportsConcurrentDocumentReads === true), format === 'EPUB')
            if (format !== 'EPUB') {
                assert.ok(!requests.includes('/foliate-js/src/epub.js'))
            }
            assert.equal(requests.includes('/foliate-js/src/vendor/zip.js'), format !== 'FB2')
            if (!importing) {
                const content = await page.evaluate(() => {
                    const doc = reader.view.renderer.getContents().find(({ index }) => index === 0).doc
                    const image = doc.querySelector('img')
                    return { text: doc.body.textContent, imageReady: image?.complete && image.naturalWidth > 0 }
                })
                if (format === 'EPUB') assert.match(content.text, /Readable EPUB content/)
                else if (format === 'CBZ') assert.equal(content.imageReady, true)
                else assert.match(content.text, /Startup FB2|Readable FB2 content/)
            }
        })
    }

    test(`PDF ${importing ? 'metadata' : 'reader'} loads its engine and worker on demand`, async t => {
        const { page, requests } = await openBook(t, {
            bytes: createPdf(), name: 'startup.pdf', importing,
        })
        assert.ok(requests.indexOf('/foliate-js/src/book.js')
            < requests.indexOf('/foliate-js/src/vendor/pdfjs/pdf.js'))
        for (const file of ['pdf.js', 'pdf.worker.js']) {
            assert.equal(requests.filter(path => path === '/foliate-js/src/vendor/pdfjs/' + file).length, 1)
        }
        assert.equal(await page.evaluate(() => reader.view.book.sections.length), 1)
        assert.ok(!requests.includes('/foliate-js/src/epub.js'))
        assert.ok(!requests.includes('/foliate-js/src/vendor/zip.js'))
        if (!importing) {
            // Pages are drawn straight into a canvas, without an encoded image.
            assert.equal(await page.evaluate(() => {
                const doc = reader.view.renderer.getContents().find(({ index }) => index === 0).doc
                return doc.querySelector('canvas.readflex-pdf-page')?.width > 0 && !doc.querySelector('img')
            }), true)
        }
    })
}

// The text node in chapter one is shorter than offset 999, as when a saved
// CFI outlives a change to its chapter's DOM.
const staleCfi = 'epubcfi(/6/2!/4/2/1:999)'

test('a saved CFI that no longer resolves opens at the saved progress', async t => {
    const { page, consoleMessages } = await openBook(t, {
        bytes: epub, name: 'startup.epub', initialCfi: staleCfi, initialProgress: 0.75,
    })
    assert.ok(consoleMessages.some(text => text.startsWith('Saved location no longer resolves')))
    assert.equal(await page.evaluate(() => reader.view.lastLocation.section.current), 1)
})

test('a saved CFI that no longer resolves opens its chapter without progress', async t => {
    const { page } = await openBook(t, { bytes: epub, name: 'startup.epub', initialCfi: staleCfi })
    assert.equal(await page.evaluate(() => reader.view.lastLocation.section.current), 0)
    assert.match(await page.evaluate(() => reader.view.lastLocation.range.toString()),
        /Readable EPUB content/)
})

test('a resolvable CFI ignores the saved progress', async t => {
    const { page, consoleMessages } = await openBook(t, {
        bytes: epub, name: 'startup.epub', initialCfi: 'epubcfi(/6/2!/4/2/1:3)', initialProgress: 0.75,
    })
    assert.ok(!consoleMessages.some(text => text.startsWith('Saved location no longer resolves')))
    assert.equal(await page.evaluate(() => reader.view.lastLocation.section.current), 0)
})

test('PDF metadata reads only the byte ranges it needs', async t => {
    const bytes = createPdf({ padding: 2 * 1024 * 1024 })
    const { page } = await openBook(t, { bytes, name: 'large.pdf', importing: true, recordReads: true })
    const read = await readBytes(page)
    assert.ok(read < bytes.length / 4, `read ${read} of ${bytes.length} bytes`)
    assert.ok(!(await page.evaluate(size => window.__fileReads
        .some(([start, end]) => start === 0 && end === size), bytes.length)), 'no whole-file read')
    const metadata = await page.evaluate(() => window.bridgeCalls.find(([name]) => name === 'onMetadata')[1])
    assert.ok(metadata.cover, 'the first page still renders as the cover')
})

test('a PDF opened for reading is read once, whole', async t => {
    const bytes = createPdf({ padding: 2 * 1024 * 1024 })
    const { page } = await openBook(t, { bytes, name: 'large.pdf', recordReads: true })
    const wholeReads = await page.evaluate(size => window.__fileReads
        .filter(([start, end]) => start === 0 && end === size).length, bytes.length)
    assert.equal(wholeReads, 1)
})

test('PDF metadata falls back to one whole-file read when byte ranges fail', async t => {
    const bytes = createPdf({ padding: 2 * 1024 * 1024 })
    const { page, consoleMessages } = await openBook(t, {
        bytes, name: 'large.pdf', importing: true, failRangesAfter: 64 * 1024,
    })
    assert.ok(consoleMessages.some(text => text.startsWith('PDF byte ranges failed')))
    assert.ok(await page.evaluate(size => window.__fileReads
        .some(([start, end]) => start === 0 && end === size), bytes.length))
    const metadata = await page.evaluate(() => window.bridgeCalls.find(([name]) => name === 'onMetadata')[1])
    assert.ok(metadata.cover)
})

for (const importing of [false, true]) {
    for (const [name, bytes] of [['startup.epub', epub], ['startup.cbz', comic]]) {
        test(`${name} timing finishes once for ${importing ? 'metadata' : 'reading'}`, async t => {
            const { timings, page } = await openBook(t, { bytes, name, importing, traceStartup: true })
            const stages = timings[0].stages.map(({ stage }) => stage)
            const chapterStages = stages.filter(stage => stage.startsWith('chapter-'))
            if (!importing && name.endsWith('.epub')) {
                assert.deepEqual(chapterStages, [
                    'chapter-load-start', 'chapter-resources-ready', 'chapter-document-loaded',
                    'chapter-prepared', 'chapter-layout-ready', 'chapter-anchor-ready',
                ])
                await page.evaluate(() => reader.view.goTo(0))
                assert.equal(timings.length, 1, 'later navigation must not emit startup reports')
            } else assert.deepEqual(chapterStages, [])
        })
    }
}

for (const [name, bytes] of [['startup.epub', epub], ['startup.cbz', comic], ['startup.fb2', fb2]]) {
    test(`${name} metadata skips the reader's direction sampling and renderer`, async t => {
        const { page, requests, timings } = await openBook(t, { bytes, name, importing: true, traceStartup: true })
        const stages = timings[0].stages.map(({ stage }) => stage)
        assert.deepEqual(stages.filter(stage => ['direction-ready', 'navigation-ready'].includes(stage)), [])
        assert.equal(await page.locator('foliate-view').count(), 0)
        assert.ok(!requests.includes('/foliate-js/src/paginator.js'))
        assert.ok(!requests.includes('/foliate-js/src/fixed-layout.js'))
        const metadata = await page.evaluate(() => window.bridgeCalls.find(([n]) => n === 'onMetadata')[1])
        assert.match(metadata.title, /startup/i)
    })
}

for (const [fontName, fontFile] of [
    ['Literata', 'Literata-Variable.ttf'], ['PT Serif', 'PTSerif-Regular.ttf'],
    ['Open Sans', 'OpenSans-Variable.ttf'], ['Geist', 'Geist-Variable.ttf'],
]) {
    test(`preloads only the selected ${fontName} font through the scoped asset URL`, async t => {
        const assetPrefix = '/r/startup-test/assets'
        const { page, origin, fontRequests } = await openBook(t, {
            bytes: epub, name: 'startup.epub', fontName, fontFile, assetPrefix,
        })
        const expected = origin + assetPrefix + '/fonts/' + fontFile
        const links = await page.locator('link[rel="preload"][as="font"]').evaluateAll(links =>
            links.map(link => ({ href: link.href, crossOrigin: link.crossOrigin })))
        assert.deepEqual(links, [{ href: expected, crossOrigin: 'anonymous' }])
        assert.deepEqual([...new Set(fontRequests)], [expected])
    })
}

for (const options of [
    { name: 'startup.cbz', bytes: comic },
    { name: 'startup.pdf', bytes: createPdf() },
    { name: 'fixed.epub', bytes: fixedEpub },
    { importing: true }, { fontName: 'book' }, { fontName: 'system' }, { overrideFont: false },
]) {
    test(`does not preload unused reader fonts: ${options.name ?? JSON.stringify(options)}`, async t => {
        const { page, fontRequests } = await openBook(t, {
            name: 'startup.epub', bytes: epub, fontName: 'Literata',
            fontFile: 'Literata-Variable.ttf', ...options,
        })
        assert.equal(await page.locator('link[rel="preload"][as="font"]').count(), 0)
        assert.deepEqual(fontRequests, [])
    })
}

test('a failed font preload does not prevent restoring the initial location', async t => {
    const { page } = await openBook(t, { bytes: epub, name: 'startup.epub',
        fontName: 'Literata', fontFile: 'Literata-Variable.ttf', fontStatus: 404,
        initialCfi: 'epubcfi(/6/2!/4/2/1:9)', traceStartup: true })
    assert.match(await page.evaluate(() => reader.view.lastLocation.cfi), /^epubcfi\(\/6\/2!\//)
})

for (const initialProgress of [0.8, 1]) {
    test(`restores saved progress ${initialProgress} without visiting the first chapter`, async t => {
        const { page } = await openBook(t, { bytes: epub, name: 'startup.epub',
            initialProgress, traceStartup: true })
        const positions = await page.evaluate(() => window.bridgeCalls
            .filter(([name]) => name === 'onRelocated').map(([, position]) => position.cfi))
        assert.ok(positions.length > 0)
        for (const cfi of positions) assert.match(cfi, /^epubcfi\(\/6\/4!\//)
        assert.match(await page.evaluate(() => reader.view.renderer.getContents()[0].doc.body.textContent),
            /Next chapter content/)
    })
}

test('restores the saved CFI in preference to conflicting progress', async t => {
    const { page } = await openBook(t, { bytes: epub, name: 'startup.epub',
        initialCfi: 'epubcfi(/6/4!/4/2/1:5)', initialProgress: 0.01 })
    const positions = await page.evaluate(() => window.bridgeCalls
        .filter(([name]) => name === 'onRelocated').map(([, position]) => position.cfi))
    assert.ok(positions.length > 0)
    for (const cfi of positions) assert.match(cfi, /^epubcfi\(\/6\/4!\//)
})
