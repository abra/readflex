# translate

Reader text action and bottom sheet for contextual translation.

The feature implements `TranslateAction` from the shared reader text-action
contract. It owns only UI and sheet state: request building, language selectors,
loading/error states, and target-language preference updates.

## Public API

| Symbol | Purpose |
|--------|---------|
| `TranslateAction` | Reader context-panel action wired by `routing.dart`; optional `onDefine` opens the definition of the same selection; optional `dictionaryRepository` enables Save in the word header, which keeps the word for review (`AppSaveToggleButton`, toast "Saved for review" on save only, quiet on remove) |
| `showTranslateSheet` | Opens the translation sheet for a `TextSelectionContext`; completes with `TranslateSheetOutcome.define` when the reader asked for the definition |
| `TranslateSheetOutcome` | How the sheet closed when it asks the opening action for a follow-up |

## Architecture

```text
routing.dart
  -> TranslateAction(...)
    -> showTranslateSheet(...)
      -> TranslateCubit
        -> ContextualTranslationService
        -> PreferencesService
```

The sheet does not create HTTP clients, ML Kit translators, or repositories.
Those are composed in the root app and passed through the action.

### Text already in the target language

Translating text into its own language means nothing; a reader who picks
English for English text wants what the word means. `TranslateCubit` keeps
the provider's detected language (`TranslateSheetState.detectedSourceLanguage`)
across target changes, so the direction label holds it and a source or target
equal to the known source language emits `TranslateSheetStatus.sameLanguage`
without a request (a running request is cancelled; the target is still saved
as the default). A provider `sameLanguage` answer, such as the first request
with an automatic source, ends in the same state. Codes compare with
`isSameTranslationLanguage`.

The state is a shared `AppStatusMessage`, "Nothing to translate", naming the
language as the menu shows it. For a word or phrase (`contextual_lookup`) with
a definition available, its button is Define: the sheet closes with
`TranslateSheetOutcome.define` and `TranslateAction` runs `onDefine` with its
own caller context, which outlives the sheet. `routing.dart` passes the reader's
`DictionaryAction.onExecute`, so this package never imports the dictionary
feature. Longer text, or no `onDefine`, gets Select language, which opens the
target menu.
Language selection remains an anchored menu in the fixed direction header,
not another bottom sheet. Ten autonyms use two columns only when measured text
and checkmark slots fit. Larger text falls back to a bounded scrollable list;
targets remain at least 48dp. Auto is a separate full-width source-only option.
Selection closes the menu and retains the existing translation request contract.
Menu layout does not change the result's scroll offset or issue extra lookups.
Request construction rejects a stale normalized single-word snapshot when the
exact selection has already been expanded to multiple words.

Short words and expressions use `contextual_lookup` so the backend can resolve
their meaning inside the surrounding sentence. Complete sentences, paragraphs,
and long selections use `text_translation`; in that mode the complete selected
range is the translation target and lexical analysis fields are not rendered.
For contextual lookup, the sheet shows the selected fragment and its translation
first. The selection, word or phrase, is a quiet selectable `titleMedium` label,
not a heading: the translation is the sheet's only large text. Optional
reading/pronunciation follows the word on its line in the shared
`AppLexicalMetadataRow`; a localized part of speech and a different lemma as
**Base form** follow on the line below, without expanding details. On one line
they are joined by ` · `, like metadata elsewhere in the app; when they do not
fit, the base form moves below the part of speech without the dot. The base
form is one localized phrase (`translationBaseForm`, e.g. `Base form: {lemma}`)
in the interface direction, with the lemma isolated in its own direction, so
the label always precedes the lemma and the phrase wraps between words.
Pronunciation describes the selected
surface form, not its lemma: mismatched or absent `analysis.surface_form` hides
pronunciation/reading and part of speech. Unknown grammatical tags are omitted.
Reading is language-aware (e.g. Japanese kana or Chinese pinyin); identical
reading/pronunciation is not repeated. Both lines follow the source word's
writing direction, independently of the UI locale, so they start on the word's
edge; IPA always stays left-to-right in the bundled phonetic font subset.
For a single-word selection, **In this context** comes first when the contextual
answer differs from the general meaning or describes a larger expression. When
the backend returns a grounded `contextual_expression`, this section names the
exact source excerpt (e.g. `rather than` for selected `rather`), followed by its
translation. The selected word's general translation follows under **Word meaning**.
The source sentence and sentence translation follow in a separate **Sentence** section.
Neither word nor contextual answers are hidden in the details disclosure; each
has an independent Copy command. An expression-level answer is never relabeled
as the word's independent meaning. All data comes from one response; there is no
second lookup or client-side phrase detection.
If the general translation is missing, the available contextual answer remains
visible; it is not reused as an independent word meaning when a larger
expression is present. The client never invents a dictionary meaning. Equal answers for
the same selected span appear once. Comparison ignores case and whitespace,
but not punctuation or diacritics. Equal translations of a word and a larger
expression keep their separate source scopes. Offline and legacy responses
without expression metadata retain the word-answer presentation.
Phrase and full-text selections are never expanded by this field.
Single-word detection follows the existing lexical presentation
rule (contextual mode and no whitespace), but a backend-classified phrase,
expression, idiom or phrasal verb is not a word even in a script without spaces.
If token IDs identify one selected token within a larger expression, the
selection retains word presentation and its pronunciation. An expression-level
tag alone must not hide the pronunciation of that selected word.
There is no extra tokenizer or Dictionary API request.
Below the result, the source sentence is paired with its translation under a
**Sentence** caption.
Book context is sentence-bounded at the
DOM-range extraction layer, not trimmed or re-segmented in the sheet; unrelated
sentences and clipped character-window prefixes are not part of that context.
The selected range from the reader's
marked-context contract is semibold in the body color without a background
fill. Long context cannot push the answer
below the initial viewport. Text-translation mode shows one complete translation
followed by the exact selected source under Original, without lexical sections.

