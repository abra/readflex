import test from 'node:test'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { createHarness } from './harness.mjs'
import {
    ACTIVE_SEARCH_HIGHLIGHT_COLOR,
    ACTIVE_SEARCH_HIGHLIGHT_OPACITY,
    SEARCH_HIGHLIGHT_COLOR,
    SEARCH_HIGHLIGHT_OPACITY,
} from '../assets/foliate-js/src/readflex_shell_constants.js'
import { premixHighlightColor } from '../assets/foliate-js/src/readflex_highlight_style.js'

const content = '<p id="block-0" data-rf-block-id="block-0"><span id="block-0-s0" data-rf-sentence="0">One vision, another <em>vision</em>, a third vision and the final vision ♾.</span></p>'

async function openArticle(t, { style = {}, nativeHighlights = true } = {}) {
    const { page, origin, routes, articleUrl } = await createHarness(t)
    routes.set('/article-content', content)
    const fontRequests = []
    await page.route('**/fonts/*.ttf', async route => {
        const name = new URL(route.request().url()).pathname.split('/').at(-1)
        fontRequests.push(name)
        await route.fulfill({
            contentType: 'font/ttf',
            path: fileURLToPath(new URL(`../../component_library/fonts/${name}`, import.meta.url)),
        })
    })
    if (!nativeHighlights) await page.addInitScript(() => { window.Highlight = undefined })
    const params = new URLSearchParams({
        style: JSON.stringify({
            fontName: 'Literata', fontPath: `${origin}/fonts/Literata-Variable.ttf`,
            fontColor: '#292521', backgroundColor: '#faf8f4', ...style,
        }),
    })
    await page.goto(`${articleUrl()}&${params}`)
    await page.waitForFunction(() => window.bridgeCalls.some(([name]) => name === 'onLoadEnd'))
    return { page, origin, fontRequests }
}

const hexToRgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16))
const rgba = (hex, opacity) => `rgba(${hexToRgb(hex).join(', ')}, ${opacity})`

test('article font stack declares the reader face with its weight axis and the symbol fallback', async t => {
    const { page, fontRequests } = await openArticle(t)
    const result = await page.evaluate(async () => {
        await document.fonts.ready
        const faces = [...document.fonts].map(face => ({
            family: face.family.replaceAll('"', ''), weight: face.weight, status: face.status,
        }))
        return { family: getComputedStyle(document.body).fontFamily, faces }
    })
    // WebKit serializes families without quotes; Chromium quotes multi-word names.
    assert.equal(result.family.replaceAll('"', ''), 'Literata, Noto Sans Symbols')
    const literata = result.faces.find(face => face.family === 'Literata')
    assert.ok(literata, JSON.stringify(result.faces))
    assert.equal(literata.weight, '100 900')
    assert.equal(literata.status, 'loaded')
    assert.ok(result.faces.some(face => face.family === 'Noto Sans Symbols'), 'symbol face must be declared')
    assert.ok(fontRequests.includes('Literata-Variable.ttf'))
})

for (const nativeHighlights of [true, false]) {
    const renderer = nativeHighlights ? 'css' : 'svg'
    test(`article search tints every match and keeps the active one amber (${renderer})`, async t => {
        const { page } = await openArticle(t, { nativeHighlights })
        await page.evaluate(() => window.startSearch(7, 'vision'))
        await page.waitForFunction(() => window.bridgeCalls.some(([name, data]) =>
            name === 'onSearch' && data.requestId === 7 && data.type === 'done'))
        const results = await page.evaluate(() => window.bridgeCalls
            .filter(([name, data]) => name === 'onSearch' && data.requestId === 7 && data.type === 'results')
            .flatMap(([, data]) => data.items))
        assert.equal(results.length, 4)
        const countMatches = () => page.evaluate(() => ({
            css: window.CSS?.highlights?.get('readflex-search-matches')?.size ?? 0,
            svg: document.querySelectorAll('[data-rf-highlight-overlay] rect').length,
            text: document.getElementById('article-content').innerText,
        }))
        const before = await countMatches()
        assert.equal(nativeHighlights ? before.css : before.svg, 4, JSON.stringify(before))
        const matchRule = await page.evaluate(() => [...document.styleSheets]
            .flatMap(sheet => [...sheet.cssRules]).map(rule => rule.cssText)
            .find(text => text.includes('::highlight(readflex-search-matches)')))
        assert.ok(matchRule.includes(rgba(SEARCH_HIGHLIGHT_COLOR, SEARCH_HIGHLIGHT_OPACITY)), matchRule)

        const sentenceCfi = await page.evaluate(() => window.bridgeCalls
            .find(([name]) => name === 'onArticlePositionChanged')[1].cfi)
        const activeState = () => page.evaluate(({ nativeHighlights, activeColor }) => {
            if (nativeHighlights) {
                return {
                    active: CSS.highlights.get('readflex-search-active')?.size ?? 0,
                    rule: [...document.styleSheets].flatMap(sheet => [...sheet.cssRules])
                        .map(rule => rule.cssText)
                        .find(text => text.includes('::highlight(readflex-search-active)')),
                }
            }
            const groups = [...document.querySelectorAll('[data-rf-highlight-overlay] g')]
                .filter(g => g.getAttribute('fill') === activeColor)
            return { active: groups.length, rule: null }
        }, { nativeHighlights, activeColor: ACTIVE_SEARCH_HIGHLIGHT_COLOR })
        for (const index of [1, 3, 0]) {
            await page.evaluate(cfi => window.goToSearchResult(cfi), results[index].cfi)
            const active = await activeState()
            assert.equal(active.active, 1)
            if (nativeHighlights) {
                assert.ok(active.rule.includes(rgba(ACTIVE_SEARCH_HIGHLIGHT_COLOR, ACTIVE_SEARCH_HIGHLIGHT_OPACITY)), active.rule)
            }
            const during = await countMatches()
            // The active match is painted alone; the other three keep their tint.
            if (nativeHighlights) assert.equal(during.css, 3)
            else assert.equal(during.svg, 4, JSON.stringify(during))
            assert.equal(during.text, before.text, 'painting the active match keeps the text')
        }
        await page.evaluate(cfi => window.goToCfi(cfi), sentenceCfi)
        const restored = await countMatches()
        assert.equal(nativeHighlights ? restored.css : restored.svg, 4,
            'leaving the active match restores its inactive tint')
        assert.equal((await activeState()).active, 0)
        const svgFill = nativeHighlights ? null : await page.evaluate(() => {
            const g = document.querySelector('[data-rf-highlight-overlay] g')
            return { fill: g.getAttribute('fill'), opacity: g.style.opacity, rx: g.querySelector('rect').getAttribute('rx') }
        })
        if (svgFill) assert.deepEqual(svgFill, { fill: SEARCH_HIGHLIGHT_COLOR, opacity: String(SEARCH_HIGHLIGHT_OPACITY), rx: '3' })

        await page.evaluate(() => window.clearSearch())
        const after = await countMatches()
        assert.deepEqual([after.css, after.svg], [0, 0])
        assert.equal(after.text, 'One vision, another vision, a third vision and the final vision ♾.')
    })
}

