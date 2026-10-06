import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'
import { READFLEX_SELECTION_CLICK_SUPPRESS_MS } from '../assets/foliate-js/src/readflex_shell_constants.js'

const content = `
<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">Read the
<a id="external" href="https://example.com/article?x=1#part">external page</a>, the
<a id="fragment" href="#later"><em id="nested">later section</em></a>, a
<a id="loopback" href="other.html">sibling file</a> and a
<a id="absolute-fragment" href="LATER_PLACEHOLDER">resolved fragment</a>.</span></p>
${Array.from({ length: 80 }, (_, i) => `<p id="filler-${i}" data-rf-block-id="filler-${i}"><span id="filler-${i}-s0" data-rf-sentence="0">Filler paragraph ${i} keeps the heading far below the first viewport.</span></p>`).join('\n')}
<h2 id="later">Later heading</h2>
<p id="block-1" data-rf-block-id="block-1"><span id="block-1-s0" data-rf-sentence="0">Later text.</span></p>
${Array.from({ length: 40 }, (_, i) => `<p id="tail-${i}" data-rf-block-id="tail-${i}"><span id="tail-${i}-s0" data-rf-sentence="0">Trailing paragraph ${i} lets the heading reach the top of the viewport.</span></p>`).join('\n')}`

async function openArticle(t) {
    const { page, origin, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', content.replace('LATER_PLACEHOLDER', `${origin}/saved/#later`))
    const navigations = []
    page.on('framenavigated', frame => { if (frame === page.mainFrame()) navigations.push(frame.url()) })
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(articleUrl())
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    const initialUrl = page.url()
    await page.evaluate(() => { window.bridgeCalls.length = 0 })
    const calls = () => page.evaluate(() => window.bridgeCalls
        .filter(([name]) => ['onExternalLink', 'onClick', 'onAnnotationClick'].includes(name))
        .map(([name, data]) => [name, typeof data === 'string' ? data : null]))
    return { page, navigations, initialUrl, calls }
}

test('external article links reach Flutter without navigating the WebView', async t => {
    const { page, navigations, initialUrl, calls } = await openArticle(t)
    await page.locator('#external').click()
    await page.waitForTimeout(100)
    assert.deepEqual(await calls(), [['onExternalLink', 'https://example.com/article?x=1#part']])
    assert.equal(page.url(), initialUrl)
    assert.deepEqual(navigations.slice(1), [], 'the article shell must stay loaded')
})

test('fragment links scroll in place through the shell navigation, not the browser', async t => {
    const { page, initialUrl, calls } = await openArticle(t)
    for (const id of ['nested', 'absolute-fragment']) {
        await page.evaluate(() => scrollTo(0, 0))
        await page.locator(`#${id}`).click()
        await page.waitForTimeout(100)
        assert.ok(await page.evaluate(() => scrollY) > 2000, `${id} must scroll to the heading`)
        assert.equal(page.url(), initialUrl, 'in-page navigation must not change the document URL or hash')
        assert.deepEqual(await calls(), [], `${id} is neither a tap nor an external link`)
        const chapter = await page.evaluate(() => window.bridgeCalls
            .filter(([name]) => name === 'onArticlePositionChanged').at(-1)?.[1]?.chapterTitle)
        assert.equal(chapter, 'Later heading')
        await page.evaluate(() => { window.bridgeCalls.length = 0 })
    }
})

test('loopback links are inert and do not toggle chrome', async t => {
    const { page, initialUrl, calls } = await openArticle(t)
    await page.locator('#loopback').click()
    await page.waitForTimeout(100)
    assert.deepEqual(await calls(), [])
    assert.equal(page.url(), initialUrl)
})

test('links are ignored while text is selected and inside the post-selection window', async t => {
    const { page, initialUrl, calls } = await openArticle(t)
    await page.evaluate(() => {
        const node = document.getElementById('block-1-s0').firstChild
        getSelection().setBaseAndExtent(node, 0, node, 5)
        document.dispatchEvent(new Event('selectionchange'))
    })
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onSelectionEnd'))
    // Past the debounce window, an active range still owns the tap.
    await page.waitForTimeout(READFLEX_SELECTION_CLICK_SUPPRESS_MS + 250)
    await page.locator('#external').dispatchEvent('click')
    await page.waitForTimeout(50)
    assert.deepEqual(await calls(), [], 'an active selection owns the tap')
    assert.equal(page.url(), initialUrl)
    await page.evaluate(() => {
        getSelection().removeAllRanges()
        document.dispatchEvent(new Event('selectionchange'))
    })
    await page.locator('#external').dispatchEvent('click')
    await page.waitForTimeout(50)
    assert.deepEqual(await calls(), [], 'the tap that dismissed the selection is swallowed')
    await page.waitForTimeout(READFLEX_SELECTION_CLICK_SUPPRESS_MS + 50)
    await page.locator('#external').dispatchEvent('click')
    await page.waitForTimeout(50)
    assert.deepEqual(await calls(), [['onExternalLink', 'https://example.com/article?x=1#part']])
    assert.equal(page.url(), initialUrl)
})
