// Theme colors for image pages (PDF): paper takes the reader background and
// ink takes the reader text color. Applied to the bitmap once per render, so
// zooming and page turns cost nothing extra.

// Backgrounds this light are white paper already; recoloring would only
// soften black text.
const WHITE_PAPER_LUMINANCE = 0.98

// Reader themes darker than this invert pages instead of tinting them.
const DARK_THEME_LUMINANCE = 0.4

/** Parses `#rgb` or `#rrggbb` into [r, g, b], or null. */
export const parseHexColor = value => {
    const match = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(String(value ?? '').trim())
    if (!match) return null
    const hex = match[1].length === 3
        ? match[1].replace(/./g, digit => digit + digit)
        : match[1]
    return [0, 2, 4].map(offset => parseInt(hex.slice(offset, offset + 2), 16))
}

/** WCAG relative luminance of an [r, g, b] color in 0-255. */
export const relativeLuminance = ([r, g, b]) => {
    const linear = channel => {
        const value = channel / 255
        return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
    }
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}

const css = ([r, g, b]) => `rgb(${r}, ${g}, ${b})`

/**
 * Page colors for a reader style, or null to keep the page as published.
 *
 * @param {'theme' | 'original' | undefined} mode reader setting
 * @param {string} backgroundColor reader background, `#rrggbb`
 * @param {string} fontColor reader text color, `#rrggbb`
 * @returns {{ background: string, foreground: string, dark: boolean } | null}
 */
export const pageColorsFor = ({ mode, backgroundColor, fontColor }) => {
    if (mode !== 'theme') return null
    const background = parseHexColor(backgroundColor)
    if (!background) return null
    const paper = relativeLuminance(background)
    if (paper >= WHITE_PAPER_LUMINANCE) return null
    const dark = paper < DARK_THEME_LUMINANCE
    const foreground = parseHexColor(fontColor) ?? (dark ? [255, 255, 255] : [0, 0, 0])
    return { background: css(background), foreground: css(foreground), dark }
}

/** Whether two results of [pageColorsFor] draw the same pixels. */
export const samePageColors = (a, b) => a === b || (!!a && !!b
    && a.background === b.background
    && a.foreground === b.foreground
    && a.dark === b.dark)

const fill = (context, operation, color, width, height) => {
    context.globalCompositeOperation = operation
    context.fillStyle = color
    context.fillRect(0, 0, width, height)
}

/**
 * Recolors a rendered page bitmap in place.
 *
 * Light themes multiply the paper into the background and lift black to the
 * text color. Dark themes invert, take the hue back from the original so blue
 * stays blue, then map black to the background and white to the text color.
 * Photos invert too; readers who mind keep the original colors.
 *
 * @param {HTMLCanvasElement} canvas opaque page bitmap
 * @param {{ background: string, foreground: string, dark: boolean } | null} colors
 */
export const applyPageColors = (canvas, colors) => {
    if (!colors) return
    const { width, height } = canvas
    const context = canvas.getContext('2d')
    if (!context || !width || !height) return
    context.save()
    try {
        if (colors.dark) {
            const original = canvas.ownerDocument.createElement('canvas')
            original.width = width
            original.height = height
            try {
                original.getContext('2d').drawImage(canvas, 0, 0)
                fill(context, 'difference', '#ffffff', width, height)
                context.globalCompositeOperation = 'hue'
                context.drawImage(original, 0, 0)
            } finally {
                // WebKit frees canvas memory on resize, not on garbage collection.
                original.width = original.height = 0
            }
            fill(context, 'multiply', colors.foreground, width, height)
            fill(context, 'lighten', colors.background, width, height)
        } else {
            fill(context, 'multiply', colors.background, width, height)
            fill(context, 'lighten', colors.foreground, width, height)
        }
    } finally {
        context.restore()
    }
}
