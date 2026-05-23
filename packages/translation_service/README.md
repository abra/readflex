# translation_service

Translation contract plus bundled translation and pronunciation lookup.

Current production wiring uses `BundledTranslationService`: pronunciation
lookup works from bundled SQLite dictionaries (`en` today), and exact
word/phrase translation uses bundled pair packs for every direction between
`en`, `de`, `es`, `fr`, `pt`, `ru`, and `zh`. Missing rows and unsupported
pairs still fall back to the development echo `[$toLang] text`. Features call
the service through the same contract now so ML Kit / backend translation can
be added later without changing UI code.

## Current behavior

```
translate()
  └─ BundledTranslationService
       ├─ copy bundled assets/translation/<from>_<to>.sqlite to app documents
       ├─ query exact source text match, preferring native dictionary rows
       └─ fall back to TranslationResult(translatedText: '[$toLang] $text')

lookupPronunciation()
  └─ copy bundled assets/phonetic/<lang>.db to app documents on first use
  └─ query SQLite pronunciation rows for the requested word/language
```

Future text translation can still use `TranslationResult.source` to distinguish
local/platform output from remote AI-enriched output.

## Public API

| Symbol                      | Type           | Purpose                                             |
|-----------------------------|----------------|-----------------------------------------------------|
| `TranslationService`        | abstract class | `translate(...)`, `lookupPronunciation(...)`, `dispose()` |
| `BundledTranslationService` | concrete       | Bundled exact translation and pronunciation lookup |
| `NoopTranslationService`    | concrete       | Stub — echoes input, `source: platform`             |
| `TranslationResult`         | data class     | `{originalText, translatedText, source, context, usageExamples}` |
| `TranslationSource`         | enum           | `remote` / `platform`                               |
| `Pronunciation`             | data class     | Phonetic variant from a local dictionary            |
| `TranslationException`      | exception      | Reserved for real translation failures              |

## Usage

```dart
final translator = context.dependencies.translationService;

try {
  final result = await translator.translate(
    'ubiquitous',
    fromLang: 'en',
    toLang: 'ru',
  );

  // Always present
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
`lib/app/composition.dart`. Consumed by the `translate` feature (bottom
sheet implementing `TextAction`). Translation/pronunciation plumbing lives
inside the service — the feature stays simple.
