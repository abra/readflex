// Geometry for fixed-layout pages: margin crops and sharp-zoom tiles.
// Pure functions. Lengths are page document pixels unless a name says CSS.

// Space kept between the detected ink and the cropped page edge, as a
// fraction of the page size.
export const CONTENT_CROP_PADDING = 0.02

// Pages whose ink is narrower than this fraction of the page (a title page,
// a lone figure) keep the whole page; cropping them would zoom one page far
// beyond its neighbours.
export const MIN_CONTENT_CROP_WIDTH = 0.5

// A page is redrawn sharper once the screen shows it this much denser than
// its bitmap. Smaller gaps are not visible and would waste renders.
export const SHARPEN_THRESHOLD = 1.1

// Extra area rendered around the visible part of a zoomed page so short pans
// stay sharp without another render.
export const TILE_MARGIN = 0.2

// Pixel budget for one sharp tile: about two phone screens, or 24 MiB of
// RGBA. WebKit caps a single canvas near 16.7 million pixels.
export const MAX_TILE_PIXELS = 6_000_000

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

/**
 * Crop that removes blank page margins around [content].
 *
 * Horizontal margins follow the ink. The height then grows to the aspect of
 * the available box, anchored at the top of the ink, so a page with less text
 * keeps the text size and the top edge of a full page.
 *
 * @param {{ left: number, top: number, right: number, bottom: number } | null} content
 * @param {number} width page width
 * @param {number} height page height
 * @param {number} availableWidth CSS width the page is fitted into
 * @param {number} availableHeight CSS height the page is fitted into
 * @returns {{ left: number, top: number, right: number, bottom: number } | null}
 *   null when the crop would keep the whole page or the page is too sparse.
 */
export const contentCrop = ({ content, width, height, availableWidth, availableHeight }) => {
    if (!content || !(width > 0) || !(height > 0)) return null
    const left = clamp(content.left - width * CONTENT_CROP_PADDING, 0, width)
    const right = clamp(content.right + width * CONTENT_CROP_PADDING, 0, width)
    const cropWidth = right - left
    if (!(cropWidth >= width * MIN_CONTENT_CROP_WIDTH)) return null

    const inkTop = clamp(content.top - height * CONTENT_CROP_PADDING, 0, height)
    const inkBottom = clamp(content.bottom + height * CONTENT_CROP_PADDING, inkTop, height)
    const aspect = availableWidth > 0 && availableHeight > 0
        ? availableHeight / availableWidth : 0
    const cropHeight = Math.min(height, Math.max(inkBottom - inkTop, cropWidth * aspect))
    // Shift up instead of running past the bottom edge.
    const top = Math.min(inkTop, height - cropHeight)
    const bottom = top + cropHeight
    if (left < 1 && top < 1 && right > width - 1 && bottom > height - 1) return null
    return { left, top, right, bottom }
}

/**
 * The visible part of a page that the screen shows denser than its bitmap.
 *
 * @param {DOMRectReadOnly} frameRect on-screen rect of the page window (CSS)
 * @param {{ left: number, top: number, right: number, bottom: number }} viewport
 *   on-screen rect that clips the page (CSS)
 * @param {{ left: number, top: number, width: number, height: number }} visible
 *   page area shown in the window: the crop, or the whole page
 * @param {number} baseDensity bitmap pixels per page pixel
 * @param {number} devicePixelRatio
 * @returns {{ left: number, top: number, width: number, height: number, density: number } | null}
 *   page area to redraw and the device pixels per page pixel it needs, or null
 *   when the bitmap is sharp enough or nothing is visible.
 */
export const sharpenRegion = ({ frameRect, viewport, visible, baseDensity, devicePixelRatio = 1 }) => {
    if (!(visible?.width > 0) || !(frameRect?.width > 0)) return null
    const cssPerPage = frameRect.width / visible.width
    const density = cssPerPage * devicePixelRatio
    if (!(density > baseDensity * SHARPEN_THRESHOLD)) return null
    const left = Math.max(frameRect.left, viewport.left)
    const top = Math.max(frameRect.top, viewport.top)
    const right = Math.min(frameRect.left + frameRect.width, viewport.right)
    const bottom = Math.min(frameRect.top + frameRect.height, viewport.bottom)
    if (right <= left || bottom <= top) return null
    return {
        left: visible.left + (left - frameRect.left) / cssPerPage,
        top: visible.top + (top - frameRect.top) / cssPerPage,
        width: (right - left) / cssPerPage,
        height: (bottom - top) / cssPerPage,
        density,
    }
}

const outward = (left, top, right, bottom, width, height) => {
    const x = Math.max(0, Math.floor(left))
    const y = Math.max(0, Math.floor(top))
    return {
        left: x,
        top: y,
        width: Math.min(width, Math.ceil(right)) - x,
        height: Math.min(height, Math.ceil(bottom)) - y,
    }
}

/**
 * Tile to render for [region]: the region plus a pan margin, clamped to the
 * page and fitted into [maxPixels]. The margin goes first, then density.
 *
 * @returns {{ left: number, top: number, width: number, height: number, density: number }}
 *   integer page rect and its device pixels per page pixel.
 */
export const tileFor = (region, { width, height }, maxPixels = MAX_TILE_PIXELS) => {
    const marginX = region.width * TILE_MARGIN
    const marginY = region.height * TILE_MARGIN
    const right = region.left + region.width
    const bottom = region.top + region.height
    let rect = outward(region.left - marginX, region.top - marginY,
        right + marginX, bottom + marginY, width, height)
    const pixels = r => r.width * r.height * region.density * region.density
    if (pixels(rect) > maxPixels) rect = outward(region.left, region.top, right, bottom, width, height)
    const area = rect.width * rect.height
    const density = area > 0 && pixels(rect) > maxPixels
        ? Math.sqrt(maxPixels / area)
        : region.density
    return { ...rect, density }
}

/** Whether a rendered [tile] still serves [region] without a new render. */
export const tileCovers = (tile, region) => {
    if (!tile || !region) return false
    const epsilon = 0.5
    return tile.density >= region.density * 0.95
        && tile.left <= region.left + epsilon
        && tile.top <= region.top + epsilon
        && tile.left + tile.width >= region.left + region.width - epsilon
        && tile.top + tile.height >= region.top + region.height - epsilon
}
