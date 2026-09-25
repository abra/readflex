import test from 'node:test'
import assert from 'node:assert/strict'
import { makeComicBook } from '../assets/foliate-js/src/comic-book.js'

function fixture(t, { count = 20, size = 1024, load } = {}) {
    const live = new Set()
    const requests = []
    let serial = 0
    t.mock.method(URL, 'createObjectURL', () => {
        const url = `blob:test-${serial++}`
        live.add(url)
        return url
    })
    t.mock.method(URL, 'revokeObjectURL', url => live.delete(url))
    const book = makeComicBook({
        entries: Array.from({ length: count }, (_, i) => ({ filename: `${String(i).padStart(3, '0')}.jpg` })),
        getSize: () => size,
        loadBlob: name => {
            requests.push(name)
            return load ? load(name) : Promise.resolve(new Blob([new Uint8Array(size)]))
        },
    }, { name: 'fixture.cbz' })
    t.after(() => book.destroy())
    return { book, live, requests }
}

test('concurrent comic page loads share extraction and object URLs', async t => {
    const { book, live, requests } = fixture(t)
    const urls = await Promise.all([book.sections[0].load(), book.sections[0].load()])
    assert.equal(urls[0], urls[1])
    assert.equal(requests.length, 1)
    assert.equal(live.size, 2)
})

test('comic prefetch retains only the visible spread and adjacent pages', async t => {
    const { book, live, requests } = fixture(t)
    for (let index = 0; index < 19; index += 2) {
        await Promise.all([book.sections[index].load(), book.sections[index + 1].load()])
        await book.prepareAdjacentPages([index, index + 1])
        assert.ok(live.size <= 8, `retained ${live.size / 2} pages at ${index}`)
    }
    const before = requests.length
    await book.sections[17].load()
    assert.equal(requests.length, before, 'previous neighbour is cached')
    await book.sections[0].load()
    assert.equal(requests.length, before + 1, 'distant pages were released')
})

test('oversized comic images are demand-loaded but not prefetched', async t => {
    const { book, requests, live } = fixture(t, { size: 9 * 1024 * 1024 })
    await book.sections[1].load()
    await book.prepareAdjacentPages([1])
    assert.deepEqual(requests, ['001.jpg'])
    assert.equal(live.size, 2)
})

test('destroy during extraction cannot resurrect comic resources', async t => {
    let finish
    const { book, live } = fixture(t, { load: () => new Promise(resolve => { finish = resolve }) })
    const loading = book.sections[0].load()
    book.destroy()
    finish(new Blob(['image']))
    await assert.rejects(loading, { name: 'AbortError' })
    assert.equal(live.size, 0)
})

test('failed comic extraction can be retried', async t => {
    let fail = true
    const { book, requests } = fixture(t, { load: async () => {
        if (fail) throw new Error('read failed')
        return new Blob(['image'])
    } })
    await assert.rejects(book.sections[0].load(), /read failed/)
    fail = false
    await book.sections[0].load()
    assert.equal(requests.length, 2)
})

test('changing the retained window discards late speculative extraction', async t => {
    let finishOld
    const { book, live, requests } = fixture(t, { load: name => name === '002.jpg'
        ? new Promise(resolve => { finishOld = resolve })
        : Promise.resolve(new Blob(['image'])) })
    await book.sections[1].load()
    const oldWindow = book.prepareAdjacentPages([1])
    await book.sections[10].load()
    await book.prepareAdjacentPages([10])
    finishOld(new Blob(['obsolete']))
    await oldWindow
    assert.equal(live.size, 6)
    assert.ok(!requests.includes('000.jpg'), 'obsolete window must stop prefetching')
})

test('neighbour prefetch shares a total byte budget, not one budget per image', async t => {
    const { book, requests } = fixture(t, { size: 5 * 1024 * 1024 })
    await book.sections[1].load()
    await book.prepareAdjacentPages([1])
    assert.deepEqual(requests, ['001.jpg', '002.jpg'])
})

test('continuous navigation releases distant pages without starting speculative work', async t => {
    const { book, live, requests } = fixture(t)
    for (let index = 0; index < 19; index += 2) {
        await Promise.all([book.sections[index].load(), book.sections[index + 1].load()])
        await book.prepareAdjacentPages([index, index + 1], { prefetch: false })
        assert.ok(live.size <= 6, 'current spread plus its already-loaded predecessor')
    }
    assert.equal(requests.length, 20)
})
