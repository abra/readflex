import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness, openEpub } from './harness.mjs'

const chapter = `<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Selection</title>
<style>body { font: 20px/1.5 serif; } p { margin: 0 0 20px; }</style></head><body>
${Array.from({ length: 60 }, (_, i) => `<p id="p${i}">Paragraph ${i}. The power bank keeps devices running. Select these words without turning the page.</p>`).join('')}
</body></html>`

async function openVerticalBook(t, { runtime = false, appleTouch = false, androidTouch = false, pageTurnStyle = 'vertical', fixedLayout = false } = {}) {
    const harness = await createHarness(t)
    const { page, origin } = harness
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    t.after(() => assert.deepEqual(errors, [], 'reader must not throw during selection'))
    await page.setViewportSize({ width: 390, height: 844 })
    if (appleTouch) await page.addInitScript(() => {
        Object.defineProperty(navigator, 'userAgent', { value: 'iPhone AppleWebKit' })
    })
    if (androidTouch) await page.addInitScript(() => {
        Object.defineProperty(navigator, 'userAgent', { value: 'Android Chrome' })
        Object.defineProperty(navigator, 'platform', { value: 'Linux armv8l' })
    })
    if (runtime) {
        // Only replace transport: exercise book.js and its actual EPUB loader
        // through the supported directory-entry interface, without a ZIP fixture.
        const files = {
            'META-INF/container.xml': '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
            'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">selection</dc:identifier><dc:title>Selection</dc:title><dc:language>en</dc:language></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="chapter"/></spine></package>',
            'chapter.xhtml': chapter,
        }
        if (fixedLayout) {
            files['content.opf'] = files['content.opf'].replace('</metadata>',
                '<meta property="rendition:layout">pre-paginated</meta></metadata>')
            files['chapter.xhtml'] = chapter.replace('</head>', '<meta name="viewport" content="width=390,height=844"/></head>')
        }
        await page.route('**/foliate-js/src/remote_file.js', route => route.fulfill({
            contentType: 'text/javascript',
            body: `export class RemoteFile {
                async open() {
                    return { isDirectory: true, fullPath: '', createReader: () => ({
                        readEntries: callback => callback(Object.entries(${JSON.stringify(files)}).map(([name, text]) => ({
                            isFile: true, fullPath: '/' + name,
                            file: callback => callback(new File([text], name)),
                        }))),
                    }) }
                }
            }`,
        }))
        const params = new URLSearchParams({
            url: JSON.stringify(origin + '/selection.epub'),
            style: JSON.stringify({
                pageTurnStyle, allowScript: false,
                fontName: 'serif', fontColor: '#000000', backgroundColor: '#ffffff',
                fontSize: 1.25, textScale: 1, fontWeight: 400, spacing: 1.5,
                topMargin: 24, bottomMargin: 24, sideMargin: 8,
                maxColumnCount: 1, backgroundImage: 'none', writingMode: 'horizontal-tb',
            }),
            readingRules: JSON.stringify({ convertChineseMode: 'none' }),
        })
        await page.goto(origin + '/foliate-js/index.html?' + params)
        await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
        await page.evaluate(() => { window.testView = window.reader.view })
    } else {
        await openEpub(page, origin, chapter)
        await page.evaluate(() => {
            const view = window.testView
            view.style.cssText = 'display:block;width:390px;height:844px'
            const renderer = view.renderer
            renderer.setAttribute('flow', 'paginated')
            renderer.setAttribute('page-turn-axis', 'vertical')
            renderer.setAttribute('max-column-count', '1')
            renderer.setAttribute('gap', '8%')
            renderer.setAttribute('top-margin', '24px')
            renderer.setAttribute('bottom-margin', '24px')
        })
    }
    await page.evaluate(async () => {
        window.testView.style.cssText = 'display:block;width:390px;height:844px'
        await window.testView.goTo(0)
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    })
    // WebKit may still be loading the replacement iframe after goTo/resize.
    // Wait for the fixture DOM, not just for two host animation frames.
    await page.waitForFunction(() => {
        const doc = window.testView.renderer.getContents()[0]?.doc
        return doc?.getElementById('p0') && doc.getElementById('p59')
    })
    await page.evaluate(() => {
        window.testView.renderer.setAttribute('animated', '')
        const doc = window.testView.renderer.getContents()[0].doc
        window.sendTouch = (type, x = 190, y = 500) => {
            const touch = { identifier: 1, target: doc.body, screenX: x, screenY: y, clientX: x, clientY: y }
            const event = new Event(type, { bubbles: true, cancelable: true })
            Object.defineProperties(event, {
                touches: { value: type === 'touchend' || type === 'touchcancel' ? [] : [touch] },
                changedTouches: { value: [touch] },
            })
            doc.body.dispatchEvent(event)
            return event.defaultPrevented
        }
        window.selectWords = () => {
            const range = doc.createRange()
            range.setStart(doc.getElementById('p0').firstChild, 0)
            range.setEnd(doc.getElementById('p0').firstChild, 12)
            doc.getSelection().removeAllRanges()
            doc.getSelection().addRange(range)
            doc.dispatchEvent(new Event('selectionchange'))
        }
        window.snapCalls = 0
        const snap = window.testView.renderer.snap?.bind(window.testView.renderer)
        if (snap) window.testView.renderer.snap = (...args) => { window.snapCalls++; return snap(...args) }
    })
    return harness
}

