// Records what foliate-js makes of every EPUB, FB2 and MOBI book in a
// folder, in Chromium, for vellum's corpus parity test. Run from
// packages/reader_webview:
//
//     VELLUM_CORPUS=~/Books node --test test_browser/corpus_snapshot.mjs
//
// Writes VELLUM_SNAPSHOT (default: vellum-parity.json inside the corpus).
// Each section is recorded as a hash of its canonical document tree, so
// the snapshot stays small; VELLUM_TREES=1 records the canonical trees
// themselves, which lets the Dart side point at the first difference.
import { readFile, writeFile, readdir, stat } from 'node:fs/promises'
import path from 'node:path'
import { createHarness } from './harness.mjs'
import test from 'node:test'

const extensions = /\.(epub|fb2|fb2\.zip|fbz|mobi|azw|azw3|prc)$/i

async function listBooks(dir) {
    const out = []
    for (const name of (await readdir(dir)).sort()) {
        const full = path.join(dir, name)
        const info = await stat(full)
        if (info.isDirectory()) out.push(...await listBooks(full))
        else if (extensions.test(name)) out.push(full)
    }
    return out
}

test('record foliate-js results for the corpus', async t => {
    const corpus = process.env.VELLUM_CORPUS
    if (!corpus) {
        t.skip('VELLUM_CORPUS is not set')
        return
    }
    const trees = process.env.VELLUM_TREES === '1'
    const { page, origin, routes } = await createHarness(t)
    await page.goto(origin + '/blank')
    const files = await listBooks(corpus)
    const snapshot = { recordedAt: new Date().toISOString(), engine: 'chromium', books: {} }
    for (const [i, file] of files.entries()) {
        routes.set(`/book${i}`, await readFile(file))
        const key = path.relative(corpus, file)
        snapshot.books[key] = await page.evaluate(async ({ url, name, trees }) => {
            // The canonical form of a document: element names, attributes
            // in name order with their whitespace folded (a character
            // reference keeps a newline the parser would fold, and the
            // Dart side cannot tell the two apart), text with CRLF
            // folded; length-prefixed so the string is unambiguous and
            // hashes the same in Dart.
            const s = x => `${x.length}:${x}`
            const attr = v => v.replace(/[\t\n\r]/g, ' ')
            const canonical = (node, dropImgAltTitle) => {
                if (node.nodeType === 3 || node.nodeType === 4) return 't' + s(node.data.replace(/\r\n?/g, '\n'))
                if (node.nodeType !== 1) return ''
                const attrs = [...node.attributes]
                    .filter(a => a.name !== 'xmlns' && !a.name.startsWith('xmlns:'))
                    .filter(a => !(dropImgAltTitle && node.localName === 'img' && (a.name === 'alt' || a.name === 'title')))
                    .map(a => [a.name, a.value]).sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0)
                let out = 'e' + s(node.localName) + 'a' + attrs.length
                for (const [k, v] of attrs) out += s(k) + s(attr(v))
                const children = [...node.childNodes].map(c => canonical(c, dropImgAltTitle)).filter(Boolean)
                out += 'c' + children.length
                for (const c of children) out += c
                return out
            }
            const digest = async text => {
                const bytes = new TextEncoder().encode(text)
                const hash = await crypto.subtle.digest('SHA-256', bytes)
                return { hash: [...new Uint8Array(hash)].map(b => b.toString(16).padStart(2, '0')).join(''), ...(trees ? { tree: text } : {}) }
            }
            const item = ({ label, href, subitems, type }) =>
                ({ label, href: href ?? null, subitems: subitems ? subitems.map(item) : null, ...(type ? { type } : {}) })
            const navHrefs = items => (items ?? []).flatMap(i => [i.href, ...navHrefs(i.subitems)]).filter(h => h != null)
            const isZip = async file => {
                const arr = new Uint8Array(await file.slice(0, 4).arrayBuffer())
                return arr[0] === 0x50 && arr[1] === 0x4b && arr[2] === 0x03 && arr[3] === 0x04
            }
            const makeZipLoader = async file => {
                const { configure, ZipReader, BlobReader, TextWriter, BlobWriter } = await import('/foliate-js/src/vendor/zip.js')
                configure({ useWebWorkers: false })
                const entries = await new ZipReader(new BlobReader(file)).getEntries()
                const map = new Map(entries.map(entry => [entry.filename, entry]))
                const load = f => (name, ...args) => map.has(name) ? f(map.get(name), ...args) : null
                return {
                    entries,
                    loadText: load(entry => entry.getData(new TextWriter())),
                    loadBlob: load((entry, type) => entry.getData(new BlobWriter(type))),
                    getSize: name => map.get(name)?.uncompressedSize ?? 0,
                }
            }
            const started = performance.now()
            const blob = await (await fetch(url)).blob()
            const file = new File([blob], name)
            let book, kind
            try {
                if (/\.fb2$/i.test(name)) {
                    const { makeFB2 } = await import('/foliate-js/src/fb2.js')
                    book = await makeFB2(file); kind = 'fb2'
                } else if (await isZip(file)) {
                    const loader = await makeZipLoader(file)
                    if (/\.(fb2\.zip|fbz)$/i.test(name)) {
                        const { makeFB2 } = await import('/foliate-js/src/fb2.js')
                        const entry = loader.entries.find(e => e.filename.endsWith('.fb2')) ?? loader.entries[0]
                        book = await makeFB2(await loader.loadBlob(entry.filename)); kind = 'fb2'
                    } else {
                        const { EPUB } = await import('/foliate-js/src/epub.js')
                        book = await new EPUB(loader).init(); kind = 'epub'
                    }
                } else {
                    const { MOBI } = await import('/foliate-js/src/mobi.js')
                    const fflate = await import('/foliate-js/src/vendor/fflate.js')
                    book = await new MOBI({ unzlib: fflate.unzlibSync }).open(file)
                    kind = book.constructor.name === 'KF8' ? 'kf8' : 'mobi6'
                }
            } catch (e) {
                return { error: String(e?.message ?? e) }
            }
            const openMs = performance.now() - started
            let cover = null
            try { const c = await book.getCover?.(); cover = c ? { size: c.size, type: c.type } : null } catch (e) { cover = { error: String(e?.message ?? e) } }
            const sections = []
            const sectionsStarted = performance.now()
            for (const section of book.sections) {
                const entry = {
                    id: section.id ?? null,
                    size: section.size ?? null,
                    linear: section.linear ?? null,
                    pageSpread: section.pageSpread ?? null,
                    cfi: section.cfi ?? null,
                    mediaType: section.mediaType ?? null,
                }
                if (section.createDocument) {
                    try {
                        const doc = await section.createDocument()
                        const root = kind === 'fb2' ? doc.body : doc.documentElement
                        entry.parserError = !!doc.querySelector('parsererror')
                        const text = kind === 'fb2'
                            ? [...root.childNodes].map(c => canonical(c, true)).filter(Boolean).join('')
                            : canonical(root, false)
                        Object.assign(entry, await digest(text))
                        entry.textLength = root.textContent.length
                    } catch (e) {
                        entry.error = String(e?.message ?? e)
                    }
                }
                sections.push(entry)
            }
            const sectionsMs = performance.now() - sectionsStarted
            const resolved = {}
            for (const href of new Set([...navHrefs(book.toc), ...navHrefs(book.landmarks), ...navHrefs(book.pageList)])) {
                try {
                    const target = await book.resolveHref(href)
                    resolved[href] = target ? { index: target.index, fragment: typeof target.anchor === 'string' ? target.anchor : null } : null
                } catch (e) {
                    resolved[href] = { error: String(e?.message ?? e) }
                }
            }
            return {
                kind,
                bytes: blob.size,
                openMs: Math.round(openMs),
                sectionsMs: Math.round(sectionsMs),
                metadata: book.metadata ?? null,
                cover,
                dir: book.dir ?? null,
                rendition: book.rendition ?? null,
                sections,
                toc: book.toc?.map(item) ?? null,
                landmarks: book.landmarks?.map(item) ?? null,
                pageList: book.pageList?.map(item) ?? null,
                resolveHref: resolved,
            }
        }, { url: `${origin}/book${i}`, name: path.basename(file), trees })
        routes.delete(`/book${i}`)
        const r = snapshot.books[key]
        console.log(`${key}: ${r.error ? 'ERROR ' + r.error : `${r.kind} ${r.sections.length} sections, ${r.openMs} ms`}`)
    }
    const out = process.env.VELLUM_SNAPSHOT ?? path.join(corpus, 'vellum-parity.json')
    await writeFile(out, JSON.stringify(snapshot, null, 1) + '\n')
    console.log(`wrote ${out} (${files.length} books)`)
})
