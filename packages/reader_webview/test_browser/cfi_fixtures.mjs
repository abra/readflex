// Records what epubcfi.js does with the vellum CFI fixtures, in Chromium,
// so the Dart port is tested against the browser rather than against
// itself. Run from packages/reader_webview:
//
//     node test_browser/cfi_fixtures.mjs
//
// Writes packages/vellum/test/fixtures/cfi/expected.json. Text nodes are
// named by their index in document order (comments excluded), which the
// Dart test reproduces over the same files.
import { readFile, writeFile, readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { chromium } from 'playwright'

const fixtures = fileURLToPath(new URL('../../vellum/test/fixtures/cfi/', import.meta.url))
const assets = fileURLToPath(new URL('../assets/', import.meta.url))

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage()
await page.goto('about:blank')
await page.addScriptTag({ content: await readFile(path.join(assets, 'foliate-js/src/epubcfi.js'), 'utf8').then(
    source => source.replaceAll(/^export /gm, '').concat('\nwindow.CFI = { parse, compare, fromRange, toRange, fromElements, toElement, collapse, isCFI, joinIndir, fake }'),
) })

const expected = {}
for (const name of (await readdir(fixtures)).filter(n => n.endsWith('.xhtml') || n.endsWith('.opf')).sort()) {
    const source = await readFile(path.join(fixtures, name), 'utf8')
    expected[name] = await page.evaluate(({ source, withFilter }) => {
      try {
        const doc = new DOMParser().parseFromString(source, 'application/xhtml+xml')
        if (doc.querySelector('parsererror')) throw new Error('fixture does not parse')
        const texts = []
        const elements = []
        const walk = node => {
            for (const child of node.childNodes) {
                if (child.nodeType === 3 || child.nodeType === 4) texts.push(child)
                else if (child.nodeType === 1) { elements.push(child); walk(child) }
            }
        }
        walk(doc.documentElement)
        const filter = withFilter ? node => node.nodeType === 1 && node.hasAttribute('data-reject')
            ? NodeFilter.FILTER_REJECT
            : node.nodeType === 1 && node.hasAttribute('data-skip') ? NodeFilter.FILTER_SKIP
            : NodeFilter.FILTER_ACCEPT : undefined
        const describe = (node, offset) => ({ text: texts.indexOf(node), offset })
        const rangeOf = (a, ao, b, bo) => {
            const range = doc.createRange()
            range.setStart(a, ao)
            range.setEnd(b, bo)
            return range
        }
        const points = []
        for (const [i, text] of texts.entries()) {
            const length = text.nodeValue.length
            for (const offset of new Set([0, Math.floor(length / 2), length])) {
                const cfi = CFI.fromRange(rangeOf(text, offset, text, offset), filter)
                const back = CFI.toRange(doc, CFI.parse(cfi), filter)
                points.push({ text: i, offset, cfi, resolved: describe(back.startContainer, back.startOffset) })
            }
        }
        const ranges = []
        for (let i = 0; i + 1 < texts.length; i++) {
            const a = texts[i], b = texts[i + 1]
            const ao = Math.min(1, a.nodeValue.length), bo = Math.min(2, b.nodeValue.length)
            const cfi = CFI.fromRange(rangeOf(a, ao, b, bo), filter)
            // Each end on its own: a DOM Range whose end precedes its start
            // (a point inside a rejected node resolves elsewhere) collapses,
            // which is the Range's doing, not the CFI's.
            const parsed = CFI.parse(cfi)
            const start = CFI.toRange(doc, CFI.collapse(parsed), filter)
            const end = CFI.toRange(doc, CFI.collapse(parsed, true), filter)
            ranges.push({
                start: { text: i, offset: ao }, end: { text: i + 1, offset: bo }, cfi,
                resolved: { start: describe(start.startContainer, start.startOffset), end: describe(end.startContainer, end.startOffset) },
            })
        }
        const ids = [...doc.querySelectorAll('[id]')].map(el => el.id)
        // epubcfi.js cannot address the root's own children (head, body):
        // their parent is the document element, which has no steps.
        const elementCfis = elements.filter(el => el.parentNode !== doc.documentElement).map(el => ({
            id: el.id || null,
            tag: el.localName,
            cfi: CFI.fromElements([el])[0],
            // toElement takes one path, as epub.js hands it the spine step.
            resolvedTag: CFI.toElement(doc, CFI.parse(CFI.fromElements([el])[0])[0]).localName,
        }))
        // fromElements wants siblings below the root's children: the body,
        // or a package document's spine (epub.js indexes its itemrefs).
        const body = doc.body ?? doc.querySelector('spine')
        const bodyChildren = body ? [...body.children] : []
        const fromElements = bodyChildren.length ? CFI.fromElements(bodyChildren) : []
        const toElement = fromElements.map((cfi, i) => ({ cfi, tag: bodyChildren[i].localName, id: bodyChildren[i].id || null,
            resolvedTag: CFI.toElement(doc, CFI.parse(cfi)[0]).localName }))
        return { textCount: texts.length, points, ranges, ids, elementCfis, fromElements, toElement }
      } catch (error) { throw new Error(`${error.message}\n${error.stack}`) }
    }, { source, withFilter: name === 'skipped.xhtml' }).catch(error => { throw new Error(`${name}: ${error.message}`) })
}

const out = path.join(fixtures, 'expected.json')
await writeFile(out, JSON.stringify(expected, null, 1) + '\n')
console.log(`wrote ${out}`)
await browser.close()