for (const scenario of [{ pageTurnStyle: 'vertical' }, { pageTurnStyle: 'slide' },
    { pageTurnStyle: 'scroll' }, { pageTurnStyle: 'slide', fixedLayout: true }]) {
    test(`Android native long-press bridge starts selection in ${JSON.stringify(scenario)}`, async t => {
        const { page } = await openVerticalBook(t, { runtime: true, androidTouch: true, ...scenario })
        const result = await page.evaluate(async () => {
            const view = window.testView
            const doc = view.renderer.getContents()[0].doc
            const node = doc.getElementById('p0').firstChild
            const offset = node.data.indexOf('power') + 2
            const range = doc.createRange()
            range.setStart(node, offset); range.setEnd(node, offset + 1)
            const rect = range.getBoundingClientRect()
            const frame = doc.defaultView.frameElement, bounds = frame.getBoundingClientRect()
            window.dispatchEvent(new CustomEvent('readflex-long-press', { detail: {
                x: (bounds.left + (rect.left + rect.width / 2) * bounds.width / frame.clientWidth) / innerWidth,
                y: (bounds.top + (rect.top + rect.height / 2) * bounds.height / frame.clientHeight) / innerHeight,
            } }))
            await new Promise(resolve => setTimeout(resolve, 250))
            return { text: doc.getSelection().toString(), payload: window.getCurrentTextSelection()?.text,
                fixedLayout: view.isFixedLayout }
        })
        assert.equal(result.text, 'power')
        assert.equal(result.payload, 'power')
        assert.equal(result.fixedLayout, scenario.fixedLayout ?? false)
        assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 2)
    })
}

for (const platform of ['ios', 'android']) for (const pageTurnStyle of ['vertical', 'slide', 'scroll']) {
    test(`${platform} ${pageTurnStyle} initial book selection keeps its range and handle ownership`, async t => {
        const { page } = await openVerticalBook(t, {
            runtime: true, appleTouch: platform === 'ios', androidTouch: platform === 'android', pageTurnStyle,
        })
        for (const backwards of [false, true]) {
            await page.evaluate(backwards => {
                const doc = window.testView.renderer.getContents()[0].doc
                const node = doc.getElementById('p0').firstChild
                window.bridgeCalls.length = 0
                doc.getSelection().setBaseAndExtent(node, backwards ? 26 : 13, node, backwards ? 13 : 26)
            }, backwards)
            if (platform === 'android') await page.evaluate(() => window.sendTouch('touchcancel'))
            await page.waitForTimeout(250)
            assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(),
                platform === 'android' ? 2 : 0)
            const state = await page.evaluate(() => {
                const selection = window.testView.renderer.getContents()[0].doc.getSelection()
                return { text: selection.toString(), anchor: selection.anchorOffset, focus: selection.focusOffset,
                    payload: window.getCurrentTextSelection()?.text,
                    clears: window.bridgeCalls.filter(([name]) => name === 'onSelectionCleared').length }
            })
            assert.deepEqual(state, { text: 'The power ban', payload: 'The power ban',
                anchor: backwards ? 26 : 13, focus: backwards ? 13 : 26, clears: 0 })
            if (platform === 'android') {
                await page.evaluate(() => window.dispatchEvent(new Event('blur')))
                assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 0)
                await page.evaluate(() => window.dispatchEvent(new Event('focus')))
                await page.waitForTimeout(200)
                assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 2)
                assert.equal(await page.evaluate(() => window.getCurrentTextSelection()?.text), state.text)
            }
            await page.evaluate(() => window.reader.clearSelectionAfterTextAction())
            await page.waitForTimeout(200)
            assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 0)
        }
        assert.ok(await page.locator('[data-readflex-selection-handles]').count() <= 1, 'reuse the controls')
    })
}

