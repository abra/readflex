import {
    READFLEX_HIGHLIGHT_OPACITY,
    READFLEX_HIGHLIGHT_RADIUS,
    READFLEX_HIGHLIGHT_VERTICAL_INSET,
} from './readflex_shell_constants.js'

const DEFAULT_HIGHLIGHT_COLOR = '#FFE600'

export const parseHexColor = value => {
    const text = String(value ?? '').trim()
    const match = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec(text)
    if (!match) return null
    let hex = match[1]
    if (hex.length === 3) hex = [...hex].map(c => c + c).join('')
    return [0, 2, 4].map(i => parseInt(hex.slice(i, i + 2), 16))
}

const clamp01 = value => {
    const number = Number(value)
    if (!Number.isFinite(number)) return null
    return Math.min(1, Math.max(0, number))
}

const finiteOr = (value, fallback) => {
    const number = Number(value)
    return Number.isFinite(number) ? number : fallback
}

// Normalizes an annotation/preview payload into the option set drawn by
// Overlayer.highlight, so both shells apply the same opacity/offset/shape.
export const highlightDrawOptions = annotation => {
    const color = parseHexColor(annotation?.color)
        ? String(annotation.color)
        : DEFAULT_HIGHLIGHT_COLOR
    const mixBlendMode = ['multiply', 'lighten'].includes(annotation?.mixBlendMode)
        ? annotation.mixBlendMode
        : 'normal'
    return {
        color,
        opacity: clamp01(annotation?.opacity) ?? READFLEX_HIGHLIGHT_OPACITY,
        mixBlendMode,
        verticalOffset: finiteOr(annotation?.verticalOffset, 0),
        radius: finiteOr(annotation?.radius, READFLEX_HIGHLIGHT_RADIUS),
        verticalInset: finiteOr(annotation?.verticalInset, READFLEX_HIGHLIGHT_VERTICAL_INSET),
    }
}

const blendChannel = (mode, source, backdrop) => {
    if (mode === 'multiply') return source * backdrop / 255
    if (mode === 'lighten') return Math.max(source, backdrop)
    return source
}

// CSS Custom Highlights cannot blend. Composite the tint against the page
// background once so a `::highlight` fill looks like the book overlay:
// result = opacity * blend(color, page) + (1 - opacity) * page.
export const premixHighlightColor = (options, pageBackground) => {
    const { color, opacity, mixBlendMode } = highlightDrawOptions(options)
    const source = parseHexColor(color)
    const backdrop = parseHexColor(pageBackground)
    if (!backdrop) return `rgba(${source.join(',')},${opacity})`
    const mixed = source.map((channel, i) => Math.round(
        opacity * blendChannel(mixBlendMode, channel, backdrop[i])
            + (1 - opacity) * backdrop[i],
    ))
    return `rgb(${mixed.join(',')})`
}