test('customCSS overrides the shared search tints in the article shell', async t => {
    const { page } = await openArticle(t, { style: {
        customCSSEnabled: true,
        customCSS: ':root { --rf-search-active-color: #00ff00; --rf-search-active-opacity: 0.5; --rf-search-match-color: #0000ff; }',
    } })
    await page.evaluate(() => window.startSearch(8, 'vision'))
    await page.waitForFunction(() => window.bridgeCalls.some(([name, data]) =>
        name === 'onSearch' && data.requestId === 8 && data.type === 'done'))
    const cfi = await page.evaluate(() => window.bridgeCalls
        .find(([name, data]) => name === 'onSearch' && data.requestId === 8 && data.type === 'results')[1].items[0].cfi)
    const result = await page.evaluate(cfi => {
        window.goToSearchResult(cfi)
        const rules = [...document.styleSheets].flatMap(sheet => [...sheet.cssRules]).map(rule => rule.cssText)
        return {
            activeRule: rules.find(text => text.includes('::highlight(readflex-search-active)')),
            matchRule: rules.find(text => text.includes('::highlight(readflex-search-matches)')),
        }
    }, cfi)
    assert.ok(result.activeRule.includes('rgba(0, 255, 0, 0.5)'), result.activeRule)
    assert.ok(result.matchRule.includes(`rgba(0, 0, 255, ${SEARCH_HIGHLIGHT_OPACITY})`), result.matchRule)
})

test('article CSS highlights are pre-mixed against the page like the book overlay', async t => {
    const { page } = await openArticle(t, { style: { backgroundColor: '#121212', fontColor: '#e8e6e3' } })
    const annotation = { color: '#FFE600', opacity: 0.72, mixBlendMode: 'lighten', verticalOffset: 2 }
    const rule = await page.evaluate(annotation => {
        const node = document.getElementById('block-0-s0').firstChild
        getSelection().setBaseAndExtent(node, 4, node, 10)
        document.dispatchEvent(new Event('selectionchange'))
        const payload = window.getCurrentTextSelection()
        getSelection().removeAllRanges()
        document.dispatchEvent(new Event('selectionchange'))
        const rendered = window.setArticleHighlights([{ id: 'h1', text: 'vision', cfiRange: payload.cfi, ...annotation }])
        const rules = [...document.styleSheets].flatMap(sheet => [...sheet.cssRules]).map(rule => rule.cssText)
        return { rendered: rendered.rendered, rule: rules.find(text => text.includes('::highlight(readflex-article-highlight-')) }
    }, annotation)
    assert.equal(rule.rendered, 1)
    const expected = premixHighlightColor(annotation, '#121212')
    assert.ok(rule.rule.includes(expected.replaceAll(',', ', ')), `${rule.rule} should use ${expected}`)
    // A theme change re-mixes the saved highlights without re-resolving them.
    const relit = await page.evaluate(() => {
        window.changeStyle({ backgroundColor: '#faf8f4', fontColor: '#292521' })
        return [...document.styleSheets].flatMap(sheet => [...sheet.cssRules]).map(rule => rule.cssText)
            .find(text => text.includes('::highlight(readflex-article-highlight-'))
    })
    assert.ok(relit.includes(premixHighlightColor(annotation, '#faf8f4').replaceAll(',', ', ')), relit)
})
