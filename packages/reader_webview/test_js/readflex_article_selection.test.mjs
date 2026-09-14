import test from 'node:test'
import assert from 'node:assert/strict'
import { articleContinuationRect } from '../assets/foliate-js/src/readflex_article_selection.js'

test('continuation controls appear only for endpoints outside the viewport', () => {
    for (const height of [240, 640, 844, 1024]) {
        for (const top of [-2000, -20, 0, 100, height - 1, height, height + 3000]) {
            const rect = { left: 60, right: 61, top, bottom: top + 20 }
            const actual = articleContinuationRect(rect, height)
            if (rect.bottom > 0 && rect.top < height) assert.equal(actual, null)
            else {
                assert.ok(actual.top >= 0 && actual.bottom <= height)
                assert.equal(actual.left, rect.left)
                assert.equal(actual.right, rect.right)
                assert.equal(rect.top, top, 'the original geometry is never mutated')
            }
        }
    }
    assert.equal(articleContinuationRect(null, 844), null)
})
