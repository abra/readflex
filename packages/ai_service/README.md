# ai_service

HTTP client to our own backend, which in turn calls the DeepSeek API. API keys
and model selection stay on the server, so the model can be swapped without an
app update.

## Public API

| Symbol               | Type           | Purpose                                              |
|----------------------|----------------|------------------------------------------------------|
| `AiService`          | abstract class | Contract for AI features                             |
| `NoopAiService`      | concrete       | Stub — returns empty results, safe for development   |
| `AiServiceException` | exception      | Thrown when the backend is unreachable or errors out |

### Methods

- `Future<String> generateHint({required String front, required String back})`
  — returns an AI-generated hint for a flashcard.
- `Future<List<String>> generateUsageExamples({required String text, String? context})`
  — returns usage examples for a word or phrase.

## Usage

```dart
final ai = context.dependencies.aiService;

try {
  final hint = await ai.generateHint(front: 'ubiquitous', back: 'everywhere');
  // show hint in flashcard editor
} on AiServiceException catch (e) {
  // show "Unavailable offline" fallback
}
```

No offline fallback — features call the service and handle
`AiServiceException` themselves (typically by showing an offline message).

## Where it fits

Registered on `DependenciesContainer.aiService` in
`lib/app/composition.dart`. Currently wired to `NoopAiService`; swap for a
real HTTP implementation when the backend is ready — no callers need to
change because they depend on the `AiService` interface.
