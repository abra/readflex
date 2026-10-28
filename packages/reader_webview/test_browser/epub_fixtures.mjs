// Records what epub.js makes of the vellum EPUB fixtures, in Chromium, so
// the Dart port is tested against the browser. Run from
// packages/reader_webview:
//
//     node test_browser/epub_fixtures.mjs
//
// Each fixture is a directory under packages/vellum/test/fixtures/epub
// served to EPUB.init() as loadText/loadBlob/getSize; the result goes to
// expected.json next to them.
import { readFile, writeFile, readdir, stat } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { createHarness } from './harness.mjs'
import test from 'node:test'

const fixtures = fileURLToPath(new URL('../../vellum/test/fixtures/epub/', import.meta.url))

async function listFiles(dir, prefix = '') {
    const out = {}
    for (const name of (await readdir(dir)).sort()) {
        const full = path.join(dir, name)
        if ((await stat(full)).isDirectory()) Object.assign(out, await listFiles(full, prefix + name + '/'))
        else out[prefix + name] = (await readFile(full)).toString('base64')
    }
    return out
}

test('record epub.js results for the fixtures', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    const expected = {}
    for (const name of (await readdir(fixtures)).sort()) {
        const dir = path.join(fixtures, name)
        if (!(await stat(dir)).isDirectory()) continue
        const files = await listFiles(dir)
        expected[name] = await page.evaluate(async ({ files }) => {
            const { EPUB } = await import('/foliate-js/src/epub.js')
            const bytes = Object.fromEntries(Object.entries(files).map(([k, v]) =>
                [k, Uint8Array.from(atob(v), c => c.charCodeAt(0))]))
            const book = await new EPUB({
                loadText: async name => name in bytes ? new TextDecoder().decode(bytes[name]) : null,
                loadBlob: async name => name in bytes ? new Blob([bytes[name]]) : null,
                getSize: name => bytes[name]?.length ?? 0,
            }).init()
            const item = ({ label, href, subitems, type }) =>
                ({ label, href: href ?? null, subitems: subitems ? subitems.map(item) : null, ...(type ? { type } : {}) })
            const cover = await book.getCover()
            const hrefs = ['OEBPS/text/chapter 1.xhtml#part-b', 'OEBPS/text/chapter%201.xhtml', 'OEBPS/text/notes.xhtml',
                'OEBPS/missing.xhtml', 'OPS/ch,1.html#s1', 'OPS/ch%2C1.html', 'OPS/sub/ch2.html', 'p2.xhtml#x']
            const cfis = ['epubcfi(/6/4!/4/2/1:0)', 'epubcfi(/6/4[first-chapter]!/4)', 'epubcfi(/6/4[wrong-id]!/4)',
                'epubcfi(/6/2,/4/2/1:0,/4/2/1:5)', 'epubcfi(/6/99!/4)', 'epubcfi(/6/2!/4)']
            return {
                sections: book.sections.map(s => ({ id: s.id, size: s.size, cfi: s.cfi, linear: s.linear ?? null, pageSpread: s.pageSpread ?? null,
                    mediaOverlay: s.mediaOverlay?.href ?? null })),
                toc: book.toc?.map(item) ?? null,
                pageList: book.pageList?.map(item) ?? null,
                landmarks: book.landmarks?.map(item) ?? null,
                dir: book.dir ?? null,
                rendition: book.rendition,
                media: book.media,
                metadata: book.metadata,
                cover: cover ? { size: cover.size, type: cover.type } : null,
                navPath: book.resources.navPath ?? null,
                ncxPath: book.resources.ncxPath ?? null,
                coverHref: book.resources.cover?.href ?? null,
                manifest: book.resources.manifest.map(({ id, href, mediaType, properties }) => ({ id, href, mediaType, properties: properties ?? null })),
                resolveHref: Object.fromEntries(hrefs.map(h => [h, book.resolveHref(h)?.index ?? null])),
                resolveCfi: Object.fromEntries(cfis.map(c => [c, book.resolveCFI(c).index])),
            }
        }, { files })
    }
    const out = path.join(fixtures, 'expected.json')
    await writeFile(out, JSON.stringify(expected, null, 1) + '\n')
    console.log(`wrote ${out}`)
})