for (const platform of ['ios', 'android']) {
    for (const pageTurnStyle of ['vertical', 'slide']) {
        test(`${platform} ${pageTurnStyle} selection can absorb and cross saved highlights`, async t => {
            const { page } = await openVerticalBook(t, {
                runtime: true, appleTouch: platform === 'ios',
                androidTouch: platform === 'android', pageTurnStyle,
            })
            await page.evaluate(async () => {
                const view = window.testView
                const { doc, index } = view.renderer.getContents()[0]
                doc.getElementById('p0').innerHTML =
                    'Paragraph 0. The <em>power</em> <strong>bank</strong> keeps devices running.'
                window.rangeForHighlightTest = (text, id = 'p0') => {
                    const root = doc.getElementById(id)
                    const walker = doc.createTreeWalker(root, NodeFilter.SHOW_TEXT)
                    const nodes = []
                    let fullText = ''
                    let node
                    while ((node = walker.nextNode())) {
                        nodes.push({ node, start: fullText.length })
                        fullText += node.data
                    }
                    const start = fullText.indexOf(text)
                    const end = start + text.length
                    if (start < 0) throw new Error(`Missing fixture text: ${text}`)
                    const first = nodes.find(entry => start >= entry.start && start < entry.start + entry.node.length)
                    const last = nodes.find(entry => end > entry.start && end <= entry.start + entry.node.length)
                    const range = doc.createRange()
                    range.setStart(first.node, start - first.start)
                    range.setEnd(last.node, end - last.start)
                    return range
                }
                for (const [id, text, paragraph] of [
                    ['saved-phrase', 'power bank', 'p0'],
                    ['saved-word', 'devices', 'p0'],
                    ['other-paragraph', 'power bank', 'p1'],
                ]) {
                    window.reader.addAnnotation({
                        id, type: 'highlight', color: '#FFE600',
                        value: view.getCFI(index, window.rangeForHighlightTest(text, paragraph)),
                    })
                }
                await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
                const overlayer = view.renderer.getContents()[0].overlayer
                const hitTest = overlayer.hitTest.bind(overlayer)
                window.highlightHitTests = 0
                overlayer.hitTest = (...args) => {
                    window.highlightHitTests++
                    return hitTest(...args)
                }
            })
            for (const scenario of [
                { text: 'The power bank keeps', ids: ['saved-phrase'] },
                { text: 'power', ids: [] },
                { text: 'power bank', ids: ['saved-phrase'] },
                { text: 'The power', ids: [] },
                { text: 'bank keeps', ids: [] },
                { text: 'power bank keeps', ids: ['saved-phrase'] },
                { text: 'The power bank', ids: ['saved-phrase'] },
                { text: 'power bank keeps devices running', ids: ['saved-phrase', 'saved-word'] },
                { text: 'Paragraph 0.', ids: [] },
                { text: 'power bank', paragraph: 'p1', ids: ['other-paragraph'] },
            ]) {
                const result = await page.evaluate(async ({ text, paragraph, platform }) => {
                    const view = window.testView
                    const { doc } = view.renderer.getContents()[0]
                    window.reader.clearTextSelection()
                    window.bridgeCalls.length = 0
                    const range = window.rangeForHighlightTest(text, paragraph)
                    doc.getSelection().addRange(range)
                    doc.dispatchEvent(new Event('selectionchange'))
                    if (platform === 'android') doc.dispatchEvent(new Event('contextmenu'))
                    await new Promise(resolve => setTimeout(resolve, 200))
                    const payload = window.bridgeCalls.filter(([name]) => name === 'onSelectionEnd').at(-1)?.[1]
                    const live = window.getCurrentTextSelection()
                    return {
                        native: doc.getSelection().toString(),
                        text: payload?.text ?? null,
                        ids: payload?.containedHighlightIds ?? null,
                        liveText: live?.text ?? null,
                        restored: payload ? view.resolveCFI(payload.cfi).anchor(doc).toString() : null,
                        editMenus: window.bridgeCalls.filter(([name]) => name === 'onAnnotationClick').length,
                        saved: window.reader.annotationsById.size,
                    }
                }, { ...scenario, platform })
                assert.deepEqual(result, {
                    native: scenario.text, text: scenario.text, ids: scenario.ids,
                    liveText: scenario.text, restored: scenario.text, editMenus: 0, saved: 3,
                }, JSON.stringify(scenario))
            }

            // Move both boundaries without cancelling the native selection.
            for (const backwards of [false, true]) {
                for (const [text, ids] of [
                    ['bank', []],
                    ['power bank', ['saved-phrase']],
                    ['The power bank keeps devices', ['saved-phrase', 'saved-word']],
                    ['bank keeps devices', ['saved-word']],
                ]) {
                    const result = await page.evaluate(({ text, backwards, platform }) => {
                        const { doc } = window.testView.renderer.getContents()[0]
                        const range = window.rangeForHighlightTest(text)
                        const selection = doc.getSelection()
                        window.bridgeCalls.length = 0
                        const start = [range.startContainer, range.startOffset]
                        const end = [range.endContainer, range.endOffset]
                        selection.setBaseAndExtent(...(backwards ? end : start), ...(backwards ? start : end))
                        doc.dispatchEvent(new Event('selectionchange'))
                        if (platform === 'android') doc.dispatchEvent(new Event('contextmenu'))
                        const payload = window.getCurrentTextSelection()
                        return {
                            native: selection.toString(), text: payload.text,
                            ids: payload.containedHighlightIds,
                            edits: window.bridgeCalls.filter(([name]) => name === 'onAnnotationClick').length,
                        }
                    }, { text, backwards, platform })
                    assert.deepEqual(result, { native: text, text, ids, edits: 0 })
                }
            }

            assert.equal(await page.evaluate(() => window.highlightHitTests), 0,
                'selection changes must not probe saved-highlight paint geometry')

            // Finishing/cancelling a text action is not a highlight deletion.
            const tap = await page.evaluate(() => {
                const { doc } = window.testView.renderer.getContents()[0]
                window.reader.clearSelectionAfterTextAction()
                window.bridgeCalls.length = 0
                const range = window.rangeForHighlightTest('power')
                const rect = range.getBoundingClientRect()
                range.startContainer.parentElement.dispatchEvent(new MouseEvent('click', {
                    bubbles: true, clientX: rect.x + rect.width / 2, clientY: rect.y + rect.height / 2,
                }))
                return {
                    id: window.bridgeCalls.find(([name]) => name === 'onAnnotationClick')?.[1]?.annotation.id,
                    saved: window.reader.annotationsById.size,
                }
            })
            assert.deepEqual(tap, { id: 'saved-phrase', saved: 3 })
        })
    }
}

