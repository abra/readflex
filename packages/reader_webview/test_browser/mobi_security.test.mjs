import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

test('MOBI publisher script must not execute in the reader origin', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank?style=' + encodeURIComponent('{"allowScript":false}'))
    const result = await page.evaluate(async () => {
        const { MOBI } = await import('/foliate-js/src/mobi.js')
        await import('/foliate-js/src/view.js')
        const encode = value => new TextEncoder().encode(value)
        const canvas = document.createElement('canvas')
        canvas.width = 4; canvas.height = 4
        canvas.getContext('2d').fillRect(0, 0, 4, 4)
        const png = new Uint8Array(await (await new Promise(resolve => canvas.toBlob(resolve))).arrayBuffer())
        const html = encode('<html><head><script>parent.publisherExecuted = true</script></head><body onload="parent.publisherExecuted = true"><p id="passage">Readable book text.</p><img id="illustration" recindex="1"><img src="missing.png" onerror="parent.publisherExecuted = true"><a href="javascript:parent.publisherExecuted=true">Unsafe</a><iframe srcdoc="&lt;script>parent.parent.publisherExecuted=true&lt;/script>"></iframe></body></html>')
        const firstRecord = 112
        const textRecord = firstRecord + 256
        const imageRecord = textRecord + html.length
        const bytes = new Uint8Array(imageRecord + png.length)
        const data = new DataView(bytes.buffer)
        bytes.set(encode('BOOKMOBI'), 60)
        data.setUint16(76, 3)
        data.setUint32(78, firstRecord)
        data.setUint32(86, textRecord)
        data.setUint32(94, imageRecord)
        const record = new DataView(bytes.buffer, firstRecord, 256)
        record.setUint16(0, 1)
        record.setUint16(8, 1)
        record.setUint16(10, 4096)
        bytes.set(encode('MOBI'), firstRecord + 16)
        record.setUint32(20, 232)
        record.setUint32(24, 2)
        record.setUint32(28, 65001)
        record.setUint32(32, 1)
        record.setUint32(36, 6)
        record.setUint32(84, 248)
        record.setUint32(88, 5)
        record.setUint8(95, 9)
        record.setUint32(108, 2)
        record.setUint32(244, 0xffffffff)
        bytes.set(encode('Probe'), firstRecord + 248)
        bytes.set(html, textRecord)
        bytes.set(png, imageRecord)
        const book = await new MOBI({ unzlib: value => value }).open(new File([bytes], 'probe.mobi'))
        const view = document.createElement('foliate-view')
        view.style.cssText = 'display:block;width:800px;height:600px'
        document.body.append(view)
        await view.open(book)
        await view.goTo(0)
        const doc = view.renderer.getContents()[0].doc
        await doc.getElementById('illustration').decode()
        const range = doc.createRange()
        const text = doc.getElementById('passage').firstChild
        range.setStart(text, 0)
        range.setEnd(text, text.length)
        const cfi = view.getCFI(0, range)
        return {
            text: doc.getElementById('passage')?.textContent,
            executed: Boolean(window.publisherExecuted),
            scripts: doc.querySelectorAll('script,iframe,[onload],[onerror],a[href^="javascript:"]').length,
            csp: doc.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content,
            restoredText: view.resolveCFI(cfi).anchor(doc).toString(),
            imageWidth: doc.getElementById('illustration').naturalWidth,
        }
    })
    assert.equal(result.text, 'Readable book text.')
    assert.equal(result.restoredText, result.text)
    assert.equal(result.imageWidth, 4)
    assert.equal(result.executed, false)
    assert.equal(result.scripts, 0)
    assert.match(result.csp, /script-src 'none'/)
})

for (const type of ['text/html', 'application/xhtml+xml']) {
    test(`publisher sanitizer preserves Kindle anchors and media (${type})`, async t => {
        const { page, origin } = await createHarness(t)
        await page.goto(origin + '/blank')
        const result = await page.evaluate(async type => {
            const { sanitizePublisherDocument } = await import('/foliate-js/src/readflex_content_security.js')
            const imageUrl = URL.createObjectURL(new Blob(['image'], { type: 'image/png' }))
            const styleUrl = URL.createObjectURL(new Blob(['p { color: green; }'], { type: 'text/css' }))
            const doc = new DOMParser().parseFromString(`<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter</title>
                <style>p { color: green; }</style><link rel="stylesheet" href="${styleUrl}"/></head><body>
                <p aid="kindle-anchor">Read <em>this</em>.</p>
                <a href="#kindle-anchor">Jump</a><img src="${imageUrl}" alt="Diagram"/>
                <a id="mobi-link" href="filepos:123">MOBI</a>
                <a id="kindle-link" href="kindle:pos:fid:000A:off:0000000010">Kindle</a>
                <a id="invalid-link" href="kindle:javascript:alert(1)">Invalid</a>
                <a id="blob-link" href="${imageUrl}">Not a resource</a>
                <img id="foreign" src="blob:https://example.com/untrusted"/>
                <svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><text>Caption</text><script>alert(1)</script></svg>
                </body></html>`, type)
            sanitizePublisherDocument(doc)
            return {
                text: doc.querySelector('[aid="kindle-anchor"]')?.textContent,
                link: doc.querySelector('a')?.getAttribute('href'),
                image: doc.querySelector('img')?.getAttribute('src') === imageUrl,
                stylesheet: doc.querySelector('link')?.getAttribute('href') === styleUrl,
                blobLink: doc.getElementById('blob-link')?.getAttribute('href'),
                foreign: doc.getElementById('foreign')?.getAttribute('src'),
                mobiLink: doc.getElementById('mobi-link')?.getAttribute('href'),
                kindleLink: doc.getElementById('kindle-link')?.getAttribute('href'),
                invalidLink: doc.getElementById('invalid-link')?.getAttribute('href'),
                style: doc.querySelector('style')?.textContent,
                caption: doc.querySelector('svg text')?.textContent,
                active: doc.querySelectorAll('script,[onload]').length,
            }
        }, type)
        assert.deepEqual(result, { text: 'Read this.', link: '#kindle-anchor',
            image: true, stylesheet: true, blobLink: null, foreign: null,
            mobiLink: 'filepos:123', kindleLink: 'kindle:pos:fid:000A:off:0000000010', invalidLink: null,
            style: 'p { color: green; }', caption: 'Caption', active: 0 })
    })
}
