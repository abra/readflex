import assert from 'node:assert/strict'
import test from 'node:test'
import { fixedSelectionBoundary, selectionNavigationDirection } from '../assets/foliate-js/src/readflex_selection_navigation.js'

test('tracks the unchanged boundary independently of DOM anchor/focus direction', () => {
    const node = {}
    const point = offset => ({ node, offset })
    const range = (start, end) => ({ start: point(start), end: point(end) })
    assert.deepEqual(fixedSelectionBoundary(range(10, 20), range(5, 20), point(10)), point(20))
    assert.deepEqual(fixedSelectionBoundary(range(10, 20), range(10, 25), point(20)), point(10))
    assert.deepEqual(fixedSelectionBoundary(range(10, 20), range(20, 30), point(20)), point(20))
    assert.deepEqual(fixedSelectionBoundary(range(10, 20), range(1, 10), point(10)), point(10))
    assert.equal(fixedSelectionBoundary(range(10, 20), range(30, 40), point(10)), null)
})

test('reversing and crossing the fixed boundary does not resurrect an old range', () => {
    const node = {}
    let previous = { start: { node, offset: 30 }, end: { node, offset: 40 } }
    let fixed = previous.start
    for (const offset of [50, 70, 50, 35, 20, 10, 35, 45]) {
        const next = { start: { node, offset: Math.min(30, offset) }, end: { node, offset: Math.max(30, offset) } }
        fixed = fixedSelectionBoundary(previous, next, fixed)
        assert.deepEqual(fixed, { node, offset: 30 })
        previous = next
    }
})

test('a separate gesture resolves to one page, with symmetric taps and RTL swipes', () => {
    const config = { width: 400, height: 800, vertical: true, rtl: false }
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 200, y: 240 }, config), 1)
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 200, y: 560 }, config), -1)
    assert.equal(selectionNavigationDirection({ x: 200, y: 30 }, { x: 200, y: 30 }, config), -1)
    assert.equal(selectionNavigationDirection({ x: 200, y: 770 }, { x: 200, y: 770 }, config), 1)
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 200, y: 400 }, config), 0)
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 250, y: 450 }, config), 0)
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 200, y: 430 }, config), 0)
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 40, y: 400 }, { ...config, vertical: false }), 1)
    assert.equal(selectionNavigationDirection({ x: 200, y: 400 }, { x: 40, y: 400 }, { ...config, vertical: false, rtl: true }), -1)
    assert.equal(selectionNavigationDirection({ x: 10, y: 400 }, { x: 10, y: 400 }, { ...config, vertical: false, rtl: true }), 1)
})
