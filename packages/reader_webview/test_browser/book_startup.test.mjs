import test from 'node:test'
import assert from 'node:assert/strict'
import { strToU8, zipSync } from 'fflate'
import { createHarness } from './harness.mjs'

const epub = zipSync(Object.fromEntries(Object.entries({
    mimetype: 'application/epub+zip',
    'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'content.opf': `<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="id">startup</dc:identifier><dc:title>Startup book</dc:title><dc:language>en</dc:language>
        </metadata>
        <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
        <spine><itemref idref="chapter"/></spine></package>`,
    'chapter.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Startup</title></head><body><p>Readable EPUB content.</p></body></html>',
}).map(([name, content]) => [name, strToU8(content)])), { level: 0 })

const comic = zipSync({
    'page.png': Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9AAAAABJRU5ErkJggg==', 'base64'),
}, { level: 0 })

function createPdf() {
    const drawing = '0.2 0.5 0.7 rg 0 0 300 400 re f\n'
    const objects = [
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << >> /Contents 4 0 R >>',
        `<< /Length ${drawing.length} >>\nstream\n${drawing}endstream`,
    ]
    let document = '%PDF-1.4\n'
    const offsets = objects.map((object, index) => {
        const offset = document.length
        document += `${index + 1} 0 obj\n${object}\nendobj\n`
        return offset
    })
    const xref = document.length
    document += `xref\n0 5\n0000000000 65535 f \n`
    for (const offset of offsets) document += `${String(offset).padStart(10, '0')} 00000 n \n`
    document += `trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`
    return Buffer.from(document)
}

async function openBook(t, { bytes, name, importing }) {
    const harness = await createHarness(t)
    const { page, origin } = harness
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, []))
    // Replace transport only; exercise the production bootstrap, format sniffing and rendering.
    await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
        contentType: 'text/javascript',
        body: `export class RemoteFile {
            async open() {
                return new File([Uint8Array.from(${JSON.stringify([...bytes])})], ${JSON.stringify(name)});
            }
        }`,
    }))
    const params = new URLSearchParams({
        url: JSON.stringify(origin + '/' + name),
        importing: JSON.stringify(importing),
        assetRevision: 'startup-test',
        style: JSON.stringify({ pageTurnStyle: 'slide', allowScript: false,
            fontName: 'serif', fontColor: '#000000', backgroundColor: '#ffffff',
            fontSize: 1, textScale: 1, fontWeight: 400, spacing: 1.5,
            topMargin: 0, bottomMargin: 0, sideMargin: 0,
            maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb' }),
        readingRules: JSON.stringify({ convertChineseMode: 'none' }),
    })
    await page.goto(origin + '/foliate-js/index.html?' + params)
    const ready = importing ? 'onMetadata' : 'onLoadEnd'
    const failures = ['onReaderLoadFailed', 'onImportError', 'onJsError']
    await page.waitForFunction(({ ready, failures }) =>
        window.bridgeCalls.some(([name]) => name === ready || failures.includes(name)),
    { ready, failures })
    const calls = await page.evaluate(() => window.bridgeCalls)
    assert.deepEqual(calls.filter(([name]) => failures.includes(name)), [])
    assert.ok(calls.some(([name]) => name === ready), `Expected ${ready}`)
    if (!importing) {
        await page.waitForFunction(() => {
            const doc = reader.view.renderer.getContents().find(({ index }) => index === 0)?.doc
            return doc?.readyState === 'complete' && doc.body?.childElementCount > 0
        })
    }
    return harness
}

for (const importing of [false, true]) {
    for (const { format, bytes, name } of [
        { format: 'EPUB', bytes: epub, name: 'startup.epub' },
        { format: 'CBZ', bytes: comic, name: 'startup.cbz' },
    ]) {
        test(`${format} ${importing ? 'metadata' : 'reader'} startup does not load the PDF engine`, async t => {
            const { page, requests } = await openBook(t, { bytes, name, importing })
            assert.deepEqual(requests.filter(path => /\/pdf(?:\.worker)?\.js$/.test(path)), [])
            assert.equal(await page.evaluate(() => typeof globalThis.pdfjsLib), 'undefined')
            if (!importing) {
                const content = await page.evaluate(() => {
                    const doc = reader.view.renderer.getContents().find(({ index }) => index === 0).doc
                    const image = doc.querySelector('img')
                    return { text: doc.body.textContent, imageReady: image?.complete && image.naturalWidth > 0 }
                })
                if (format === 'EPUB') assert.match(content.text, /Readable EPUB content/)
                else assert.equal(content.imageReady, true)
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
        if (!importing) {
            assert.equal(await page.evaluate(() => {
                const doc = reader.view.renderer.getContents().find(({ index }) => index === 0).doc
                const image = doc.querySelector('img')
                return image.complete && image.naturalWidth > 0
            }), true)
        }
    })
}
