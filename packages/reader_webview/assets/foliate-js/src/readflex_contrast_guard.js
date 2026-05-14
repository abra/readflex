const GUARD_ATTR = 'data-readflex-contrast-guard'
const ORIGINAL_COLOR_ATTR = 'data-readflex-contrast-original-color'
const ORIGINAL_PRIORITY_ATTR = 'data-readflex-contrast-original-priority'

const TEXT_ELEMENT_SELECTOR = [
  'a',
  'abbr',
  'b',
  'blockquote',
  'caption',
  'cite',
  'code',
  'dd',
  'dfn',
  'div',
  'dt',
  'em',
  'figcaption',
  'font',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'i',
  'kbd',
  'label',
  'li',
  'mark',
  'p',
  'pre',
  'q',
  'samp',
  'small',
  'span',
  'strong',
  'sub',
  'sup',
  'td',
  'th',
].join(',')

const SKIP_SELECTOR = [
  'audio',
  'canvas',
  'embed',
  'iframe',
  'img',
  'math',
  'mjx-container',
  'object',
  'picture',
  'script',
  'source',
  'style',
  'svg',
  'video',
].join(',')

const clamp01 = value => Math.min(Math.max(value, 0), 1)

const parseChannel = value => {
  const text = `${value ?? ''}`.trim()
  const number = Number.parseFloat(text)
  if (!Number.isFinite(number)) return null
  return text.endsWith('%')
    ? Math.round(clamp01(number / 100) * 255)
    : Math.min(Math.max(number, 0), 255)
}

const parseAlpha = value => {
  if (value == null || value === '') return 1
  const text = `${value}`.trim()
  const number = Number.parseFloat(text)
  if (!Number.isFinite(number)) return 1
  return text.endsWith('%') ? clamp01(number / 100) : clamp01(number)
}

export const parseCssColor = value => {
  const text = `${value ?? ''}`.trim()
  if (!text || text === 'transparent' || text === 'none') return null

  if (text.startsWith('#')) {
    const hex = text.slice(1)
    const expand = value => value.length === 1 ? `${value}${value}` : value
    if (![3, 4, 6, 8].includes(hex.length)) return null

    const parts = hex.length <= 4
      ? [expand(hex[0]), expand(hex[1]), expand(hex[2]), expand(hex[3] ?? 'f')]
      : [hex.slice(0, 2), hex.slice(2, 4), hex.slice(4, 6), hex.slice(6, 8) || 'ff']

    const channels = parts.map(part => Number.parseInt(part, 16))
    if (channels.some(channel => !Number.isFinite(channel))) return null
    return {
      r: channels[0],
      g: channels[1],
      b: channels[2],
      a: channels[3] / 255,
    }
  }

  const rgbMatch = text.match(/^rgba?\((.*)\)$/i)
  if (!rgbMatch) return null

  const normalized = rgbMatch[1].replace(/\s*\/\s*/, ' / ')
  const parts = normalized.includes(',')
    ? normalized.split(/\s*,\s*/)
    : normalized.split(/\s+/)

  const slashIndex = parts.indexOf('/')
  const alphaPart = slashIndex === -1 ? parts[3] : parts[slashIndex + 1]
  const colorParts = slashIndex === -1 ? parts.slice(0, 3) : parts.slice(0, slashIndex)
  if (colorParts.length < 3) return null

  const [r, g, b] = colorParts.map(parseChannel)
  if ([r, g, b].some(channel => channel == null)) return null
  return { r, g, b, a: parseAlpha(alphaPart) }
}

const composite = (foreground, background) => {
  const alpha = foreground.a + background.a * (1 - foreground.a)
  if (alpha <= 0) return { r: 0, g: 0, b: 0, a: 0 }

  return {
    r: (foreground.r * foreground.a + background.r * background.a * (1 - foreground.a)) / alpha,
    g: (foreground.g * foreground.a + background.g * background.a * (1 - foreground.a)) / alpha,
    b: (foreground.b * foreground.a + background.b * background.a * (1 - foreground.a)) / alpha,
    a: alpha,
  }
}

