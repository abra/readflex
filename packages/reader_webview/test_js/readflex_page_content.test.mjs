import test from 'node:test'
import assert from 'node:assert/strict'
import { detectContentBox } from '../assets/foliate-js/src/readflex_page_content.js'

// Builds an RGBA sample filled with [paper] and lets [paint] set pixels.
function sample(width, height, paper = [255, 255, 255], paint = () => {}) {
    const data = new Uint8ClampedArray(width * height * 4)
    const set = (x, y, [r, g, b]) => {
        const offset = (y * width + x) * 4
        data[offset] = r; data[offset + 1] = g; data[offset + 2] = b; data[offset + 3] = 255
    }
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) set(x, y, paper)
    const rect = (left, top, right, bottom, color) => {
        for (let y = top; y < bottom; y++) for (let x = left; x < right; x++) set(x, y, color)
    }
    paint({ set, rect })
    return data
}

const ink = [20, 20, 20]

test('a text block on white paper is boxed with one pixel of slack', () => {
    const data = sample(113, 160, undefined, ({ rect }) => {
        // Lines of text: every other row inked between the margins.
        for (let y = 20; y < 140; y += 2) rect(15, y, 98, y + 1, ink)
    })
    assert.deepEqual(detectContentBox(data, 113, 160), { left: 14, top: 19, right: 99, bottom: 140 })
})

test('blank and too small samples have no content', () => {
    assert.equal(detectContentBox(sample(113, 160), 113, 160), null)
    assert.equal(detectContentBox(new Uint8ClampedArray(16), 2, 2), null)
    assert.equal(detectContentBox(new Uint8ClampedArray(10), 113, 160), null)
})

test('scan shadows on the edge and isolated specks do not stretch the box', () => {
    const data = sample(113, 160, undefined, ({ set, rect }) => {
        rect(0, 0, 1, 160, [60, 60, 60])        // binding shadow on the edge
        rect(30, 50, 80, 110, ink)              // printed area
        set(5, 5, ink)                          // speck in the margin
        set(100, 150, ink)
    })
    assert.deepEqual(detectContentBox(data, 113, 160), { left: 29, top: 49, right: 81, bottom: 111 })
})

test('gray scans measure ink against their own paper tone', () => {
    const paper = [200, 196, 188]
    const data = sample(113, 160, paper, ({ rect }) => {
        rect(20, 30, 90, 130, [60, 58, 55])
        rect(10, 10, 100, 12, [190, 186, 178]) // faint rule within the ink delta
    })
    assert.deepEqual(detectContentBox(data, 113, 160), { left: 19, top: 29, right: 91, bottom: 131 })
})

test('dark pages with light ink are found as well', () => {
    const data = sample(113, 160, [15, 17, 21], ({ rect }) => rect(25, 40, 85, 120, [190, 193, 202]))
    assert.deepEqual(detectContentBox(data, 113, 160), { left: 24, top: 39, right: 86, bottom: 121 })
})
