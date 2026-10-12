# dictionary

Reader `TextAction` and bottom sheet for monolingual word definitions.

The action first asks `SystemDictionaryService` to present the native iOS or
Android definition UI. If the platform cannot present a definition handler,
the action opens the Readflex sheet backed by `DictionaryLookupService`.

`Define` is deliberately separate from `Translate`: definitions stay in the
language of the selected term. The remote service sends the selected term and
its sentence context to the Readflex Dictionary API. That backend calls
DeepSeek, validates its structured response, and caches valid definitions;
the mobile app never calls DeepSeek or contains its provider key.

Readflex keeps the selected term's canonical lemma as the first entry. When
the marked sentence context contains a reliable lexicalized expression, the
backend may append it as a second monolingual entry. For example, selecting
`shutting` in `shutting off` shows the `shut` headword, then `shut off` under
**In this context**, then the definitions of `shut` under **Word meaning**. The
expression supplements the selected word and never replaces it. A `found`
result without entries reads as not found.

## Architecture

- `DictionaryAction` owns system-first orchestration and opens the sheet only
  when native UI is unavailable.
- `DictionarySheet` creates `DictionaryCubit` from the injected service.
- The private sheet View reads only Cubit state and invokes UI callbacks.
- `DictionaryCubit` maps backend statuses and typed failures to explicit UI
  states; it does not depend on platform or HTTP implementations.

Each lexical entry has one Copy command beside its lemma. It copies that lemma
and its numbered definitions, without another lookup. `DictionarySheet`
supplies the clipboard callback; the shared `AppCopyButton` owns only temporary
success/error feedback. Both the primary word and a contextual expression can
be copied independently. Native system dictionary presentation is unchanged.
`AppSheetActionRow` puts each Copy glyph on the 24dp content edge, centered on
its lemma's line, while preserving a 48dp target that reaches its section's
outline. Copy trails the lemma in the
lemma's own direction: beside Close for an English entry in an English
interface, on the opposite gutter in an Arabic one, as in Translation.
`AppCopyButton` shares circular press/focus feedback with other standalone
utility actions.

## Presentation

The resolved term appears once as a selectable serif `headlineSmall` headword,
the subject of the sheet, without a selection preview card. If the selected form differs from the canonical lemma, the
heading preserves the connection (for example, `shutting -> shut`). Long forms
wrap within the available width instead of truncating. Reading, IPA and part
of speech sit right below it in the shared `AppLexicalMetadataRow`, starting
on the headword's edge in either interface direction: IPA stays left-to-right
in the phonetic font and the backend's part-of-speech tag is shown as sent,
because definitions are monolingual and there is no dictionary POS catalog. At
a large text size a headword too wide for one word shrinks just enough to stay
whole (`appFitSelectableText`), never below metadata size. Definitions are
`bodyLarge` with a localized number (`dictionaryDefinitionNumber`) on the
definition's baseline, in a tabular-figure column that scales with the user's
text size; examples stay muted `bodyMedium` and share the definition's text
column, so both start on the same edge in LTR and RTL. Definitions are
separated by 12dp with no trailing padding after the last one, so a successful
result ends 16dp above the sheet inset like the other states.

The order and the sections match Translation. The headword and its metadata
lead, outside the sections. Each part below is its own outlined
`AppSheetSection`, 12dp apart: the contextual expression as a regular-weight
`titleMedium` entry titled **In this context**, then the word's own definitions
titled **Word meaning** (`dictionaryWordMeaning`; untitled when there is no
contextual entry), then any further entries, each in its own section. Every
entry keeps its definitions in order and its own Copy. Titles sit 12dp inside
the outline and 8dp above their content, and the last definition ends 12dp
above the outline, at any text size; there are no dividers.

While loading and in every non-success state the selected phrase is quoted
with the shared `AppSourceQuote`, whose rule follows the phrase's own writing
direction. Loading uses `CenteredCircularProgressIndicator` inside the same
24dp vertical padding; not-found, unsupported-language and failure states use
`AppStatusMessage`, with Retry as its filled action.

`ActionBottomSheetLayout.scrollable` supplies the same title/Close, gutters and
bounded body as Translation, Display and Appearance. Full-width top/bottom fades
remain outside the content's horizontal padding. Short entries fit
their content; long results, landscape screens and large system text remain
scrollable. `intl` bidi detection gives lexical content its own writing direction,
independent of the interface locale. Clipboard feedback and scrolling do not
perform lookups. Loading and failure states retain the original selected text
as a quote without introducing a duplicate success preview.

## Verification

Package tests cover de-duplication, canonical forms, contextual expressions,
independent copies, RTL content, and 200% text in all ten interface locales.
Layout tests (`dictionary_sheet_layout_test.dart`) check the entry order and
section titles, the outlined sections
(one untitled section for a single entry), spacing at 1x and 2x, Copy on each
lemma line reaching its outline and its side in an Arabic interface,
baseline-aligned numbers, and long lemmas that shrink instead of breaking.
Root goldens include definitions, contextual expressions and not-found states
in five visual profiles. Native reader scenarios verify both copies, the exact
lookup term and the same WebView after dismissing the sheet. These use fixture
services and do not contact live providers or measure release-mode FPS.
