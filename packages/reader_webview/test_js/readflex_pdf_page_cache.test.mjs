import test from 'node:test'
import assert from 'node:assert/strict'
import { createPdfPageCache } from '../assets/foliate-js/src/readflex_pdf_page_cache.js'

// Renders resolve when the test calls `finish(index)` or immediately.
function fixture({ count = 20, manual = false, fail = () => false } = {}) {
    const renders = []
    const released = []
    const aborted = []
    const pending = new Map()
    const cache = createPdfPageCache({
        count,
        render: (index, signal) => {
            renders.push(index)
            signal.addEventListener('abort', () => aborted.push(index))
            if (fail(index)) return Promise.reject(new Error(`page ${index}`))
            if (!manual) return Promise.resolve({ index })
            return new Promise(resolve => pending.set(index, () => resolve({ index })))
        },
        release: value => released.push(value.index),
    })
    const finish = index => { pending.get(index)?.(); pending.delete(index) }
    return { cache, renders, released, aborted, finish }
}

test('concurrent loads of one page share a single render', async () => {
    const { cache, renders } = fixture()
    const [a, b] = await Promise.all([cache.load(3), cache.load(3)])
    assert.equal(a, b)
    assert.deepEqual(renders, [3])
    assert.equal(cache.peek(3), a)
})

test('reading forward keeps the visible page and its neighbours only', async () => {
    const { cache, released } = fixture()
    for (let index = 0; index < 8; index++) {
        await cache.load(index)
        await cache.retain([index])
    }
    assert.deepEqual(cache.ready().map(([index]) => index), [7, 6, 8])
    assert.deepEqual(released, [0, 1, 2, 3, 4, 5])
    assert.equal(cache.size, 3)
})

test('prefetch renders the next page before the previous one and stays in range', async () => {
    const { cache, renders } = fixture({ count: 5 })
    await cache.load(2)
    await cache.retain([2])
    assert.deepEqual(renders, [2, 3, 1])
    await cache.load(4)
    await cache.retain([4])
    assert.deepEqual(renders, [2, 3, 1, 4], 'page 3 is cached; there is no page 5')
    await cache.retain([4], { prefetch: false })
    await cache.retain([-1, 9, 0.5])
    assert.equal(cache.size, 2)
})

test('a spread keeps both pages and the pages around it', async () => {
    const { cache } = fixture()
    await Promise.all([cache.load(4), cache.load(5)])
    await cache.retain([4, 5])
    assert.deepEqual(cache.ready().map(([index]) => index).sort((a, b) => a - b), [3, 4, 5, 6])
})

test('releasing a page aborts its render and drops the late result', async () => {
    const { cache, aborted, released, finish } = fixture({ manual: true })
    const far = cache.load(10)
    const visible = cache.load(0)
    finish(0)
    await visible
    const retain = cache.retain([0], { prefetch: false })
    await retain
    assert.deepEqual(aborted, [10])
    finish(10)
    await assert.rejects(far, { name: 'AbortError' })
    assert.deepEqual(released, [10], 'the finished bitmap of a released page is freed')
    assert.equal(cache.peek(10), undefined)
})

test('a newer window cancels the rest of an older prefetch', async () => {
    const { cache, renders, finish } = fixture({ manual: true })
    const first = cache.load(5)
    finish(5)
    await first
    const prefetch = cache.retain([5])
    await Promise.resolve()
    assert.deepEqual(renders, [5, 6], 'the next page renders first')
    const jump = cache.load(15)
    finish(15)
    await jump
    void cache.retain([15], { prefetch: false })
    finish(6)
    await prefetch
    assert.deepEqual(renders, [5, 6, 15], 'the old prefetch never renders page 4')
})

test('failed pages are retried on the next demand and do not stop prefetch', async () => {
    let failures = 1
    const { cache, renders } = fixture({ fail: index => index === 3 && failures-- > 0 })
    await cache.load(2)
    await cache.retain([2])
    assert.deepEqual(renders, [2, 3, 1])
    assert.equal(cache.peek(3), undefined)
    assert.deepEqual(await cache.load(3), { index: 3 })
})

test('destroy releases every page and rejects later loads', async () => {
    const { cache, released } = fixture()
    await cache.load(1)
    await cache.retain([1])
    cache.destroy()
    assert.deepEqual(released.sort(), [0, 1, 2])
    await assert.rejects(cache.load(1), { name: 'AbortError' })
    await cache.retain([1])
    assert.equal(cache.size, 0)
})
