// Font declarations shared by the book and article shells. Both resolve the
// bundled symbol fallback against this module, because chapter documents use
// blob URLs and the article shell installs a content <base>.

export const symbolFontFamily = 'Noto Sans Symbols'
export const symbolFontURL = new URL('../../fonts/NotoSansSymbols-Regular.ttf', import.meta.url).href

export const escapeCSSString = value => String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')

export const quoteFontFamily = value => `"${escapeCSSString(value)}"`

const escapeCSSUrl = value => String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll("'", "\\'")

const genericFamilies = new Set(['serif', 'sans-serif', 'monospace', 'system-ui'])

export const getFontFamilyToken = fontName => fontName === 'system'
    ? 'system-ui'
    : genericFamilies.has(fontName) ? fontName : quoteFontFamily(fontName)

// Selected family first, bundled symbol coverage last.
export const readerFontFamilyChain = fontName =>
    `${getFontFamilyToken(fontName)}, ${quoteFontFamily(symbolFontFamily)}`

// Only the variable TTFs carry a weight axis. A static face must keep the
// default descriptor so bold text is synthesized instead of drawn regular.
export const isVariableFontPath = fontPath =>
    /-Variable\.[a-z0-9]+(?:[?#].*)?$/i.test(String(fontPath ?? ''))

export const readerFontFaceCSS = ({ fontName, fontPath } = {}) => {
    if (!fontName || fontName === 'book' || fontName === 'system' || !fontPath) return ''
    const weightDecl = isVariableFontPath(fontPath) ? '\n      font-weight: 100 900;' : ''
    return `
    @font-face {
      font-family: ${quoteFontFamily(fontName)};
      src: url('${escapeCSSUrl(fontPath)}');${weightDecl}
      font-display: swap;
    }`
}

export const symbolFontFaceCSS = () => `
    @font-face {
      font-family: ${quoteFontFamily(symbolFontFamily)};
      src: url('${symbolFontURL}');
      font-display: swap;
    }`
