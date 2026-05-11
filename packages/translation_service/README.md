# translation_service

Translation contract plus bundled pronunciation lookup.

Current production wiring uses `BundledTranslationService`: pronunciation
lookup works from bundled SQLite dictionaries (`en` today), while arbitrary
text translation is still a development stub that echoes input as
`[$toLang] text`. Features call the service through the same contract now so
ML Kit / backend translation can be added later without changing UI code.

## Current behavior

```
translate()
  └─ BundledTranslationService
       └─ returns TranslationResult(
            translatedText: '[$toLang] $text',
            source: platform,
          )

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
| `BundledTranslationService` | concrete       | Bundled pronunciation lookup; translation echo stub |
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
