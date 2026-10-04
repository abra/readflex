// length for context in excerpts
const CONTEXT_LENGTH = 50

const normalizeWhitespace = str => str.replace(/\s+/g, ' ')

const contextExcerpt = (text, offset, before) => {
    // Read just enough context; normalizing a whole text node per hit is quadratic.
    let length = CONTEXT_LENGTH
    while (true) {
        const fragment = before ? text.slice(Math.max(0, offset - length), offset)
            : text.slice(offset, offset + length)
        const normalized = normalizeWhitespace(fragment)
        const trimmed = before ? normalized.trimStart() : normalized.trimEnd()
        if (trimmed.length >= CONTEXT_LENGTH)
            return before ? `…${trimmed.slice(-CONTEXT_LENGTH)}`
                : `${trimmed.slice(0, CONTEXT_LENGTH)}…`
        if (before ? length >= offset : offset + length >= text.length) return trimmed
        length *= 2
    }
}

const makeExcerpt = (strs, { startIndex, startOffset, endIndex, endOffset }) => {
    const start = strs[startIndex]
    const end = strs[endIndex]
    const match = startIndex === endIndex
        ? start.slice(startOffset, endOffset)
        : start.slice(startOffset)
            + strs.slice(startIndex + 1, endIndex).join('')
            + end.slice(0, endOffset)
    const pre = contextExcerpt(start, startOffset, true)
    const post = contextExcerpt(end, endOffset, false)
    return { pre, match, post }
}

// Store only length-changing spans, not two offset arrays for every character.
// ASCII runs avoid per-character normalization in mostly Latin chapters.
const normalizeSearchText = (text, { locales, matchCase, matchDiacritics }) => {
    const edits = []
    const lower = value => matchCase ? value
        : value.toLocaleLowerCase(locales).replace(/\u03c2/g, '\u03c3')
    if (!/[^\x00-\x7f]/.test(text)) return { text: lower(text), edits }
    // Repeated non-ASCII letters should not each invoke locale/Unicode tables.
    // Bound both entries and key size; keep this cache local to one search text.
    const normalizedSpans = new Map()
    let delta = 0
    const normalized = text.replace(
        /[\x00-\x7f]+(?!\p{M})|\P{M}\p{M}*|\p{M}+/gu,
        (span, offset) => {
            let value = normalizedSpans.get(span)
            if (value === undefined) {
                value = lower(span).normalize(matchDiacritics ? 'NFC' : 'NFD')
                if (!matchDiacritics) value = value.replace(/\p{M}/gu, '')
                if (span.length <= 8 && normalizedSpans.size < 256)
                    normalizedSpans.set(span, value)
            }
            if (value.length !== span.length) {
                const start = offset + delta
                delta += value.length - span.length
                edits.push({ start, end: start + value.length,
                    originalStart: offset, originalEnd: offset + span.length, delta })
            }
            return value
        })
    return { text: normalized, edits }
}

const originalOffsetMapper = (edits, endBoundary) => {
    let cursor = 0
    return offset => {
        while (cursor < edits.length && (endBoundary
            ? edits[cursor].end < offset : edits[cursor].end <= offset)) cursor++
        const edit = edits[cursor]
        if (edit && (endBoundary ? edit.start < offset : edit.start <= offset))
            return endBoundary ? edit.originalEnd : edit.originalStart
        return offset - (edits[cursor - 1]?.delta ?? 0)
    }
}

const simpleSearch = function* (strs, query, options = {}) {
    if (!query || !strs.length) return
    const { sensitivity = 'base' } = options
    let locales
    try { locales = Intl.getCanonicalLocales(options.locales ?? 'en') }
    catch { locales = ['en'] }
    const normalization = {
        locales,
        matchCase: sensitivity === 'variant' || sensitivity === 'case',
        matchDiacritics: sensitivity === 'variant' || sensitivity === 'accent',
    }
    const haystack = normalizeSearchText(strs.join(''), normalization)
    const needle = normalizeSearchText(query, normalization).text
    if (!needle) return
    const originalStart = originalOffsetMapper(haystack.edits, false)
    const originalEnd = originalOffsetMapper(haystack.edits, true)
    const needleLength = needle.length
    let index = -1
    // Separate forward-only cursors also support overlapping matches.
    let startIndex = -1, endIndex = -1
    let startSum = 0, endSum = 0
    do {
        index = haystack.text.indexOf(needle, index + 1)
        if (index > -1) {
            if (normalization.matchDiacritics && /^\p{M}/u.test(
                haystack.text.slice(index + needleLength, index + needleLength + 2))) continue
            const start = originalStart(index)
            const end = originalEnd(index + needleLength)
            while (startSum <= start) startSum += strs[++startIndex].length
            const startOffset = start - (startSum - strs[startIndex].length)
            while (endSum < end) endSum += strs[++endIndex].length
            const endOffset = end - (endSum - strs[endIndex].length)
            const range = { startIndex, startOffset, endIndex, endOffset }
            yield { range, excerpt: makeExcerpt(strs, range) }
        }
    } while (index > -1)
}