for (const scenario of [
    {
        name: 'last repeated word without a clipped preceding sentence',
        html: 'Ludwig Boltzmann, who spent most of his life studying statistical mechanics, died in 1906, by his own hand. Paul Ehrenfest, carrying on the work, died similarly in 1933. Now it is our turn to study statistical mechanics.',
        selected: 'mechanics',
        expected: 'Now it is our turn to study statistical mechanics.',
        marked: 'Now it is our turn to study statistical [[mechanics]].',
    },
    {
        name: 'word inside an inline element',
        html: 'An earlier sentence. The <em>power</em> bank keeps devices running. A later sentence.',
        selected: 'power',
        expected: 'The power bank keeps devices running.',
        marked: 'The [[power]] bank keeps devices running.',
    },
    {
        name: 'expression across inline nodes without duplicate context',
        html: 'An earlier sentence. The <em>power</em> <strong>bank</strong> keeps devices running. A later sentence.',
        selected: 'power bank',
        expected: 'The power bank keeps devices running.',
        marked: 'The [[power bank]] keeps devices running.',
    },
    {
        name: 'full sentence beyond the old character window',
        html: `Previous. This ${'very '.repeat(70)}compact power bank keeps devices running. Next.`,
        selected: 'power',
        expected: `This ${'very '.repeat(70)}compact power bank keeps devices running.`,
        marked: `This ${'very '.repeat(70)}compact [[power]] bank keeps devices running.`,
    },
]) {
    test(`book action context contains the ${scenario.name}`, async t => {
        const { page } = await openVerticalBook(t, { runtime: true, appleTouch: true })
        const result = await page.evaluate(({ html, selected }) => {
            const view = window.testView
            const doc = view.renderer.getContents()[0].doc
            const paragraph = doc.getElementById('p0')
            paragraph.innerHTML = html
            const walker = doc.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT)
            const nodes = []
            let fullText = ''
            let node
            while ((node = walker.nextNode())) {
                nodes.push({ node, offset: fullText.length })
                fullText += node.data
            }
            const start = fullText.lastIndexOf(selected)
            const end = start + selected.length
            const first = nodes.find(({ node, offset }) => start >= offset && start < offset + node.length)
            const last = nodes.find(({ node, offset }) => end > offset && end <= offset + node.length)
            const range = doc.createRange()
            range.setStart(first.node, start - first.offset)
            range.setEnd(last.node, end - last.offset)
            const selection = doc.getSelection()
            selection.removeAllRanges()
            selection.addRange(range)
            doc.dispatchEvent(new Event('selectionchange'))
            const payload = window.getCurrentTextSelection()
            return {
                text: payload.text,
                context: payload.contextText,
                marked: payload.markedContextText,
                normalizedMarked: payload.normalizedMarkedContextText,
                restored: view.resolveCFI(payload.cfi).anchor(doc).toString(),
            }
        }, scenario)
        assert.deepEqual(result, {
            text: scenario.selected,
            context: scenario.expected,
            marked: scenario.marked,
            normalizedMarked: scenario.marked,
            restored: scenario.selected,
        })
    })
}

for (const clearMethod of ['clearSelectionAfterTextAction', 'clearTextSelection']) {
    test(`horizontal boundary selection cancels its page turn on ${clearMethod}`, async t => {
        const { page } = await openVerticalBook(t, { runtime: true, pageTurnStyle: 'slide' })
        const before = await page.evaluate(() => {
            const view = window.testView
            const doc = view.renderer.getContents()[0].doc
            doc.dispatchEvent(new Event('selectstart'))
            doc.getSelection().addRange(view.lastLocation.range.cloneRange())
            doc.dispatchEvent(new Event('selectionchange'))
            return { page: view.renderer.page, scheduled: !!globalThis.pageDebounceTimer }
        })
        assert.equal(before.scheduled, false, 'boundary selection never schedules an automatic page turn')
        await page.evaluate(method => window.reader[method](), clearMethod)
        await page.waitForTimeout(1500)
        assert.equal(await page.evaluate(() => window.testView.renderer.page), before.page)
        assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
            .doc.getSelection().toString()), '')
    })
}

test('active horizontal selection requires a separate gesture to advance', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, pageTurnStyle: 'slide' })
    const before = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        doc.dispatchEvent(new Event('selectstart'))
        doc.getSelection().addRange(view.lastLocation.range.cloneRange())
        doc.dispatchEvent(new Event('selectionchange'))
        return view.renderer.page
    })
    await page.waitForTimeout(1200)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), before)
})

test('changing to vertical pagination cancels a pending horizontal selection turn', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, pageTurnStyle: 'slide' })
    const before = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        doc.getSelection().addRange(view.lastLocation.range.cloneRange())
        doc.dispatchEvent(new Event('selectionchange'))
        view.renderer.setAttribute('page-turn-axis', 'vertical')
        return view.renderer.page
    })
    await page.waitForTimeout(1500)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), before)
})

test('horizontal range changes do not install additional scroll listeners', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, pageTurnStyle: 'slide' })
    const result = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        const container = view.renderer.shadowRoot.querySelector('#container')
        const guards = new Set()
        const add = container.addEventListener.bind(container)
        const remove = container.removeEventListener.bind(container)
        container.addEventListener = (name, callback, ...args) => {
            if (name === 'scroll') guards.add(callback)
            return add(name, callback, ...args)
        }
        container.removeEventListener = (name, callback, ...args) => {
            if (name === 'scroll') guards.delete(callback)
            return remove(name, callback, ...args)
        }
        let peak = 0
        const range = view.lastLocation.range.cloneRange()
        range.setEnd(range.endContainer, range.endOffset - 1)
        for (let i = 0; i < 100; i++) {
            doc.getSelection().removeAllRanges()
            doc.getSelection().addRange(range.cloneRange())
            doc.dispatchEvent(new Event('selectionchange'))
            peak = Math.max(peak, guards.size)
        }
        doc.getSelection().removeAllRanges()
        doc.dispatchEvent(new Event('selectionchange'))
        return { peak, remaining: guards.size }
    })
    assert.deepEqual(result, { peak: 0, remaining: 0 })
})

