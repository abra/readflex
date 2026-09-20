# translate

Reader text action and bottom sheet for contextual translation.

The feature implements `TranslateAction` from the shared reader text-action
contract. It owns only UI and sheet state: request building, language selectors,
loading/error states, and target-language preference updates.

## Public API

| Symbol | Purpose |
|--------|---------|
| `TranslateAction` | Reader context-panel action wired by `routing.dart` |
| `showTranslateSheet` | Opens the translation sheet for a `TextSelectionContext` |

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
Request construction rejects a stale normalized single-word snapshot when the
exact selection has already been expanded to multiple words.

Short words and expressions use `contextual_lookup` so the backend can resolve
their meaning inside the surrounding sentence. Complete sentences, paragraphs,
and long selections use `text_translation`; in that mode the complete selected
range is the translation target and lexical analysis fields are not rendered.
For contextual lookup, the sheet shows the selected fragment and its translation
first. A word is a compact heading, with optional pronunciation/reading and a
localized part of speech directly below it. A different lemma appears as
**Base form** without expanding details. Pronunciation describes the selected
surface form, not its lemma: mismatched or absent `analysis.surface_form` hides
pronunciation/reading and part of speech. Unknown grammatical tags are omitted.
Reading is language-aware (e.g. Japanese kana or Chinese pinyin); identical
reading/pronunciation is not repeated. Metadata aligns with the source word's
writing direction, independently of the UI locale. IPA uses a bundled phonetic font subset.
For a single-word selection, the selected word's general translation is visible
directly below its lexical header. A separate **In this context** section shows
the contextual answer when it differs or describes a larger expression. When
the backend returns a grounded `contextual_expression`, this section names the
exact source excerpt (e.g. `rather than` for selected `rather`), followed by its
translation. The source sentence and sentence translation sit below that answer
inside the same section, without a redundant Sentence heading or extra divider.
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
Below the result, the source sentence is paired with its translation. When
there is no separate contextual answer, it has a Sentence heading.
Book context is sentence-bounded at the
DOM-range extraction layer, not trimmed or re-segmented in the sheet; unrelated
sentences and clipped character-window prefixes are not part of that context.
The selected range from the reader's
marked-context contract uses semibold emphasis only, retaining the quote's text
color without a background fill. Long context cannot push the answer
below the initial viewport. Text-translation mode shows one complete translation
followed by the exact selected source under Original, without lexical sections.
Only the selected word uses the compact `titleLarge` Geist heading; contextual
expressions use `titleMedium`. All translations use consistent `bodyLarge`
typography with zero letter spacing, including short single-word answers.
Neither surface uses reader-style headline typography. The sheet body has a bounded,
scrollable viewport so long contexts and lexical results do not overflow.
The shared `ScrollEdgeFadeStack` adds full-width shadows when content extends
beyond the viewport: below the fixed title and language controls after scrolling,
and at the bottom when more content remains below. Expanding details updates the bottom shadow
without requiring a scroll gesture. Reaching either edge hides its shadow;
content that fits needs neither. The overlays ignore pointer input and do not
update translation state or request the service.

Source phrases, sentence context and full selected originals are presented as
quotations: a 2px leading rule with a 12px inner inset and no background fill.
Quote text and the standalone word heading use the primary `onSurface` text
color in both themes; only the rule retains a secondary color.
The rule follows the source text direction, so Arabic quotes use the right edge
even in an English interface. It spans the natural text height without intrinsic
layout passes, including loading and failure previews. Translated answers are
not styled as quotes. A divider separates the lexical and contextual sections.
Only optional explanation and alternatives are collapsed by default
under **Meaning & alternatives**. Expanding them is local widget state: it
neither sends a request nor rebuilds the Reader WebView. A new result resets
the expansion. Source context and sentence translation stay outside this fold.
A lemma equal to the already visible selection is omitted from the header.

An unknown offline source language offers **Select language**, which opens the
source picker without repeating the invalid request. The menu controller is
local View state; choosing a language still goes through `TranslateCubit`.
The language direction stays fixed below the Translation title; only the result,
context and details scroll. The controls remain reachable after scrolling to the
end of a long result, including when they stack on narrow/large-text screens.
Opening a source-language recovery menu does not move the result viewport.
The two language menus size to their labels, retain 48px minimum tap targets and
adapt to system text scaling. They are unfilled text controls: primary in light
mode, on-surface in dark mode so labels keep at least 4.5:1 contrast. They show
source, direction arrow and target;
there is no duplicate direction caption or visible From/To label. Those roles
remain available to assistive technologies. Controls stack with a downward
arrow when the labels cannot fit side by side. The horizontal arrow and control
order follow the UI writing direction. Menus are disabled while a request runs.
An automatically detected language is shown as **Auto: English**, for example,
without replacing the actual `auto` source preference or request value.

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
headline styling of long answers to short words. Quotation tests check the rule
direction, inset and full height for phrases, paragraphs and failure previews.
Both themes verify weight-only emphasis without a separate text color or fill.
They also require the main text color and at least 7:1 quote-to-sheet contrast.
Root `make test-ui` adds modal
goldens in five visual profiles, including words, complete text, language menus
and collapsed/expanded lexical details.
`make test-device DEVICE=<id>` exercises the reader-to-translation flow in a
native WebView using deterministic services, including equality between the
book's source sentence, the request context and the visible Sentence quote.
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