### Layout

The selection sits on top as a label; below it every part of the result is its
own outlined `AppSheetSection`, 12dp apart, so it is clear what is where:

1. the answer, titled **In this context** when there is a contextual section,
   with the contextual expression right above it;
2. **Word meaning**, the selected word's general translation;
3. **Sentence** (or **Original** for text translation), the source muted above
   its translation;
4. **Meaning & alternatives**, the collapsed details tile, its title styled as
   a section title and without a border of its own.

The sheet has one heading: the translation of the selected word or phrase in
its sentence. A contextual answer, with or without a
larger expression, uses serif `headlineSmall` when it has at most 48 graphemes
and fits two lines at the user's text scale; the length cap also applies on
wide screens. Longer answers, text translations and the standalone word
meaning keep `bodyLarge` with zero letter spacing. Contextual expressions use
regular-weight `titleMedium`, so the bold section title stays the bold line.

Every source sits above its translation in the same way: the sentence above
the sentence translation, the original below a text translation as muted
`bodyMedium` (`onSurfaceVariant`, at least 4.5:1) with the translation in the
body color. Sources start on the same 24dp gutter as everything else;
successful results quote nothing. The quote bar (`AppSourceQuote`) is kept for
the phrase shown while loading and in failure states, which have no sections.

Inside a section, titles sit 12dp below the outline and 8dp above their
content, the expression 4dp above its answer, and text ends 12dp above the
outline at any text size. A section title above an answer is the answer row's
lead, so Copy stays centered on the answer. A word too wide for its line at a
large text size shrinks just enough to stay whole (`appFitSelectableText`),
never below metadata size. The sheet's internal widgets (selection label,
sentence preview, grammar line, details, answer styles) are private parts of
`translate_sheet.dart`. The sheet body has a bounded,
scrollable viewport so long contexts and lexical results do not overflow.
The shared `ScrollEdgeFadeStack` adds full-width shadows when content extends
beyond the viewport: below the fixed title and language controls after scrolling,
and at the bottom when more content remains below. Expanding details updates the bottom shadow
without requiring a scroll gesture. Reaching either edge hides its shadow;
content that fits needs neither. The overlays ignore pointer input and do not
update translation state or request the service.

While loading and in failure states the selected phrase is shown with the
shared `AppSourceQuote`: a 2px leading rule with a 12px inner inset and no
background fill, quote text in `onSurface`. The rule follows the source text
direction, so Arabic quotes use the right edge even in an English interface.
Only optional explanation and alternatives are collapsed by default
under **Meaning & alternatives**. Expanding them is local widget state: it
neither sends a request nor rebuilds the Reader WebView. A new result resets
the expansion. Source context and sentence translation stay outside this fold.
A lemma equal to the already visible selection is omitted from the header.