async function selectionPageGesture(page, direction, style, { tap = false, cancel = false } = {}) {
    await page.evaluate(({ direction, style, tap, cancel }) => {
        const doc = window.testView.renderer.getContents()[0].doc
        const frame = doc.defaultView.frameElement
        const rect = frame.getBoundingClientRect()
        const send = (type, x, y) => {
            if (!tap) return window.sendTouch(type,
                (x - rect.left) * frame.clientWidth / rect.width,
                (y - rect.top) * frame.clientHeight / rect.height)
            const host = window.testView.renderer
            const touch = { identifier: 2, target: host, screenX: x, screenY: y, clientX: x, clientY: y }
            const event = new Event(type, { bubbles: true, cancelable: true })
            Object.defineProperties(event, {
                touches: { value: type === 'touchend' || type === 'touchcancel' ? [] : [touch] },
                changedTouches: { value: [touch] },
            })
            host.dispatchEvent(event)
            return event.defaultPrevented
        }
        const x = tap && style === 'slide' ? (direction < 0 ? 12 : innerWidth - 12) : innerWidth / 2
        const y = tap && style === 'vertical' ? (direction < 0 ? 12 : innerHeight - 12) : innerHeight / 2
        send('touchstart', x, y)
        if (!tap) send('touchmove', x - (style === 'slide' ? direction * 120 : 0),
            y - (style === 'vertical' ? direction * 120 : 0))
        send(cancel ? 'touchcancel' : 'touchend', x, y)
    }, { direction, style, tap, cancel })
    await page.waitForTimeout(250)
}

test('a second finger cancels selected edge navigation even without a move event', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, androidTouch: true })
    await page.evaluate(() => window.selectWords())
    await page.waitForTimeout(200)
    const before = await page.evaluate(() => {
        const host = window.testView.renderer
        const touch = id => ({ identifier: id, target: host, clientX: innerWidth / 2, clientY: innerHeight - 12 })
        const dispatch = (type, touches) => {
            const event = new Event(type, { bubbles: true, cancelable: true })
            Object.defineProperties(event, { touches: { value: touches }, changedTouches: { value: [touch(2)] } })
            host.dispatchEvent(event)
        }
        dispatch('touchstart', [touch(1)])
        dispatch('touchstart', [touch(1), touch(2)])
        dispatch('touchend', [touch(1)])
        dispatch('touchend', [])
        return host.page
    })
    await page.waitForTimeout(300)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), before)
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0].doc.__readflexSelectionNavigation.isAdjusting), false)
    await selectionPageGesture(page, 1, 'vertical', { tap: true })
    assert.equal(await page.evaluate(() => window.testView.renderer.page), before + 1)
})

for (const platform of ['ios', 'android']) for (const pageTurnStyle of ['slide', 'vertical']) {
    for (const direction of [-1, 1]) {
        test(`${platform} ${pageTurnStyle} ${direction} continuation retains the fixed boundary when reversing and crossing`, async t => {
            const { page } = await openVerticalBook(t, { runtime: true, appleTouch: platform === 'ios', androidTouch: platform === 'android', pageTurnStyle })
            await page.waitForTimeout(150)
            const before = await page.evaluate(async direction => {
                const view = window.testView
                await view.renderer.goTo({ index: 0, anchor: 0.4 })
                const doc = view.renderer.getContents()[0].doc
                const visible = view.lastLocation.range
                const node = visible.startContainer.nodeType === 3 ? visible.startContainer : visible.startContainer.firstChild
                const offset = visible.startContainer === node ? visible.startOffset : 0
                const selection = doc.getSelection()
                selection.setBaseAndExtent(node, offset + 2, node, offset + 7)
                doc.dispatchEvent(new Event('selectionchange'))
                window.fixedTestPoint = { node, offset: offset + (direction < 0 ? 7 : 2) }
                const range = selection.getRangeAt(0).cloneRange()
                if (direction < 0) range.setStart(visible.startContainer, visible.startOffset)
                else range.setEnd(visible.endContainer, visible.endOffset)
                // Preserve the forward Selection order when dragging the left
                // handle, as real iOS does. Do not manufacture a backward one.
                selection.setBaseAndExtent(range.startContainer, range.startOffset, range.endContainer, range.endOffset)
                doc.dispatchEvent(new Event('selectionchange'))
                return view.renderer.page
            }, direction)
            assert.ok(before > 1)
            await page.waitForTimeout(1100)
            assert.equal(await page.evaluate(() => window.testView.renderer.page), before)
            await selectionPageGesture(page, direction, pageTurnStyle, { cancel: true })
            assert.equal(await page.evaluate(() => window.testView.renderer.page), before)
            let expectedPage = before
            for (const [step, tap] of [[direction, false], [direction, true], [-direction, false], [-direction, true], [-direction, false]]) {
                await selectionPageGesture(page, step, pageTurnStyle, { tap })
                expectedPage += step
                const result = await page.evaluate(() => {
                    const view = window.testView
                    const doc = view.renderer.getContents()[0].doc
                    const selection = doc.getSelection()
                    const payload = window.getCurrentTextSelection()
                    const fixed = window.fixedTestPoint
                    return { page: view.renderer.page, fixed: selection.anchorNode === fixed.node && selection.anchorOffset === fixed.offset,
                        text: payload?.text, raw: selection.rangeCount ? selection.getRangeAt(0).toString() : null,
                        restored: payload ? view.resolveCFI(payload.cfi).anchor(doc).toString() : null,
                        anchor: [selection.anchorNode.parentElement.id, selection.anchorOffset],
                        expectedAnchor: [fixed.node.parentElement.id, fixed.offset],
                        pos: payload?.pos, adjusting: doc.__readflexSelectionNavigation.isAdjusting }
                })
                assert.equal(result.page, expectedPage, JSON.stringify({ step, tap, result }))
                assert.equal(result.fixed, true, JSON.stringify({ step, tap, result }))
                assert.equal(result.adjusting, false)
                assert.equal(result.restored, result.raw)
                assert.ok(result.text.length > 0)
                assert.ok(result.pos.bottom > result.pos.top && result.pos.top >= 0 && result.pos.bottom <= 1)
            }
            await page.waitForTimeout(1100)
            assert.equal(await page.evaluate(() => window.testView.renderer.page), expectedPage, 'no delayed extra turn')
            assert.equal(await page.evaluate(() => !!document.querySelector('[data-readflex-selection-handles]')), platform === 'android')
        })
    }
}

