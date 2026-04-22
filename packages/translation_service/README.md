# translation_service

Translation with a **remote → platform** fallback strategy. Features call
`translate()` and never deal with network state themselves — the service
decides where the result comes from and records that in
`TranslationResult.source`.

## Fallback strategy

```
translate()
  └─ try remote backend (our server → upstream provider, AI-enriched)
       ├─ success           → TranslationResult(source: remote,  context/examples populated)
       └─ NetworkException  → fall back to platform translator (iOS / Android built-in)
                                ├─ success → TranslationResult(source: platform)
                                └─ failure → throw TranslationException
```

The remote path may return additional AI-generated context and usage examples
(premium). The platform path gives plain translated text only. The UI checks
`result.source` to decide whether to render the AI-enriched blocks.

This mirrors the repository-level offline policy: reading, highlights,
flashcards, and basic translation work offline; premium AI features do not.

## Public API

| Symbol                      | Type           | Purpose                                             |
|-----------------------------|----------------|-----------------------------------------------------|
| `TranslationService`        | abstract class | Single `translate(text, fromLang, toLang)` method   |
| `NoopTranslationService`    | concrete       | Stub — echoes input, `source: platform`             |
| `TranslationResult`         | data class     | `{originalText, translatedText, source, context, usageExamples}` |
| `TranslationSource`         | enum           | `remote` / `platform`                               |
| `TranslationException`      | exception      | Thrown when both remote and platform fail           |

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

  // Only populated when result.source == TranslationSource.remote
  if (result.source == TranslationSource.remote) {
    showAiContext(result.context, result.usageExamples);
  }
} on TranslationException catch (e) {
  showError(e.message);
}
```

## Where it fits

Registered on `DependenciesContainer.translationService` in
`lib/app/composition.dart`. Consumed by the `translate` feature (bottom
sheet implementing `TextAction`). The fallback logic lives inside the
service — the feature stays simple.
