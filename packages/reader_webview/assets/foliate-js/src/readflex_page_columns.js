// Column layout of paginated reflowable pages. Pure functions; lengths are
// CSS pixels along the page's inline axis.
//
// Foliate lays a page out as `columns` CSS columns of `columnWidth`, `gap`
// apart, with `gap / 2` outside the first and last one, so
// `columns * (columnWidth + gap) === size`. A reader measure (the
// `max-inline-size` attribute) caps the column width; the margins and the
// spread's gutter absorb the rest, which keeps that identity and every page
// offset intact.

// Least share of the measure each page of an Auto spread keeps: about 40
// characters at the 32em measure Readflex sets. Narrower pages, from a short
// window or large text, show one column instead.
export const AUTO_SPREAD_MIN_MEASURE = 0.625

// Columns upstream foliate shows when no measure is set: one per
// `maxInlineSize`, at most two.
const upstreamColumns = (size, maxInlineSize) =>
    Math.min(2, Math.ceil(size / maxInlineSize))

// The narrowest gap that keeps each outer margin clear of a `safeInset`
// (a display cutout beside a landscape page). Margins and the spread's gutter
// share one gap, so both widen together.
const minimumGap = (gap, safeInset) => Math.max(gap, 2 * (safeInset || 0))

// Columns for `maxColumnCount` (0 = automatic). With a `measure`, Auto shows
// a spread only in a `landscape` window whose two columns each keep most of
// it. Orientation is the window's, not the page's: the keyboard shortens the
// page but never the window, so searching, even across a rotation, does not
// turn a portrait page into a spread.
export const pageColumnCount = ({
    landscape, size, gap, maxColumnCount, maxInlineSize, measure = null,
    safeInset = 0,
}) => {
    if (maxColumnCount > 0) return maxColumnCount
    if (!measure) return upstreamColumns(size, maxInlineSize)
    const pageGap = minimumGap(gap, safeInset)
    return landscape && size / 2 - pageGap >= measure * AUTO_SPREAD_MIN_MEASURE
        ? 2
        : 1
}

// The page's columns, the gap between them (twice the outer margin) and the
// column width. Without a `measure` the columns fill the page.
export const pageColumnLayout = ({
    landscape, size, gap, maxColumnCount, maxInlineSize, measure = null,
    safeInset = 0,
}) => {
    const columns = pageColumnCount({
        landscape, size, gap, maxColumnCount, maxInlineSize, measure, safeInset,
    })
    const pageGap = minimumGap(gap, safeInset)
    const columnGap = measure
        ? Math.max(pageGap, size / columns - measure)
        : pageGap
    return { columns, gap: columnGap, columnWidth: size / columns - columnGap }
}
