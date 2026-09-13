// Compare DOM boundaries, not painted rectangles: adjacent or partly
// intersecting highlights must not be replaced when saving a selection.
export const rangeContainsRange = (outer, inner) => {
    if (!outer || !inner || outer.collapsed || inner.collapsed) return false
    try {
        return outer.compareBoundaryPoints(Range.START_TO_START, inner) <= 0
            && outer.compareBoundaryPoints(Range.END_TO_END, inner) >= 0
    } catch {
        return false
    }
}