Loading uses `CenteredCircularProgressIndicator` inside 24dp vertical padding
under the quoted phrase. Source-required, offline-model, download-in-progress
(`busy`) and failure states use `AppStatusMessage`; an offline-model prompt
whose language codes are unknown names them with `translationUnknownLanguage`.
An unknown offline source language offers **Select language**, which opens the
source picker without repeating the invalid request. The menu controller is
local View state; choosing a language still goes through `TranslateCubit`.
The details disclosure animates with `AppMotion.short` through
`context.motion`, so it settles immediately under reduced motion.
`ActionBottomSheetLayout.scrollable` supplies the shared header, gutters, bounded
viewport and full-width fades. Its `headerBottom` slot keeps language direction
fixed below the Translation title; only the result,
context and details scroll. The controls remain reachable after scrolling to the
end of a long result, including when they stack on narrow/large-text screens.
Opening a source-language recovery menu does not move the result viewport.
The two language menus size to their labels, retain 48px minimum tap targets and
adapt to system text scaling. They are `TextButton`s on the shared text-button
theme (shape, foreground and transparent background come from the theme, so
labels keep at least 4.5:1 contrast); only the compact `bodySmall` label style,
height and 2dp ink inset are picker-specific. The source picker drops its
leading inset and start-aligns its content so the label starts on the 24dp
content edge with the title; the target picker keeps symmetric ink. They show
source, direction arrow and target;
there is no duplicate direction caption or visible From/To label. Those roles
remain available to assistive technologies. Controls stack with a downward
arrow when the labels cannot fit side by side. The horizontal arrow and control
order follow the UI writing direction. Menus are disabled while a request runs.
An automatically detected language is shown compactly as **English**, for example.
Its accessibility value still includes the localized auto-detection prefix, and
Auto remains selected in the menu. Neither preference nor request changes from
`auto`. The sheet has an explicit close action and a taller result viewport for
large text; no backend or reader remount is needed for these layout changes.

Action, sheet, recovery and detail labels use the shared ARB catalog in all ten
supported locales. Language names retain the application's existing autonyms.
Source, translation and lexical content derive their own writing direction via
`intl` bidi detection, independent of the UI locale. The reader action uses the
shared translation icon; the globe remains available for other language UI.

The primary result has a Copy command. `TranslateSheet` supplies the clipboard
callback; the View never accesses a service for copying. Success/error feedback
is local to `AppCopyButton` and does not trigger another translation or rebuild
the Reader WebView. The full source context and sentence translation remain
visible in the existing scrollable body.
Answer rows use `AppSheetActionRow`: the Copy glyph follows the header's 24dp
content edge, with a 48dp tap target reaching the section outline, centered on
the answer's first line. The section title and expression above an answer are
the row's lead, so Copy moves down to the answer instead of pushing it down;
titles keep the interface's edge while LTR answers keep Copy trailing them in
an RTL interface. Copy feedback uses the same circular control as Close, without moving
the pinned language row.

## Verification

`flutter test` covers request construction, exact selection preservation,
pronunciation/reading compatibility, inflected forms, mismatched surface forms,
unknown grammatical tags, Japanese/Chinese words and non-spaced phrases,
immediately visible word/expression scopes and independent copying,
`rather` with and without a larger expression, duplicate/missing-value fallback,
unchanged multi-word behavior, and expanded details at 200% text in all ten locales,
fixed language controls during scrolling, language changes and recovery, copy
feedback, details reset without extra requests, all ten locale labels, RTL
content/control direction and 200% text on
a narrow viewport. Tests also keep the primary result and Copy reachable before
a long context, check the source/result order for text translation, and prevent
headline styling of long answers to short words. Layout tests
(`translate_sheet_layout_test.dart`) check the quiet
selection label (pronunciation on its line, grammar and base form below,
joined by a dot or stacked without it, in either direction), the
answer heading for expressions and short phrases, the four outlined sections in
reading order (two for text translation), 12dp between and inside sections at
1x and 2x, 8dp titles and the 4dp expression gap, Copy centered on each answer
and reaching the outline, interface-edge titles in Arabic, and long words that
shrink instead of breaking at 2x. Both themes verify the muted
source (at least 4.5:1) with the selection semibold in the body color (at least
7:1) and no fill; successful results quote nothing, while loading and failure
previews keep the quote.
Root `make test-ui` adds modal
goldens in five visual profiles, including words, complete text, language menus
and collapsed/expanded lexical details.
`make test-device DEVICE=<id>` exercises the reader-to-translation flow in a
native WebView using deterministic services, including equality between the
book's source sentence, the request context and the visible Sentence text.
It does not test live providers.

`integration_test/translation_sheet_test.dart` is a focused native sheet check
using the real device viewport, font rendering and clipboard, plus deterministic
provider responses. It checks ordinary words and contextual expressions,
immediately visible general meanings, both copy commands, a fixed language header
while dragging the expanded details, and a target-language change from that
scrolled position without extra requests from copying or scrolling.
Run it on either platform with the existing
`test_driver/ui_driver.dart` and `READFLEX_NATIVE_DEVICE=<id>`; screenshots go to
`.local/ui-device/`. It does not simulate reader selection or call DeepSeek.