for (const pageTurnStyle of ['slide', 'vertical']) {
    test(`${pageTurnStyle} selection stays within the chapter and rejects native scroll drift`, async t => {
        const { page } = await openVerticalBook(t, { runtime: true, androidTouch: true, pageTurnStyle })
        await page.waitForTimeout(150)
        for (const direction of [-1, 1]) {
            const before = await page.evaluate(async direction => {
                const view = window.testView
                window.reader.clearTextSelection()
                await view.renderer.goTo({ index: 0, anchor: direction < 0 ? 0 : 1 })
                const doc = view.renderer.getContents()[0].doc
                const range = view.lastLocation.range.cloneRange()
                doc.getSelection().addRange(range)
                doc.dispatchEvent(new Event('selectionchange'))
                const container = view.renderer.shadowRoot.querySelector('#container')
                const offset = container[view.renderer.scrollProp]
                // Native handle auto-scroll is outside the reader's page API.
                container[view.renderer.scrollProp] += direction < 0 ? 80 : -80
                return { page: view.renderer.page, offset, text: range.toString(),
                    cfi: view.getCFI(0, range) }
            }, direction)
            await page.waitForTimeout(250)
            assert.equal(await page.evaluate(() => {
                const renderer = window.testView.renderer
                return renderer.shadowRoot.querySelector('#container')[renderer.scrollProp]
            }), before.offset, 'native scroll cannot leave a partially visible page')
            await selectionPageGesture(page, direction, pageTurnStyle, { tap: true })
            const after = await page.evaluate(() => {
                const view = window.testView
                const doc = view.renderer.getContents()[0].doc
                const range = doc.getSelection().getRangeAt(0)
                return { page: view.renderer.page, text: range.toString(),
                    cfi: view.getCFI(0, range), adjusting: doc.__readflexSelectionNavigation.isAdjusting }
            })
            assert.deepEqual(after, { page: before.page, text: before.text, cfi: before.cfi, adjusting: false })
        }
    })
}

test('vertical book selection at the page boundary does not schedule a page turn', async t => {
    const { page } = await openVerticalBook(t, { runtime: true })
    const original = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        doc.dispatchEvent(new Event('selectstart'))
        const range = view.lastLocation.range.cloneRange()
        doc.getSelection().addRange(range)
        doc.dispatchEvent(new Event('selectionchange'))
        return { page: view.renderer.page, text: doc.getSelection().toString() }
    })
    assert.ok(original.text.length > 0)
    // Exceed the old one-second auto-page timer, including its animation.
    await page.waitForTimeout(1500)
    assert.deepEqual(await page.evaluate(() => ({
        page: window.testView.renderer.page,
        text: window.testView.renderer.getContents()[0].doc.getSelection().toString(),
    })), original)
})

for (const platform of ['iOS', 'Android']) {
test(`${platform} keeps the native range without a second preview, and saved highlights still render`, async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: platform === 'iOS', androidTouch: platform === 'Android' })
    const original = await page.evaluate(() => {
        window.selectWords()
        const reader = window.reader
        const { doc, index } = reader.view.renderer.getContents()[0]
        const range = doc.getSelection().getRangeAt(0)
        const cfi = reader.view.getCFI(index, range)
        window.selectionTestCfi = cfi
        reader.showSelectionHighlightPreview({ cfi, color: '#ffff00' })
        return range.toString()
    })
    assert.equal(await page.evaluate(() => window.reader.annotationsById
        .has('__readflex-selection-preview-highlight')), false)
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
        .doc.getSelection().toString()), original)
    await page.evaluate(() => {
        window.reader.clearSelectionAfterTextAction()
        window.reader.addAnnotation({
            id: 'saved', type: 'highlight', value: window.selectionTestCfi,
            color: '#00ff00',
        })
    })
    await page.waitForFunction(() => window.testView.renderer.getContents()[0]
        .overlayer.element.querySelector('rect'))
    assert.equal(await page.evaluate(() => window.reader.annotationsById.get('saved').color), '#00ff00')
})

