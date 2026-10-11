import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

// Fixed-layout pages draw saved highlights inside the page document, so the
// marks follow the page's scale and stay out of CFIs.
test('fixed-layout EPUB pages draw saved highlights in the page document', async t => {
    const { page, origin } = await createHarness(t)
    await openEpub(page, origin, '<html xmlns="http://www.w3.org/1999/xhtml"><head><meta name="viewport" content="width=800,height=600"/></head><body><p>Fixed page with a highlight</p></body></html>', true)
    const result = await page.evaluate(async () => {
        const { Overlayer } = await import('/foliate-js/src/overlayer.js')
        const view = window.testView
        view.addEventListener('draw-annotation', e => e.detail.draw(Overlayer.highlight, { color: 'yellow' }))
        const { doc, index, overlayer } = view.renderer.getContents()[0]
        const text = doc.querySelector('p').firstChild
        const range = doc.createRange()
        range.setStart(text, 0)
        range.setEnd(text, 10)
        const cfi = view.getCFI(index, range)
        await view.addAnnotation({ value: cfi })
        const svg = doc.body.lastElementChild
        return {
            overlayer: !!overlayer,
            inert: svg.hasAttribute('cfi-inert'),
            rects: svg.querySelectorAll('rect').length,
            sameCfi: view.getCFI(index, range) === cfi,
        }
    })
    assert.deepEqual(result, { overlayer: true, inert: true, rects: 1, sameCfi: true })
})
