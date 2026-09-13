import test from 'node:test'
import assert from 'node:assert/strict'
import { RemoteFile } from '../assets/foliate-js/src/remote_file.js'

const KiB = 1024
const MiB = 1024 * KiB

function fixture() {
    const file = new RemoteFile('http://fixture/book.cbz')
    file.size = 256 * MiB
    const requests = []
    file._fetchRange = async (start, end) => {
        requests.push([start, end])
        return new Uint8Array(end - start).fill(start / (64 * KiB) % 256).buffer
    }
    return { file, requests }
}

const retainedBytes = file => [...file._cache.values()]
    .reduce((total, buffer) => total + buffer.byteLength, 0)

test('ZIP-sized reads stay within an 8 MiB retained cache budget', async () => {
    const { file } = fixture()
    for (let i = 0; i < 128; i++)
        await file.slice(i * MiB, i * MiB + 512 * KiB).arrayBuffer()
    assert.ok(retainedBytes(file) <= 8 * MiB)
})

test('oversized reads return all bytes without evicting the working set', async () => {
    const { file, requests } = fixture()
    await file.slice(0, 100).arrayBuffer()
    const large = await file.slice(MiB, 17 * MiB).arrayBuffer()
    assert.equal(large.byteLength, 16 * MiB)
    assert.ok(retainedBytes(file) <= 8 * MiB)
    await file.slice(0, 100).arrayBuffer()
    assert.equal(requests.length, 2)
})

test('adjacent and concurrent probes reuse one range request', async () => {
    const { file, requests } = fixture()
    await Promise.all([file.slice(0, 4).arrayBuffer(), file.slice(0, 4).arrayBuffer()])
    await file.slice(40, 48).arrayBuffer()
    assert.deepEqual(requests, [[0, 64 * KiB]])
})

test('recent chunks survive byte-budget eviction and evicted chunks refetch', async () => {
    const { file, requests } = fixture()
    for (let i = 0; i < 16; i++)
        await file.slice(i * MiB, i * MiB + 512 * KiB).arrayBuffer()
    await file.slice(0, 10).arrayBuffer()
    await file.slice(16 * MiB, 16 * MiB + 512 * KiB).arrayBuffer()
    await file.slice(0, 10).arrayBuffer()
    assert.equal(requests.length, 17)
    const result = await file.slice(MiB, MiB + 10).arrayBuffer()
    assert.equal(requests.length, 18)
    assert.deepEqual([...new Uint8Array(result)], Array(10).fill(16))
})

test('a growing chunk replaces its slot without double-counting retained bytes', async () => {
    const { file, requests } = fixture()
    await file.slice(0, 10).arrayBuffer()
    await file.slice(0, MiB).arrayBuffer()
    assert.equal(retainedBytes(file), MiB)
    assert.equal(file._cacheBytes, MiB)
    await file.slice(100, 200).arrayBuffer()
    assert.equal(requests.length, 2)
})

test('failed requests leave no poisoned in-flight entry and can retry', async () => {
    const { file } = fixture()
    const fetch = file._fetchRange
    file._fetchRange = async () => { throw new Error('Transport failure') }
    await assert.rejects(file.slice(0, 4).arrayBuffer(), /Transport failure/)
    assert.equal(file._inFlight.size, 0)
    assert.equal(retainedBytes(file), 0)
    file._fetchRange = fetch
    assert.equal((await file.slice(0, 4).arrayBuffer()).byteLength, 4)
})

test('a late smaller response does not shrink an already cached chunk', async () => {
    const { file } = fixture()
    const pending = []
    file._fetchRange = (start, end) => new Promise(resolve => pending.push({ end, resolve }))
    const small = file.slice(0, 4).arrayBuffer()
    const large = file.slice(0, 512 * KiB).arrayBuffer()
    pending[1].resolve(new ArrayBuffer(pending[1].end))
    await large
    pending[0].resolve(new ArrayBuffer(pending[0].end))
    await small
    assert.equal(retainedBytes(file), 512 * KiB)
    assert.equal(file._cacheBytes, retainedBytes(file))
    await file.slice(128 * KiB, 256 * KiB).arrayBuffer()
    assert.equal(pending.length, 2)
})