test(`${platform} removes a fallback preview when the native selection reappears`, async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: platform === 'iOS', androidTouch: platform === 'Android' })
    await page.evaluate(() => {
        const reader = window.reader
        const { doc, index } = reader.view.renderer.getContents()[0]
        const range = doc.createRange()
        range.setStart(doc.getElementById('p0').firstChild, 0)
        range.setEnd(doc.getElementById('p0').firstChild, 12)
        reader.showSelectionHighlightPreview({ cfi: reader.view.getCFI(index, range), color: '#ffff00' })
    })
    await page.waitForFunction(() => window.testView.renderer.getContents()[0]
        .overlayer.element.querySelector('rect'))
    await page.evaluate(() => window.selectWords())
    assert.equal(await page.evaluate(() => window.reader.annotationsById
        .has('__readflex-selection-preview-highlight')), false)
    await page.waitForFunction(() => !window.testView.renderer.getContents()[0]
        .overlayer.element.querySelector('rect'))
})
}

test('dragging an existing selection belongs to the iframe, not the page swipe handler', async t => {
    const { page } = await openVerticalBook(t)
    const result = await page.evaluate(() => {
        window.selectWords()
        window.sendTouch('touchstart')
        const prevented = window.sendTouch('touchmove', 190, 100)
        const doc = window.testView.renderer.getContents()[0].doc
        const transform = doc.defaultView.frameElement.parentElement.style.transform
        window.sendTouch('touchend', 190, 100)
        return { prevented, transform, page: window.testView.renderer.page }
    })
    await page.waitForTimeout(600)
    assert.equal(result.prevented, false, 'native selection must retain the gesture')
    assert.equal(result.transform, '')
    assert.equal(await page.evaluate(() => window.testView.renderer.page), result.page)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('a long press that starts selection cannot snap on release, even if the range collapses', async t => {
    const { page } = await openVerticalBook(t)
    await page.evaluate(() => {
        window.sendTouch('touchstart')
        window.selectWords()
        const doc = window.testView.renderer.getContents()[0].doc
        doc.getSelection().removeAllRanges()
        doc.dispatchEvent(new Event('selectionchange'))
        window.sendTouch('touchend')
    })
    await page.waitForTimeout(600)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('selection created after touchend cancels the pending snap frame', async t => {
    const { page } = await openVerticalBook(t)
    await page.evaluate(() => {
        window.sendTouch('touchstart')
        window.sendTouch('touchend')
        window.selectWords()
    })
    await page.waitForTimeout(600)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('a selection appearing during a vertical release animation stops that page turn', async t => {
    const { page } = await openVerticalBook(t)
    const originalPage = await page.evaluate(() => {
        const page = window.testView.renderer.page
        window.sendTouch('touchstart')
        window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchend', 190, 100)
        window.selectWords()
        return page
    })
    await page.waitForTimeout(600)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), originalPage)
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
        .doc.defaultView.frameElement.parentElement.style.transform), '')
})

test('cancelled vertical swipes leave no preview and a fresh swipe still turns one page', async t => {
    const { page } = await openVerticalBook(t)
    await page.evaluate(() => {
        window.sendTouch('touchstart')
        window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchcancel', 190, 100)
    })
    assert.equal(await page.evaluate(() => window.testView.renderer.getContents()[0]
        .doc.defaultView.frameElement.parentElement.style.transform), '')
    const originalPage = await page.evaluate(() => {
        window.selectWords()
        const doc = window.testView.renderer.getContents()[0].doc
        doc.getSelection().removeAllRanges()
        doc.dispatchEvent(new Event('selectionchange'))
        const originalPage = window.testView.renderer.page
        window.sendTouch('touchstart')
        window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchend', 190, 100)
        return originalPage
    })
    await page.waitForFunction(original => window.testView.renderer.page === original + 1, originalPage)
    await page.waitForTimeout(300)
    await page.evaluate(() => {
        window.sendTouch('touchstart', 190, 100)
        window.sendTouch('touchmove', 190, 500)
        window.sendTouch('touchend', 190, 500)
    })
    await page.waitForFunction(original => window.testView.renderer.page === original, originalPage)
})

test('backward multi-page selection keeps its complete text and CFI for reader actions', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: true })
    const result = await page.evaluate(() => {
        const view = window.testView
        const doc = view.renderer.getContents()[0].doc
        const start = doc.getElementById('p0').firstChild
        const end = doc.getElementById('p12').firstChild
        const selection = doc.getSelection()
        selection.setBaseAndExtent(end, end.length, start, 0)
        doc.dispatchEvent(new Event('selectionchange'))
        const payload = window.getCurrentTextSelection()
        return {
            expected: selection.toString(), actual: payload.text, raw: selection.getRangeAt(0).toString(),
            restored: view.resolveCFI(payload.cfi).anchor(doc).toString(),
            backward: selection.focusNode === start, page: view.renderer.page,
        }
    })
    assert.ok(result.expected.includes('Paragraph 12.'))
    assert.equal(result.backward, true)
    assert.equal(result.actual, result.expected)
    assert.equal(result.restored, result.raw)
    assert.match(result.actual, /\n/, 'rendered paragraph breaks reach actions')
    await page.waitForTimeout(1500)
    assert.equal(await page.evaluate(() => window.testView.renderer.page), result.page)
})

