# contextual_translation_service

Contextual translation contracts and service orchestration.

This package owns the wire format between reader text selection and the
translation backend, plus the fallback path for on-device ML Kit translation.
UI packages depend on the service contract and models, not on HTTP, ML Kit, or
cache details.

## Public API

| Symbol | Purpose |
|--------|---------|
| `ContextualTranslationRequest` | Versioned request payload with selected text, marked context, language direction, and source anchor |
| `ContextualTranslationResult` | Versioned response payload with detected language, translation, alternatives, explanation, and source metadata |
| `ContextualTranslationService` | Common translation service contract |
| `RemoteContextualTranslationService` | HTTP client for `/v1/contextual-translation/analyze` |
| `MlKitOfflineTranslationService` | On-device fallback using Google ML Kit models |
| `ContextualTranslationCoordinator` | Cache-first remote call with controlled offline fallback |

Requests use `contextual_lookup` for short lexical selections and
`text_translation` for complete sentences or longer fragments. The latter
requires the provider to translate the complete selection without extracting a
single focus word.

## Flow

```text
TranslateCubit
  -> ContextualTranslationCoordinator
    -> memory cache
    -> RemoteContextualTranslationService
    -> MlKitOfflineTranslationService when network/backend is unavailable
```

Remote translation may use `source_language: "auto"` and
`source_language_hint`. Offline translation requires a concrete source language
because ML Kit does not auto-detect inside the translation API.

The remote client treats the backend payload as an untrusted versioned
contract. It requires the supported schema version and enums, verifies that the
response `request_id` and mode match the request, and maps malformed responses
to a stable invalid-response failure. Backend response bodies and credential
details are never surfaced directly in user-facing errors.
