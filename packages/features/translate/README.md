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
first. Below the result, the Sentence section pairs the source sentence supplied
by the reader with its translation. Book context is sentence-bounded at the
DOM-range extraction layer, not trimmed or re-segmented in the sheet; unrelated
sentences and clipped character-window prefixes are not part of that context.
The selected range from the reader's
marked-context contract uses semibold emphasis only, retaining the quote's text
color without a background fill. Long context cannot push the answer
below the initial viewport. Text-translation mode shows one complete translation
followed by the exact selected source under Original, without lexical sections.
Single-word answers to single-word selections use the compact `titleLarge`
Geist role; multi-word and complete-text translations use `bodyLarge`. Neither
surface uses reader-style headline typography. The sheet body has a bounded,
scrollable viewport so long contexts and lexical results do not overflow.

Source words, sentence context and full selected originals are presented as
quotations: a 2px leading rule with a 12px inner inset and no background fill.
Quote text uses the primary `onSurface` text color in both themes, including
the standalone selected word; only the rule retains a secondary color.
The rule follows the source text direction, so Arabic quotes use the right edge
even in an English interface. It spans the natural text height without intrinsic
layout passes, including loading and failure previews. Translated answers are
not styled as quotes. A divider separates context from the primary result.
Optional lemma, explanation and alternatives are collapsed by default
under **Meaning & alternatives**. Expanding them is local widget state: it
neither sends a request nor rebuilds the Reader WebView. A new result resets
the expansion. Source context and sentence translation stay outside this fold.
A lemma equal to the already visible selection is omitted from the details;
different canonical forms remain available.

An unknown offline source language offers **Select language**, which opens the
source picker without repeating the invalid request. The menu controller is
local View state; choosing a language still goes through `TranslateCubit`.
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
language changes and recovery, copy feedback, details reset without extra
requests, all ten locale labels, RTL content/control direction and 200% text on
a narrow viewport. Tests also keep the primary result and Copy reachable before
a long context, check the source/result order for text translation, and prevent
headline styling of long answers to short words. Quotation tests check the rule
direction, inset and full height for words, paragraphs and failure previews.
Both themes verify weight-only emphasis without a separate text color or fill.
They also require the main text color and at least 7:1 quote-to-sheet contrast.
Root `make test-ui` adds modal
goldens in five visual profiles, including words, complete text, language menus
and collapsed/expanded lexical details.
`make test-device DEVICE=<id>` exercises the reader-to-translation flow in a
native WebView using deterministic services, including equality between the
book's source sentence, the request context and the visible Sentence quote.
It does not test live providers.