test('Android keeps the same controls from initial selection through continuation, keys, and clear', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, androidTouch: true })
    await page.waitForTimeout(150)
    await page.evaluate(() => window.selectWords())
    await page.waitForTimeout(200)
    assert.equal(await page.locator('[data-readflex-selection-handles] button:visible').count(), 2)
    const initialHost = await page.locator('[data-readflex-selection-handles]').elementHandle()
    await selectionPageGesture(page, 1, 'vertical')
    assert.equal(await initialHost.evaluate(node => node === document.querySelector('[data-readflex-selection-handles]')), true)
    const end = page.locator('[data-readflex-selection-handles] button[data-endpoint="end"]')
    const box = await end.boundingBox()
    assert.ok(box && box.width >= 48 && box.height >= 48)
    assert.equal(await end.getAttribute('aria-label'), 'Selection end')
    const before = await page.evaluate(() => ({ page: testView.renderer.page, text: reader.view.renderer.getContents()[0].doc.getSelection().toString() }))
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
    await page.mouse.down()
    await page.mouse.move(280, 320, { steps: 12 })
    await page.mouse.up()
    await page.waitForTimeout(200)
    const extended = await page.evaluate(() => ({ page: testView.renderer.page, text: reader.view.renderer.getContents()[0].doc.getSelection().toString() }))
    assert.equal(extended.page, before.page)
    assert.ok(extended.text.length > before.text.length)
    await end.focus()
    await page.keyboard.press('ArrowRight')
    await page.waitForTimeout(200)
    assert.ok(await page.evaluate(length => reader.view.renderer.getContents()[0].doc.getSelection().toString().length > length, extended.text.length))
    await page.keyboard.press('Escape')
    await page.waitForTimeout(200)
    assert.equal(await end.isVisible(), false)
    assert.equal(await page.evaluate(() => reader.view.renderer.getContents()[0].doc.getSelection().toString()), '')
})

test('selection updates defer text serialization and keep geometry bounded', async t => {
    const { page } = await openVerticalBook(t, { runtime: true, appleTouch: true })
    const immediate = await page.evaluate(() => {
        const doc = testView.renderer.getContents()[0].doc
        const selection = doc.getSelection()
        const native = selection.toString.bind(selection)
        window.selectionSerializations = 0
        selection.toString = () => { window.selectionSerializations++; return native() }
        const first = doc.getElementById('p0').firstChild
        const last = doc.getElementById('p59').firstChild
        for (let offset = 1; offset < 40; offset++) {
            selection.setBaseAndExtent(first, 0, last, offset)
            doc.dispatchEvent(new Event('selectionchange'))
        }
        return window.selectionSerializations
    })
    assert.equal(immediate, 0, 'handle moves must not serialize chapter-sized selections')
    await page.waitForTimeout(250)
    assert.ok(await page.evaluate(() => window.selectionSerializations) <= 2)
    const result = await page.evaluate(async () => {
        const doc = testView.renderer.getContents()[0].doc
        const expected = doc.getSelection().toString()
        const payload = window.getCurrentTextSelection()
        const { selectionViewportPosition } = await import('./src/readflex_selection_navigation.js')
        const prototype = doc.defaultView.Range.prototype
        const bounding = prototype.getBoundingClientRect, all = prototype.getClientRects
        let rectangles = 0, lineScans = 0
        prototype.getBoundingClientRect = function () { rectangles++; return bounding.call(this) }
        prototype.getClientRects = function () { lineScans++; return all.call(this) }
        try { selectionViewportPosition(doc.getSelection().getRangeAt(0)) }
        finally { prototype.getBoundingClientRect = bounding; prototype.getClientRects = all }
        doc.getSelection().removeAllRanges()
        const remembered = window.getCurrentTextSelection()
        return { expected, text: payload.text, remembered: remembered.text, rectangles, lineScans }
    })
    assert.equal(result.text, result.expected)
    assert.equal(result.remembered, result.expected, 'focus loss preserves paragraph separators')
    assert.ok(result.rectangles <= 4, 'at most two endpoints, including collapsed-caret fallbacks')
    assert.equal(result.lineScans, 0, 'menu positioning never scans selected lines')
})

test('book continuous scroll keeps native movement and skips page snapping', async t => {
    const { page } = await openVerticalBook(t)
    const prevented = await page.evaluate(() => {
        window.testView.renderer.setAttribute('flow', 'scrolled')
        window.sendTouch('touchstart')
        const prevented = window.sendTouch('touchmove', 190, 100)
        window.sendTouch('touchend', 190, 100)
        return prevented
    })
    await page.waitForTimeout(600)
    assert.equal(prevented, false)
    assert.equal(await page.evaluate(() => window.snapCalls), 0)
})

test('selection cancels a horizontal reader pull gesture without leaving content shifted', async t => {
    const { page } = await openVerticalBook(t, { runtime: true })
    await page.evaluate(() => {
        window.changeStyle({ pageTurnStyle: 'slide' })
        window.sendTouch('touchstart', 190, 100)
        window.sendTouch('touchmove', 190, 300)
    })
    assert.notEqual(await page.evaluate(() => window.testView.renderer.style.transform), '')
    await page.evaluate(() => {
        window.selectWords()
        window.sendTouch('touchend', 190, 300)
    })
    assert.equal(await page.evaluate(() => window.testView.renderer.style.transform), '')
})
