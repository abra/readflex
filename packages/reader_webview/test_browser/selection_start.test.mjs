import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

for (const [name, html, selected, offset] of [
    ['repeated word', 'power and power bank', 'power', 12],
    ['inline word', 'The shut<em>ting</em> off mechanism.', 'shutting', 5],
    ['Cyrillic', 'Some words: перевод текста.', 'перевод', 15],
    ['Japanese', '東京に行きます。', '東京', 0],
    ['RTL', '<span dir="rtl">مرحبا بالعالم</span>', 'مرحبا', 1],
    ['supplementary Unicode letters', 'Word: \u{10400}\u{10428}\u{10428} end.', '\u{10400}\u{10428}\u{10428}', 8],
]) {
    test(`reader long press selects the ${name} using browser word boundaries`, async t => {
        const { page, origin } = await createHarness(t)
        await page.goto(origin + '/harness.html')
        const result = await page.evaluate(async ({ html, offset }) => {
            const { installCustomSelectionStart } = await import('/foliate-js/src/readflex_selection_start.js')
            document.body.innerHTML = `<p id="text" style="font:24px/2 serif;margin:100px 20px">${html}</p>`
            const paragraph = document.getElementById('text')
            const remove = installCustomSelectionStart({ doc: document })
            const walker = document.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT)
            let node, count = 0
            while (walker.nextNode()) {
                node = walker.currentNode
                if (count + node.length > offset) break
                count += node.length
            }
            const glyph = document.createRange()
            glyph.setStart(node, offset - count); glyph.setEnd(node, offset - count + 1)
            const rect = glyph.getBoundingClientRect()
            const press = detail => window.dispatchEvent(new CustomEvent('readflex-long-press', { detail }))
            press({ x: (rect.left + rect.width / 2) / innerWidth, y: (rect.top + rect.height / 2) / innerHeight })
            const text = getSelection().toString()
            const start = getSelection().getRangeAt(0).cloneRange()
            press({ x: 0.99, y: 0.9 })
            press({ x: NaN, y: 0 })
            press({ x: -1, y: 0 })
            const retained = getSelection().toString()
            remove()
            getSelection().removeAllRanges()
            press({ x: rect.left / innerWidth, y: rect.top / innerHeight })
            return { text, retained, cleared: getSelection().isCollapsed,
                occurrence: start.startContainer.textContent.slice(0, start.startOffset) }
        }, { html, offset })
        assert.equal(result.text, selected)
        assert.equal(result.retained, selected, 'blank space and malformed coordinates do not replace selection')
        assert.equal(result.cleared, true, 'disposed handlers do not select text')
        if (name === 'repeated word') assert.equal(result.occurrence, 'power and ')
    })
}
