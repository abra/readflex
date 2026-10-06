// Presentation constants shared by the book shell (book.js/view.js) and the
// article shell (article-html/index.html). Keep both readers visually aligned
// by changing values here, never in one shell only.

// Saved-highlight fallbacks when Flutter sends no explicit value.
export const READFLEX_HIGHLIGHT_OPACITY = 0.62
export const READFLEX_HIGHLIGHT_RADIUS = 3
export const READFLEX_HIGHLIGHT_VERTICAL_INSET = 1.5
export const READFLEX_SELECTION_PREVIEW_HIGHLIGHT_OPACITY = 0.5

// Search tints: every match gets the soft cyan fill, the active one amber.
export const SEARCH_HIGHLIGHT_COLOR = '#00d4d8'
export const SEARCH_HIGHLIGHT_OPACITY = 0.16
export const ACTIVE_SEARCH_HIGHLIGHT_COLOR = '#ffb300'
export const ACTIVE_SEARCH_HIGHLIGHT_OPACITY = 0.36
export const SEARCH_HIGHLIGHT_PADDING = 1
export const SEARCH_HIGHLIGHT_RADIUS = 3

// Flutter overrides search tints through `FoliateStyle.customCSS` by
// redefining these custom properties on `:root`; both shells read them.
export const SEARCH_MATCH_COLOR_VAR = '--rf-search-match-color'
export const SEARCH_MATCH_OPACITY_VAR = '--rf-search-match-opacity'
export const SEARCH_ACTIVE_COLOR_VAR = '--rf-search-active-color'
export const SEARCH_ACTIVE_OPACITY_VAR = '--rf-search-active-opacity'

export const searchHighlightDefaults = active => active
    ? { color: ACTIVE_SEARCH_HIGHLIGHT_COLOR, opacity: ACTIVE_SEARCH_HIGHLIGHT_OPACITY }
    : { color: SEARCH_HIGHLIGHT_COLOR, opacity: SEARCH_HIGHLIGHT_OPACITY }

export const searchHighlightVars = active => active
    ? { color: SEARCH_ACTIVE_COLOR_VAR, opacity: SEARCH_ACTIVE_OPACITY_VAR }
    : { color: SEARCH_MATCH_COLOR_VAR, opacity: SEARCH_MATCH_OPACITY_VAR }

// CSS `var()` references with the shared defaults as fallback values.
export const searchHighlightFill = active => {
    const vars = searchHighlightVars(active)
    const defaults = searchHighlightDefaults(active)
    return {
        color: `var(${vars.color}, ${defaults.color})`,
        opacity: `var(${vars.opacity}, ${defaults.opacity})`,
    }
}

export const searchHighlightRootCSS = () => `:root {
  ${SEARCH_MATCH_COLOR_VAR}: ${SEARCH_HIGHLIGHT_COLOR};
  ${SEARCH_MATCH_OPACITY_VAR}: ${SEARCH_HIGHLIGHT_OPACITY};
  ${SEARCH_ACTIVE_COLOR_VAR}: ${ACTIVE_SEARCH_HIGHLIGHT_COLOR};
  ${SEARCH_ACTIVE_OPACITY_VAR}: ${ACTIVE_SEARCH_HIGHLIGHT_OPACITY};
}`

// Taps that arrive right after a selection change are the gesture that ended
// the selection, not a chrome toggle. Both shells wait the same interval.
export const READFLEX_SELECTION_CLICK_SUPPRESS_MS = 200
