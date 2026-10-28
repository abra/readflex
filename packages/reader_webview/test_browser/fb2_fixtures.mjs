// Records what fb2.js makes of the vellum FB2 fixtures, in Chromium. Run
// from packages/reader_webview:
//
//     node --test test_browser/fb2_fixtures.mjs
//
// Writes packages/vellum/test/fixtures/fb2/expected.json: metadata, the
// converted XHTML of every section (the body's inner markup), sizes,
// the table of contents and link resolutions, which the Dart port must
// reproduce tree for tree.
import { readFile, writeFile, readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { createHarness } from './harness.mjs'
import test from 'node:test'

const fixtures = fileURLToPath(new URL('../../vellum/test/fixtures/fb2/', import.meta.url))

test('record fb2.js results for the fixtures', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    const expected = {}
    for (const name of (await readdir(fixtures)).filter(n => n.endsWith('.fb2')).sort()) {
        const data = (await readFile(path.join(fixtures, name))).toString('base64')
        expected[name] = await page.evaluate(async ({ data }) => {
            const { makeFB2 } = await import('/foliate-js/src/fb2.js')
            const bytes = Uint8Array.from(atob(data), c => c.charCodeAt(0))
            const book = await makeFB2(new Blob([bytes]))
            const cover = await book.getCover()
            const sections = []
            for (const section of book.sections) {
                const doc = section.createDocument()
                sections.push({
                    size: section.size,
                    linear: section.linear ?? null,
                    body: doc.body.innerHTML,
                })
            }
            const item = ({ label, href, subitems }) => ({ label, href, subitems: subitems ? subitems.map(item) : null })
            const hrefs = ['0', '1#0', '1#1', '2', '#ch2', '#n1', '#c1', '#ch1-1', '#nope', 'https://example.com']
            return {
                metadata: book.metadata,
                cover: cover ? { size: cover.size, type: cover.type } : null,
                sections,
                toc: book.toc.map(item),
                resolveHref: Object.fromEntries(hrefs.map(h => [h, book.resolveHref(h).index ?? null])),
                isExternal: Object.fromEntries(['https://x', '#id', '1#0', 'mailto:a'].map(u => [u, book.isExternal(u)])),
            }
        }, { data })
    }
    const out = path.join(fixtures, 'expected.json')
    await writeFile(out, JSON.stringify(expected, null, 1) + '\n')
    console.log(`wrote ${out}`)
})
