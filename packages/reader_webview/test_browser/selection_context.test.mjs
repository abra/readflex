import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

async function contextHarness(t) {
    const harness = await createHarness(t)
    await harness.page.goto(harness.origin + '/blank')
    await harness.page.evaluate(async () => {
        const { buildSelectionContext } = await import('/foliate-js/src/readflex_selection_context.js')
        window.buildSelectionContext = buildSelectionContext
        window.rangeForOffsets = (root, start, end) => {
            const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
            const range = document.createRange()
            let offset = 0
            let node
            while ((node = walker.nextNode())) {
                if (start >= offset && start < offset + node.length) {
                    range.setStart(node, start - offset)
                }
                if (end > offset && end <= offset + node.length) {
                    range.setEnd(node, end - offset)
                    return range
                }
                offset += node.length
            }
            throw new Error('Selection outside fixture')
        }
    })
    return harness
}

test('sentence context is invariant under inline markup and text-node splits', async t => {
    const { page } = await contextHarness(t)
    const results = await page.evaluate(() => {
        const results = []
        const selected = 'power'
        for (let index = 0; index < 8; index++) {
            const sentence = `Sentence ${index} repeats power and power.`
            const text = `Earlier power. ${sentence} Later power.`
            for (const chunkSize of [1, 2, 5, text.length]) {
                const paragraph = document.createElement('p')
                for (let offset = 0; offset < text.length; offset += chunkSize) {
                    const span = document.createElement(offset % 2 === 0 ? 'em' : 'span')
                    const child = document.createElement('b')
                    child.textContent = text.slice(offset, offset + chunkSize)
                    span.append(child)
                    paragraph.append(span)
                }
                document.body.replaceChildren(paragraph)
                for (const localOffset of [sentence.indexOf(selected), sentence.lastIndexOf(selected)]) {
                    const start = 'Earlier power. '.length + localOffset
                    const range = window.rangeForOffsets(paragraph, start, start + selected.length)
                    const selection = getSelection()
                    selection.removeAllRanges()
                    selection.addRange(range)
                    const html = paragraph.innerHTML
                    const result = window.buildSelectionContext(range)
                    results.push({
                        result, sentence,
                        expectedMarked: sentence.slice(0, localOffset) + '[[' + selected + ']]'
                            + sentence.slice(localOffset + selected.length),
                        text: range.toString(), nativeText: selection.toString(),
                        unchanged: paragraph.innerHTML === html,
                        sameEndpoints: selection.anchorNode === range.startContainer
                            && selection.anchorOffset === range.startOffset
                            && selection.focusNode === range.endContainer
                            && selection.focusOffset === range.endOffset,
                    })
                }
            }
        }
        return results
    })
    assert.equal(results.length, 64)
    for (const { result, sentence, expectedMarked, text, nativeText, unchanged, sameEndpoints } of results) {
        assert.deepEqual(result, { contextText: sentence, markedContextText: expectedMarked })
        assert.equal(text, 'power')
        assert.equal(nativeText, 'power')
        assert.equal(unchanged, true, 'extracting context must not mutate the DOM')
        assert.equal(sameEndpoints, true, 'extracting context must not change native selection handles')
    }
})

test('element-offset ranges produce the same context as text-offset ranges', async t => {
    const { page } = await contextHarness(t)
    const results = await page.evaluate(() => {
        document.body.innerHTML = '<p>Before. The <span><b>power</b> <em>bank</em></span> works. After.</p>'
        const paragraph = document.querySelector('p')
        const span = paragraph.querySelector('span')
        const inner = document.createRange()
        inner.selectNodeContents(span)
        const outer = document.createRange()
        outer.selectNode(span)
        const mixed = inner.cloneRange()
        mixed.setEnd(span.lastChild.firstChild, 4)
        return [inner, outer, mixed].map(range => window.buildSelectionContext(range))
    })
    for (const result of results) assert.deepEqual(result, {
        contextText: 'The power bank works.',
        markedContextText: 'The [[power bank]] works.',
    })
})

