# translation_service

Translation contract plus bundled translation and pronunciation lookup.

Production wiring uses `BundledTranslationService` as a layered service:
pronunciation lookup returns empty until a non-bundled source is wired, exact
word/phrase translation can come from bundled pair packs, online enrichment can
come from an optional direct DeepSeek client, and the on-device translation adapter is reserved for a future
plugin/backend-safe implementation.

The direct DeepSeek client is temporary and intended only for local/internal
builds. A production app must put DeepSeek behind a Readflex backend so API
keys, rate limits, request logging, retries, and privacy policy are controlled
server-side. The client is behind `RemoteTranslationClient` so that future swap
should not affect feature UI.

## Current behavior

```
translate()
  └─ BundledTranslationService
       ├─ query assets/translation/<from>_<to>.sqlite exact pair pack if present
       ├─ if DEEPSEEK_API_KEY is set, try DeepSeek direct chat completions
       ├─ try an injected on-device translation adapter when available
       └─ fall back to development echo `[$toLang] text` unless disabled

lookupPronunciation()
  └─ return [] until a non-bundled pronunciation source is wired
```

`TranslationResult.source` distinguishes remote output from local/platform
output. Remote implementations can also return structured contextual metadata:
`answerType`, `confidence`, `sense`, `expression`, `naturalEquivalents`,
`literalTranslation`, `suggestedFullPhrase`, `notes`, `context`, and
`usageExamples`. The legacy `context` string is still populated so existing
screens and saved dictionary entries keep working, but new UI should prefer the
typed fields when it needs classification-specific rendering.

DeepSeek returns a minimal contextual payload. The relevant source sentence is
returned as `marked_sentence`, with the selected word, selected span, or larger
expression wrapped in `[[...]]` for UI highlighting. Every response shape also
includes source-language `usage_examples` and `related_terms` shaped as
`{source, target, relation}`. Related terms are vocabulary aids, not alternative
translations: `source` must be a concise word-family item, domain collocation,
narrower term, or contrast term, never a synonym, definition, broad role label,
explanatory paraphrase, or phrase that repeats the selected headword. Callers
expose them through `usageExamples` and display strings in `naturalEquivalents`.
Use an empty list when there is no useful value.

## Contextual LLM contract

The LLM contract is intentionally small. The app/backend sends the exact
selection plus sentence context; the model decides only whether the selection is
ordinary text or part of a larger language unit.

Request shape for the future backend path:

```json
{
  "source_language": "en",
  "target_language": "ru",
  "selected_text": "kick",
  "current_sentence": "Once the team is identified, it is time to kick things off.",
  "previous_sentence": null,
  "next_sentence": "The next step is to align on success criteria.",
  "selection_start": 44,
  "selection_end": 48
}
```

The current direct DeepSeek client already sends `selected_text` plus
`marked_context`; the backend version should split that into previous/current/next
sentences and offsets.

Response rules:

- One ordinary word: return `mode: single_word`, `word`, `word_translation`,
  `part_of_speech`, optional selected-form `transcription`, optional
  `word_form` for inflected words. For plural nouns, `word_form.lemma` is the
  singular source word and `word_form.transcription` is the singular IPA. Then
  return source/target `definition`, `marked_sentence` with the word
  highlighted, plus `usage_examples` and `related_terms`.
- One word inside a larger unit: return `mode: word_in_expression`, `word`,
  direct standalone `word_translation`, source/target `definition`, `phrase`
  (`text`, `type`), `marked_sentence` with the larger unit highlighted, plus
  `usage_examples` and `related_terms`. For
  separated phrasal verbs, `phrase.text` is the sentence surface to highlight,
  not a claim that inserted object words are part of the dictionary phrasal verb.
- Selected n-word expression: return `mode: selected_expression`, `text`,
  `translation`, `phrase_type`, source/target `definition`, `marked_sentence`
  with the selected text highlighted, plus `usage_examples` and
  `related_terms`.
- Selected n-word non-expression: return `mode: span_translation`, `text`,
  `translation`, `marked_sentence`, plus `usage_examples` and
  `related_terms`.

Before choosing a mode, the model checks only these larger-unit classes:
phrasal verb, idiom, fixed phrase, collocation, verb pattern, preposition
pattern, and sentence pattern. Exact selection comes first; larger contextual
unit comes second only when it exists.

## Configuration

Direct DeepSeek wiring is controlled by dart-defines on the app target:

```bash
flutter run   --dart-define=DEEPSEEK_API_KEY=...   --dart-define=DEEPSEEK_MODEL=deepseek-v4-pro
```

Optional values:

- `DEEPSEEK_BASE_URL`, default `https://api.deepseek.com`
- `DEEPSEEK_MODEL`, default `deepseek-v4-pro`

Do not ship a public build with `DEEPSEEK_API_KEY` in the client. Replace
`DeepSeekDirectTranslationClient` with a backend-backed `RemoteTranslationClient`
first.

## Public API

| Symbol                            | Type           | Purpose                                             |
|-----------------------------------|----------------|-----------------------------------------------------|
| `TranslationService`              | abstract class | `translate(...)`, `lookupPronunciation(...)`, `dispose()` |
| `BundledTranslationService`       | concrete       | Layered translation with empty pronunciation lookup |
| `UnavailableOnDeviceTranslationClient` | concrete  | Plugin-free placeholder for future offline adapter  |
| `DeepSeekDirectTranslationClient` | concrete       | Temporary direct online translator/enricher         |
| `NoopTranslationService`          | concrete       | Stub — echoes input, `source: platform`             |
| `TranslationResult`               | data class     | Translation text plus answer type, confidence, sense/expression metadata, context, and examples |
| `TranslationAnswerType`           | enum           | `wordTranslation` / `expressionExplanation` / `spanTranslation` / `ambiguous` / `unknown` |
| `TranslationConfidence`           | enum           | `high` / `medium` / `low` / `unknown`             |
| `TranslationSource`               | enum           | `remote` / `platform`                               |
| `Pronunciation`                   | data class     | Phonetic variant for future/non-bundled sources     |
| `TranslationException`            | exception      | Raised when all sources fail and echo fallback is disabled |

## Usage

```dart
final translator = context.dependencies.translationService;

try {
  final result = await translator.translate(
    'ubiquitous',
    fromLang: 'en',
    toLang: 'ru',
  );

  showText(result.translatedText);

  final pronunciations = await translator.lookupPronunciation(
    word: 'ubiquitous',
    lang: 'en',
  );
} on TranslationException catch (e) {
  showError(e.message);
}
```

## Where it fits

Registered on `DependenciesContainer.translationService` in
`lib/app/composition.dart`. Consumed by the `translate` feature (bottom sheet
implementing `TextAction`). Translation/pronunciation plumbing lives inside the
service — the feature stays simple.

## Planned backend handoff

The next production step is a backend-backed `RemoteTranslationClient` that
accepts selected text, source/target languages, source location, and nearby
sentences. A future on-device adapter can provide temporary offline
translations, save them locally with source context, then enqueue enrichment
through the backend when network is available. That queue is not implemented
yet; the direct DeepSeek client only covers the immediate online call path.
