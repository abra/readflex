// Records what mobi.js makes of the vellum MOBI fixtures, in Chromium.
// Run from packages/reader_webview:
//
//     node --test test_browser/mobi_fixtures.mjs
//
// Writes packages/vellum/test/fixtures/mobi/expected.json. With
// MOBI_FILES=/a.mobi:/b.azw3 it records those files instead, into
// MOBI_EXPECTED (default: a file next to the first one), for ad hoc
// parity runs on real books.
import { readFile, writeFile, readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { createHarness } from './harness.mjs'
import test from 'node:test'

const fixtures = fileURLToPath(new URL('../../vellum/test/fixtures/mobi/', import.meta.url))

test('record mobi.js results for the fixtures', async t => {
    const { page, origin, routes } = await createHarness(t)
    await page.goto(origin + '/blank')
    const extra = process.env.MOBI_FILES?.split(':').filter(Boolean)
    const files = extra ?? (await readdir(fixtures)).filter(n => /\.(mobi|azw3?|prc)$/i.test(n)).sort().map(n => path.join(fixtures, n))
    const expected = {}
    for (const [i, file] of files.entries()) {
        // Served over the harness rather than passed through evaluate: real
        // books are tens of megabytes.
        routes.set(`/book${i}`, await readFile(file))
        expected[path.basename(file)] = await page.evaluate(async ({ url }) => {
            const { MOBI } = await import('/foliate-js/src/mobi.js')
            const fflate = await import('/foliate-js/src/vendor/fflate.js')
            const unzlib = fflate.unzlibSync
            const blob = await (await fetch(url)).blob()
            const book = await new MOBI({ unzlib }).open(new File([blob], 'book'))
            const isKF8 = book.constructor.name === 'KF8'
            const item = ({ label, href, subitems, type }) => ({ label, href, subitems: subitems ? subitems.map(item) : null, ...(type ? { type } : {}) })
            const describe = node => {
                if (node.nodeType === 3) return node.data
                if (node.nodeType !== 1) return null
                return { tag: node.localName, attrs: Object.fromEntries([...node.attributes].map(a => [a.name, a.value])),
                    children: [...node.childNodes].map(describe).filter(x => x !== null) }
            }
            const cover = await book.getCover()
            const sections = []
            for (const section of book.sections) {
                if (!section.createDocument) { sections.push({ linear: section.linear ?? null }); continue }
                const doc = await section.createDocument()
                sections.push({
                    size: section.size,
                    linear: section.linear ?? null,
                    pageSpread: section.pageSpread ?? null,
                    document: describe(doc.documentElement),
                })
            }
            const resolved = {}
            for (const href of [...(book.toc ?? []), ...(book.landmarks ?? [])].flatMap(i => [i.href, ...(i.subitems?.map(s => s.href) ?? [])])) {
                const target = await book.resolveHref(href)
                resolved[href] = target ? target.index : null
            }
            return {
                kind: isKF8 ? 'kf8' : 'mobi6',
                metadata: book.metadata,
                cover: cover ? cover.size : null,
                sections,
                toc: book.toc?.map(item) ?? null,
                landmarks: book.landmarks?.map(item) ?? null,
                dir: book.dir ?? null,
                rendition: book.rendition ?? null,
                resolveHref: resolved,
            }
        }, { url: `${origin}/book${i}` })
    }
    const out = process.env.MOBI_EXPECTED ?? (extra ? path.join(path.dirname(extra[0]), 'mobi_expected.json') : path.join(fixtures, 'expected.json'))
    await writeFile(out, JSON.stringify(expected, null, 1) + '\n')
    console.log(`wrote ${out}`)
})