test('context never crosses a neighbouring block without sentence punctuation', async t => {
    const { page } = await contextHarness(t)
    const result = await page.evaluate(() => {
        document.body.innerHTML = '<div><p>Unrelated prefix without punctuation</p>This <b>word</b> works.<p>Unrelated suffix without punctuation</p></div>'
        const range = document.createRange()
        range.selectNodeContents(document.querySelector('b'))
        return window.buildSelectionContext(range)
    })
    assert.deepEqual(result, { contextText: 'This word works.', markedContextText: 'This [[word]] works.' })
})

test('cross-paragraph and long selections preserve the exact selected text once', async t => {
    const { page } = await contextHarness(t)
    const results = await page.evaluate(() => {
        document.body.innerHTML = `<p>Unselected prefix. First selected sentence.</p><p>${'Selected text. '.repeat(400)}Last selected sentence. Unselected suffix.</p>`
        const [first, last] = document.querySelectorAll('p')
        const ranges = []
        const cross = document.createRange()
        cross.setStart(first.firstChild, 'Unselected prefix. '.length)
        cross.setEnd(last.firstChild, last.textContent.indexOf(' Unselected suffix.'))
        ranges.push(cross)
        const same = document.createRange()
        same.setStart(last.firstChild, 0)
        same.setEnd(cross.endContainer, cross.endOffset)
        ranges.push(same)
        return ranges.map(range => ({ text: range.toString(), result: window.buildSelectionContext(range) }))
    })
    for (const { text, result } of results) {
        const expected = text.replace(/\s+/g, ' ').trim()
        assert.equal(result.contextText, expected)
        assert.equal(result.markedContextText, `[[${expected}]]`)
        assert.ok(!result.contextText.includes('Unselected'))
    }
})

test('context collection and segmentation stay bounded in very large blocks', async t => {
    const { page } = await contextHarness(t)
    const result = await page.evaluate(() => {
        const inputLengths = []
        const Segmenter = Intl.Segmenter
        Intl.Segmenter = class extends Segmenter {
            segment(text) { inputLengths.push(text.length); return super.segment(text) }
        }
        let steps = 0
        const createWalker = document.createTreeWalker.bind(document)
        document.createTreeWalker = (...args) => {
            const walker = createWalker(...args)
            for (const name of ['nextNode', 'previousNode', 'lastChild']) {
                const step = walker[name].bind(walker)
                walker[name] = () => { steps++; return step() }
            }
            return walker
        }
        const paragraph = document.createElement('p')
        const prefix = 'Earlier sentence. '.repeat(60000)
        const text = `${prefix}The power bank works. ${'Later sentence. '.repeat(60000)}`
        const node = document.createTextNode(text)
        paragraph.append(node)
        document.body.replaceChildren(paragraph)
        // Forbid accidentally materialising the full block via textContent.
        Object.defineProperty(paragraph, 'textContent', { get() { throw new Error('Full block scan') } })
        const range = document.createRange()
        const start = prefix.length + 'The '.length
        range.setStart(node, start)
        range.setEnd(node, start + 'power'.length)
        const result = window.buildSelectionContext(range)
        const textSteps = steps
        paragraph.innerHTML = `${'<span></span>'.repeat(4000)}<b>word</b>${'<span></span>'.repeat(4000)}`
        range.selectNodeContents(paragraph.querySelector('b'))
        const limited = window.buildSelectionContext(range)
        return { result, limited, textSteps, steps, inputLengths }
    })
    assert.deepEqual(result.result, {
        contextText: 'The power bank works.',
        markedContextText: 'The [[power]] bank works.',
    })
    assert.deepEqual(result.limited, { contextText: 'word', markedContextText: '[[word]]' })
    assert.ok(result.inputLengths.length >= 1)
    assert.ok(Math.max(...result.inputLengths) < 8200, 'never segment the whole book block')
    assert.ok(result.textSteps < 8, 'large text nodes must be sliced locally')
    assert.ok(result.steps < 530, 'empty markup must not defeat the traversal budget')
})
