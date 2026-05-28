// Runtime-only cleanup for publisher-controlled iframe documents. Keep
// transforms idempotent: this runs after each foliate-js section load and
// never rewrites the user's original EPUB or saved article files.
const ELEMENT_NODE = globalThis.Node?.ELEMENT_NODE ?? 1
const TEXT_NODE = globalThis.Node?.TEXT_NODE ?? 3

const CODE_BLOCK_CLASS_PATTERN =
  /(?:^|[-_\s])(?:programcode|paratypeprogramcode|programlisting|screen|sourcecode|source|codeblock|listing|literal|literallayout|verbatim|console|terminal|cmd|shell|highlight|hljs)(?:$|[-_\s])/i
const CODE_CLASS_FRAGMENT_PATTERN =
  /(?:program|source|sample|example|syntax|highlight)?code(?:block|listing|sample|example|snippet|source|area|container|fragment|line|text)?/i
const NON_CODE_CLASS_FRAGMENT_PATTERN =
  /(?:decode|encode|unicode|barcode|postcode|zipcode|classificationcode)/i
const MONOSPACE_FONT_PATTERN =
  /\b(?:mono|menlo|monaco|consolas|courier|source code|jetbrains|fira code|cascadia|ui-monospace)\b/i
const CODE_TEXT_PATTERN =
  /[{};<>]|(?:^|\s)(?:import|package|public|private|protected|class|interface|return|throw|new|if|else|for|while|try|catch|@Bean|@Configuration)\b/
const CODE_BLOCK_MIN_TEXT_LENGTH = 80

export const languageInfo = lang => {
  if (!lang) return {}
  try {
    const canonical = Intl.getCanonicalLocales(lang)[0] ?? 'en'
    const locale = new Intl.Locale(canonical)
    const isCJK = ['zh', 'ja', 'kr'].includes(locale.language)
    const direction = (locale.getTextInfo?.() ?? locale.textInfo)?.direction
    return { canonical, locale, isCJK, direction }
  } catch (e) {
    console.warn(e)
    return {}
  }
}

const rtlSampleRegex = /[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g
const ltrSampleRegex = /[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]/g

export const inferDocumentDirection = doc => {
  const sample = (doc.body?.textContent ?? '')
    .replace(/\s+/g, ' ')
    .slice(0, 5000)
  if (!sample) return ''

  const rtlCount = sample.match(rtlSampleRegex)?.length ?? 0
  const ltrCount = sample.match(ltrSampleRegex)?.length ?? 0
  return rtlCount > ltrCount ? 'rtl' : ''
}

export const applyArticleTextDirection = (doc, direction) => {
  if (!direction) return

  // Keep the root RTL too: CSS columns use it for physical page order.
  doc.documentElement.dir = direction
  doc.documentElement.dataset.readflexTextDirection = direction
  if (doc.body) doc.body.dir = direction

  const selector = [
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'p', 'li', 'blockquote', 'dd', 'dt', 'figcaption', 'caption',
    'section', 'article', 'main', 'div:not(.readflex-wide-table)',
    'th', 'td',
  ].join(',')
  const nodes = Array.from(doc.body?.querySelectorAll(selector) ?? [])
  if (nodes.length === 0 && doc.body) nodes.push(doc.body)
  for (const node of nodes) {
    node.style.setProperty('direction', direction, 'important')
    node.style.setProperty('unicode-bidi', 'plaintext')
    node.style.setProperty(
      'text-align',
      'var(--readflex-rtl-article-text-align, right)',
      'important'
    )
  }

  if (doc.getElementById('readflex-article-text-direction')) return

  const style = doc.createElement('style')
  style.id = 'readflex-article-text-direction'
  style.textContent = [
    'body > h1, body > h2, body > h3, body > h4, body > h5, body > h6,',
    'body > p, body > ul, body > ol, body > blockquote,',
    'body > section, body > article, body > main,',
    'body > div:not(.readflex-wide-table), li, dd, dt, figcaption, th, td {',
    '  direction: ' + direction + ' !important;',
    '  unicode-bidi: plaintext;',
    '  text-align: var(--readflex-rtl-article-text-align, right) !important;',
    '}',
  ].join('\n')
  doc.head?.append(style)
}

export const normalizeDocumentLanguageAndDirection = (doc, { language = {}, sourceType = '' } = {}) => {
  doc.documentElement.lang ||= language.canonical ?? ''
  if (language.isCJK) return

  const direction = language.direction || inferDocumentDirection(doc)
  if (direction === 'rtl' && sourceType === 'article') {
    applyArticleTextDirection(doc, direction)
  } else {
    doc.documentElement.dir ||= direction
    if (doc.body) doc.body.dir ||= direction
  }
}

export const wrapWideTables = doc => {
  for (const table of doc.querySelectorAll('table')) {
    if (table.closest('.readflex-wide-table')) continue
    const wrapper = doc.createElement('div')
    wrapper.className = 'readflex-wide-table'
    table.before(wrapper)
    wrapper.append(table)
  }
}

export const markInlineImages = doc => {
  for (const img of doc.querySelectorAll('img')) {
    const parent = img.parentNode
    if (!parent || parent.nodeType !== ELEMENT_NODE) continue

    const siblings = Array.from(parent.childNodes ?? [])
    const hasTextSiblings = siblings.some(
      node => node.nodeType === TEXT_NODE && node.textContent?.trim()
    )
    const hasBlockBreak = siblings.some(
      node => node.nodeType === ELEMENT_NODE && node.tagName?.toUpperCase() === 'BR'
    )

    if (hasTextSiblings && !hasBlockBreak) {
      img.classList.add('has-text-siblings')
    }
  }
}

const hasCodeLikeClass = element => {
  const classAndId = `${element.className || ''} ${element.id || ''}`
  if (CODE_BLOCK_CLASS_PATTERN.test(classAndId)) return true

  return classAndId
    .split(/\s+/)
    .filter(Boolean)
    .some(token =>
      CODE_CLASS_FRAGMENT_PATTERN.test(token)
      && !NON_CODE_CLASS_FRAGMENT_PATTERN.test(token)
    )
}

export const normalizeCodeLikeBlocks = doc => {
  const win = doc.defaultView
  if (!win) return

  const candidates = doc.querySelectorAll('div, p, section, article, li')
  for (const element of candidates) {
    if (element.closest('pre, .readflex-code-block')) continue

    const text = element.textContent?.trim() ?? ''
    if (text.length < CODE_BLOCK_MIN_TEXT_LENGTH) continue

    const style = win.getComputedStyle(element)
    const isBlockish = /block|flow-root|list-item|table/.test(style.display)
    if (!isBlockish) continue

    const hasCodeClass = hasCodeLikeClass(element)
    const hasMonospaceFont = MONOSPACE_FONT_PATTERN.test(style.fontFamily)
    const preservesWhitespace = /pre|nowrap/.test(style.whiteSpace)

    if (hasCodeClass || (hasMonospaceFont && (preservesWhitespace || CODE_TEXT_PATTERN.test(text)))) {
      element.classList.add('readflex-code-block')
    }
  }
}

export const normalizeLoadedDocument = doc => {
  wrapWideTables(doc)
  markInlineImages(doc)
  normalizeCodeLikeBlocks(doc)
}