const linearize = channel => {
  const value = channel / 255
  return value <= 0.03928
    ? value / 12.92
    : ((value + 0.055) / 1.055) ** 2.4
}

export const relativeLuminance = color =>
  0.2126 * linearize(color.r) +
  0.7152 * linearize(color.g) +
  0.0722 * linearize(color.b)

export const contrastRatio = (a, b) => {
  const lighter = Math.max(relativeLuminance(a), relativeLuminance(b))
  const darker = Math.min(relativeLuminance(a), relativeLuminance(b))
  return (lighter + 0.05) / (darker + 0.05)
}

const hasDirectText = element =>
  Array.from(element.childNodes).some(node =>
    node.nodeType === Node.TEXT_NODE && node.textContent?.trim()
  )

const restoreGuardedColor = element => {
  if (element.getAttribute(GUARD_ATTR) !== 'true') return

  const originalColor = element.getAttribute(ORIGINAL_COLOR_ATTR) ?? ''
  const originalPriority = element.getAttribute(ORIGINAL_PRIORITY_ATTR) ?? ''
  if (originalColor) {
    element.style.setProperty('color', originalColor, originalPriority)
  } else {
    element.style.removeProperty('color')
  }

  element.removeAttribute(GUARD_ATTR)
  element.removeAttribute(ORIGINAL_COLOR_ATTR)
  element.removeAttribute(ORIGINAL_PRIORITY_ATTR)
}

const effectiveBackgroundColor = (element, fallbackColor, win) => {
  let result = fallbackColor
  const chain = []
  let current = element

  while (current?.nodeType === Node.ELEMENT_NODE) {
    chain.push(current)
    current = current.parentElement
  }

  for (const item of chain.reverse()) {
    const background = parseCssColor(win.getComputedStyle(item).backgroundColor)
    if (background && background.a > 0) {
      result = composite(background, result)
    }
  }

  return result
}

const fallbackTextColorFor = background => {
  const white = { r: 255, g: 255, b: 255, a: 1 }
  const black = { r: 0, g: 0, b: 0, a: 1 }
  return contrastRatio(white, background) >= contrastRatio(black, background)
    ? '#ffffff'
    : '#000000'
}

const shouldSkipElement = (element, computedStyle) =>
  !element.style ||
  element.matches(SKIP_SELECTOR) ||
  element.closest(SKIP_SELECTOR) ||
  element.closest('[hidden], [aria-hidden="true"]') ||
  computedStyle.display === 'none' ||
  computedStyle.visibility === 'hidden' ||
  !hasDirectText(element)

export const applyTextContrastGuard = (doc, {
  backgroundColor,
  textColor,
  minContrast = 4.5,
} = {}) => {
  const win = doc?.defaultView
  const body = doc?.body
  if (!win || !body) return

  const readerBackground = parseCssColor(backgroundColor)
  if (!readerBackground) return

  const safeTextColor = parseCssColor(textColor)
  const isDarkReaderTheme = relativeLuminance(readerBackground) < 0.5

  for (const element of body.querySelectorAll(`[${GUARD_ATTR}="true"]`)) {
    restoreGuardedColor(element)
  }

  if (!isDarkReaderTheme || !safeTextColor) return

  for (const element of body.querySelectorAll(TEXT_ELEMENT_SELECTOR)) {
    const computedStyle = win.getComputedStyle(element)
    if (shouldSkipElement(element, computedStyle)) continue

    const color = parseCssColor(computedStyle.color)
    if (!color || color.a <= 0) continue

    const background = effectiveBackgroundColor(element, readerBackground, win)
    const visibleColor = color.a < 1 ? composite(color, background) : color
    if (contrastRatio(visibleColor, background) >= minContrast) continue

    const replacement = contrastRatio(safeTextColor, background) >= minContrast
      ? textColor
      : fallbackTextColorFor(background)

    element.setAttribute(GUARD_ATTR, 'true')
    element.setAttribute(
      ORIGINAL_COLOR_ATTR,
      element.style.getPropertyValue('color'),
    )
    element.setAttribute(
      ORIGINAL_PRIORITY_ATTR,
      element.style.getPropertyPriority('color'),
    )
    element.style.setProperty('color', replacement, 'important')
  }
}
