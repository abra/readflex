// Finds the printed area of a rendered page from a small RGBA sample.
// Pure: callers downscale the page bitmap and pass its pixels.

// Long side of the sample. The box is only as precise as one sample pixel,
// so crops add their own padding; 160 px keeps the read-back below 0.1 MiB.
export const PAGE_CONTENT_SAMPLE_SIZE = 160

// Luminance difference from the paper (0-255) that counts as ink. Faint
// gray rules and light scan noise stay paper; body text is far above it.
const INK_DELTA = 28

// Scans keep shadows and binding marks along the very edge of the page.
const EDGE_FRACTION = 0.01

// Rows and columns need this share of inked samples, or at least two, so
// isolated specks in a scanned margin do not stretch the box.
const MIN_INK_FRACTION = 0.01

const luminance = (data, offset) =>
    (data[offset] * 54 + data[offset + 1] * 183 + data[offset + 2] * 19) >> 8

const median = values => {
    if (!values.length) return 255
    values.sort((a, b) => a - b)
    return values[values.length >> 1]
}

/**
 * Bounding box of the ink on a page sample.
 *
 * The paper tone is the median of the ring just inside the ignored edge, so
 * off-white and gray scans work as well as white pages.
 *
 * @param {Uint8ClampedArray} data RGBA pixels, row-major
 * @param {number} width sample width
 * @param {number} height sample height
 * @returns {{ left: number, top: number, right: number, bottom: number } | null}
 *   sample-pixel box with exclusive right and bottom, or null for a blank page.
 */
export const detectContentBox = (data, width, height) => {
    if (!(width > 2) || !(height > 2) || data.length < width * height * 4) return null
    const edge = Math.max(1, Math.round(Math.min(width, height) * EDGE_FRACTION))
    const x0 = edge
    const y0 = edge
    const x1 = width - edge
    const y1 = height - edge
    if (x1 <= x0 || y1 <= y0) return null

    const ring = []
    for (let x = x0; x < x1; x++) {
        ring.push(luminance(data, (y0 * width + x) * 4))
        ring.push(luminance(data, ((y1 - 1) * width + x) * 4))
    }
    for (let y = y0 + 1; y < y1 - 1; y++) {
        ring.push(luminance(data, (y * width + x0) * 4))
        ring.push(luminance(data, (y * width + x1 - 1) * 4))
    }
    const paper = median(ring)

    const rows = new Uint32Array(height)
    const columns = new Uint32Array(width)
    for (let y = y0; y < y1; y++) {
        let offset = (y * width + x0) * 4
        for (let x = x0; x < x1; x++, offset += 4) {
            if (Math.abs(luminance(data, offset) - paper) > INK_DELTA) {
                rows[y]++
                columns[x]++
            }
        }
    }
    const minRowInk = Math.max(2, Math.round((x1 - x0) * MIN_INK_FRACTION))
    const minColumnInk = Math.max(2, Math.round((y1 - y0) * MIN_INK_FRACTION))
    let top = y0
    while (top < y1 && rows[top] < minRowInk) top++
    if (top === y1) return null
    let bottom = y1
    while (bottom > top && rows[bottom - 1] < minRowInk) bottom--
    let left = x0
    while (left < x1 && columns[left] < minColumnInk) left++
    let right = x1
    while (right > left && columns[right - 1] < minColumnInk) right--
    if (right <= left) return null
    // One sample pixel of slack covers ink that the downscale blended away.
    return {
        left: Math.max(0, left - 1),
        top: Math.max(0, top - 1),
        right: Math.min(width, right + 1),
        bottom: Math.min(height, bottom + 1),
    }
}
