import test from 'node:test'
import assert from 'node:assert/strict'
import { createFileRangeTransport } from '../assets/foliate-js/src/readflex_pdf_ranges.js'

// Stand-in for pdfjsLib.PDFDataRangeTransport: records what pdf.js would get.
class Transport {
    constructor(length, initialData) {
        this.length = length
        this.initialData = initialData
        this.ranges = []
    }
    onDataRange(begin, chunk) {
        this.ranges.push([begin, [...chunk]])
    }
}

const fileOf = (bytes, { reject = null } = {}) => {
    const reads = []
    return {
        reads,
        size: bytes.length,
        slice: (start, end) => ({
            arrayBuffer: async () => {
                reads.push([start, end])
                if (reject) throw reject
                return Uint8Array.from(bytes.slice(start, end)).buffer
            },
        }),
    }
}

const settle = () => new Promise(resolve => setTimeout(resolve))

test('a requested range reaches pdf.js as one chunk at its start', async () => {
    const file = fileOf([0, 1, 2, 3, 4, 5, 6, 7])
    const { transport } = createFileRangeTransport(Transport, file)
    assert.equal(transport.length, 8)
    assert.equal(transport.initialData, null)
    transport.requestDataRange(2, 6)
    await settle()
    assert.deepEqual(file.reads, [[2, 6]])
    assert.deepEqual(transport.ranges, [[2, [2, 3, 4, 5]]])
})

test('ranges that arrive after abort are dropped', async () => {
    const file = fileOf([0, 1, 2, 3])
    const { transport } = createFileRangeTransport(Transport, file)
    transport.requestDataRange(0, 4)
    transport.abort()
    await settle()
    assert.deepEqual(transport.ranges, [])
})

test('a failed read rejects failed and delivers nothing', async () => {
    const error = new Error('range failed')
    const file = fileOf([0, 1, 2, 3], { reject: error })
    const { transport, failed } = createFileRangeTransport(Transport, file)
    transport.requestDataRange(0, 4)
    await assert.rejects(failed, error)
    assert.deepEqual(transport.ranges, [])
})