const segmenterSearch = function* (strs, query, options = {}) {
    if (!query || !strs.length) return
    const { locales = 'en', granularity = 'word', sensitivity = 'base' } = options
    let segmenter, collator
    try {
        segmenter = new Intl.Segmenter(locales, { usage: 'search', granularity })
        collator = new Intl.Collator(locales, { sensitivity })
    } catch (e) {
        console.warn(e)
        segmenter = new Intl.Segmenter('en', { usage: 'search', granularity })
        collator = new Intl.Collator('en', { sensitivity })
    }
    const queryLength = Array.from(segmenter.segment(query)).length

    const substrArr = []
    let strIndex = 0
    let segments = segmenter.segment(strs[strIndex])[Symbol.iterator]()
    main: while (strIndex < strs.length) {
        while (substrArr.length < queryLength) {
            const { done, value } = segments.next()
            if (done) {
                // the current string is exhausted
                // move on to the next string
                strIndex++
                if (strIndex < strs.length) {
                    segments = segmenter.segment(strs[strIndex])[Symbol.iterator]()
                    continue
                } else break main
            }
            const { index, segment } = value
            // ignore formatting characters
            if (!/[^\p{Format}]/u.test(segment)) continue
            // normalize whitespace
            if (/\s/u.test(segment)) {
                if (!/\s/u.test(substrArr[substrArr.length - 1]?.segment))
                    substrArr.push({ strIndex, index, segment: ' ' })
                continue
            }
            value.strIndex = strIndex
            substrArr.push(value)
        }
        const substr = substrArr.map(x => x.segment).join('')
        if (collator.compare(query, substr) === 0) {
            const endIndex = strIndex
            const lastSeg = substrArr[substrArr.length - 1]
            const endOffset = lastSeg.index + lastSeg.segment.length
            const startIndex = substrArr[0].strIndex
            const startOffset = substrArr[0].index
            const range = { startIndex, startOffset, endIndex, endOffset }
            yield { range, excerpt: makeExcerpt(strs, range) }
        }
        substrArr.shift()
    }
}

export const search = (strs, query, options = {}) => {
    const { granularity = 'grapheme', sensitivity = 'base' } = options
    // Full-book search runs on the UI WebView process. Android WebView's
    // Intl.Segmenter can be extremely slow on long sections, so keep the
    // common substring path on simple indexOf-based search and reserve
    // segmentation for whole-word matching.
    if (granularity !== 'word'
        || typeof Intl === 'undefined'
        || !Intl.Segmenter
        || granularity === 'grapheme'
        && (sensitivity === 'variant' || sensitivity === 'accent'))
        return simpleSearch(strs, query, options)
    return segmenterSearch(strs, query, options)
}

export const searchMatcher = (textWalker, opts) => {
    const { defaultLocale, matchCase, matchDiacritics, matchWholeWords } = opts
    return function* (doc, query) {
        const iter = textWalker(doc, function* (strs, makeRange) {
            for (const result of search(strs, query, {
                locales: doc.body.lang || doc.documentElement.lang || defaultLocale || 'en',
                granularity: matchWholeWords ? 'word' : 'grapheme',
                sensitivity: matchDiacritics && matchCase ? 'variant'
                : matchDiacritics && !matchCase ? 'accent'
                : !matchDiacritics && matchCase ? 'case'
                : 'base',
            })) {
                const { startIndex, startOffset, endIndex, endOffset } = result.range
                result.range = makeRange(startIndex, startOffset, endIndex, endOffset)
                yield result
            }
        })
        for (const result of iter) yield result
    }
}
