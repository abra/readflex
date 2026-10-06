import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import * as constants from '../assets/foliate-js/src/readflex_shell_constants.js'
import { ACTIVE_SEARCH_HIGHLIGHT_COLOR } from '../assets/foliate-js/src/readflex_search_occlusion.js'

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8')
const articleShell = read('../assets/article-html/index.html')
const bookShell = read('../assets/foliate-js/src/book.js')
const viewRuntime = read('../assets/foliate-js/src/view.js')

test('shared defaults keep the book values', () => {
    assert.equal(constants.READFLEX_HIGHLIGHT_OPACITY, 0.62)
    assert.equal(constants.READFLEX_HIGHLIGHT_RADIUS, 3)
    assert.equal(constants.READFLEX_HIGHLIGHT_VERTICAL_INSET, 1.5)
    assert.equal(constants.READFLEX_SELECTION_PREVIEW_HIGHLIGHT_OPACITY, 0.5)
    assert.equal(constants.SEARCH_HIGHLIGHT_COLOR, '#00d4d8')
    assert.equal(constants.SEARCH_HIGHLIGHT_OPACITY, 0.16)
    assert.equal(constants.ACTIVE_SEARCH_HIGHLIGHT_COLOR, '#ffb300')
    assert.equal(constants.ACTIVE_SEARCH_HIGHLIGHT_OPACITY, 0.36)
    assert.equal(constants.SEARCH_HIGHLIGHT_PADDING, 1)
    assert.equal(constants.SEARCH_HIGHLIGHT_RADIUS, 3)
    assert.equal(constants.READFLEX_SELECTION_CLICK_SUPPRESS_MS, 200)
    assert.equal(ACTIVE_SEARCH_HIGHLIGHT_COLOR, constants.ACTIVE_SEARCH_HIGHLIGHT_COLOR,
        'the occlusion indicator must paint the same active colour')
})

test('search fills reference overridable variables with shared fallbacks', () => {
    assert.deepEqual(constants.searchHighlightFill(true), {
        color: 'var(--rf-search-active-color, #ffb300)',
        opacity: 'var(--rf-search-active-opacity, 0.36)',
    })
    assert.deepEqual(constants.searchHighlightFill(false), {
        color: 'var(--rf-search-match-color, #00d4d8)',
        opacity: 'var(--rf-search-match-opacity, 0.16)',
    })
    const root = constants.searchHighlightRootCSS()
    assert.match(root, /^:root \{/)
    for (const name of [
        constants.SEARCH_MATCH_COLOR_VAR, constants.SEARCH_MATCH_OPACITY_VAR,
        constants.SEARCH_ACTIVE_COLOR_VAR, constants.SEARCH_ACTIVE_OPACITY_VAR,
    ]) assert.ok(root.includes(`${name}:`), name)
})

test('both shells import the shared constants instead of local copies', () => {
    assert.ok(articleShell.includes('readflex_shell_constants.js'))
    assert.ok(bookShell.includes('readflex_shell_constants.js'))
    assert.ok(viewRuntime.includes('readflex_shell_constants.js'))
    assert.ok(articleShell.includes('selectionClickSuppressMs = READFLEX_SELECTION_CLICK_SUPPRESS_MS'))
    assert.ok(bookShell.includes('< READFLEX_SELECTION_CLICK_SUPPRESS_MS'))
    for (const [name, source] of [['article', articleShell], ['book', bookShell], ['view', viewRuntime]]) {
        assert.ok(!/const READFLEX_HIGHLIGHT_OPACITY\s*=/.test(source), name)
        assert.ok(!/SEARCH_HIGHLIGHT_COLOR\s*=\s*'#/.test(source), name)
        assert.ok(!/selectionClickSuppressMs\s*=\s*\d/.test(source), name)
        assert.ok(!source.includes('rgb(255 179 0 / 28%)'), name)
        assert.ok(!/0\.38\b/.test(source), `${name} must not keep the old article fallback opacity`)
    }
    assert.ok(!/<\s*200\b/.test(bookShell), 'book tap debounce must use the shared constant')
})
