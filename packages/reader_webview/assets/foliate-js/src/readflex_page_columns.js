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

// Columns for `maxColumnCount` (0 = automatic). With a `measure`, Auto shows
// a spread only on a landscape page whose two columns each keep most of it.
// `previous` is the last Auto decision: a change of height alone, such as the
// keyboard opening over the page, keeps it, so the page does not turn into a
// spread while the reader searches. Rotation and window resizes change the
// width and decide again.
export const pageColumnCount = ({
    width, height, size, gap, maxColumnCount, maxInlineSize, measure = null,
    previous = null,
}) => {
    if (maxColumnCount > 0) return maxColumnCount
    if (!measure) return upstreamColumns(size, maxInlineSize)
    if (previous && previous.width === width && previous.measure === measure
        && previous.gap === gap) return previous.columns
    return width > height && size / 2 - gap >= measure * AUTO_SPREAD_MIN_MEASURE
        ? 2
        : 1
}

// The page's columns, the gap between them (twice the outer margin) and the
// column width. Without a `measure` the columns fill the page. `auto` is the
// decision to pass back as `previous` next time, or `null` outside Auto.
export const pageColumnLayout = ({
    width, height, size, gap, maxColumnCount, maxInlineSize, measure = null,
    previous = null,
}) => {
    const columns = pageColumnCount({
        width, height, size, gap, maxColumnCount, maxInlineSize, measure, previous,
    })
    const columnGap = measure ? Math.max(gap, size / columns - measure) : gap
    const auto = maxColumnCount > 0 || !measure ? null : { width, measure, gap, columns }
    return { columns, gap: columnGap, columnWidth: size / columns - columnGap, auto }
}
