const wordCharRegex = /[\p{L}\p{N}\p{M}]/u
const joinerRegex = /['’-]/u

const isWordChar = char => !!char && wordCharRegex.test(char)

const isJoinerChar = char => !!char && joinerRegex.test(char)

const charAt = (text, index) => (
  index >= 0 && index < text.length ? text[index] : ''
)

const isTokenCharAt = (text, index) => {
  const char = charAt(text, index)
  if (isWordChar(char)) return true
  if (!isJoinerChar(char)) return false
  return isWordChar(charAt(text, index - 1))
    && isWordChar(charAt(text, index + 1))
}

const clampOffset = (text, offset) =>
  Math.max(0, Math.min(text.length, Number.isFinite(offset) ? offset : 0))

const shouldExpandStart = (text, offset) =>
  offset > 0 && isTokenCharAt(text, offset - 1) && isTokenCharAt(text, offset)

const shouldExpandEnd = (text, offset) =>
  offset > 0
  && offset < text.length
  && isTokenCharAt(text, offset - 1)
  && isTokenCharAt(text, offset)

const selectionKindFor = (selectedText, normalizedText, changed) => {
  if (!changed) return 'exact'
  return /\s/.test(selectedText.trim()) || /\s/.test(normalizedText.trim())
    ? 'partial_span'
    : 'partial_word'
}

export const normalizeTextRange = (text, startOffset, endOffset) => {
  const value = typeof text === 'string' ? text : ''
  const start = clampOffset(value, startOffset)
  const end = Math.max(start, clampOffset(value, endOffset))
  let normalizedStart = start
  let normalizedEnd = end

  if (shouldExpandStart(value, start)) {
    while (normalizedStart > 0 && isTokenCharAt(value, normalizedStart - 1)) {
      normalizedStart -= 1
    }
  }

  if (shouldExpandEnd(value, end)) {
    while (
      normalizedEnd < value.length
      && isTokenCharAt(value, normalizedEnd)
    ) {
      normalizedEnd += 1
    }
  }

  const selectedText = value.slice(start, end)
  const normalizedText = value.slice(normalizedStart, normalizedEnd)
  const changed = normalizedStart !== start || normalizedEnd !== end

  return {
    start,
    end,
    selectedText,
    normalizedStart,
    normalizedEnd,
    normalizedText,
    selectionKind: selectionKindFor(selectedText, normalizedText, changed),
  }
}

const isTextNode = node =>
  typeof Node !== 'undefined' && node?.nodeType === Node.TEXT_NODE

export const normalizeSelectionRange = range => {
  if (!range || range.collapsed) return null

  const normalizedRange = range.cloneRange()
  let selectionKind = 'exact'

  if (isTextNode(range.startContainer)) {
    const start = normalizeTextRange(
      range.startContainer.textContent ?? '',
      range.startOffset,
      range.startOffset
    ).normalizedStart
    if (start !== range.startOffset) {
      normalizedRange.setStart(range.startContainer, start)
      selectionKind = 'partial_word'
    }
  }

  if (isTextNode(range.endContainer)) {
    const end = normalizeTextRange(
      range.endContainer.textContent ?? '',
      range.endOffset,
      range.endOffset
    ).normalizedEnd
    if (end !== range.endOffset) {
      normalizedRange.setEnd(range.endContainer, end)
      selectionKind = 'partial_word'
    }
  }

  const selectedText = range.toString()
  const normalizedText = normalizedRange.toString()
  if (selectionKind !== 'exact' && /\s/.test(selectedText.trim())) {
    selectionKind = 'partial_span'
  }

  return {
    range: normalizedRange,
    selectedText,
    normalizedText,
    selectionKind,
  }
}
