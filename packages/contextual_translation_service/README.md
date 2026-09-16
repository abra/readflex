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

Fallback is limited to typed network/unavailable failures and HTTP 408, 429,
or 5xx responses. Authentication/validation failures and malformed backend
responses do not trigger it. A concrete source may come from an explicit
language or the request's language hint; an unknown source requires user input.
Both language models must already be downloaded, or the caller must explicitly
allow a download. Downloading requires connectivity, so offline translation is
not guaranteed on a fresh installation. The adapter currently exposes the ten
app languages, not every language supported by ML Kit.

The default in-memory LRU holds up to 128 results for 30 minutes from each
write. Remote and offline results share this cache; a cached offline answer
does not automatically refresh from the backend when connectivity returns.
Cache hits are rebound to the current request ID. Nothing is persisted to disk.

The remote client treats the backend payload as an untrusted versioned
contract. It requires the supported schema version and enums, verifies that the
response `request_id` and mode match the request, and maps malformed responses
to a stable invalid-response failure. Backend response bodies and credential
details are never surfaced directly in user-facing errors.
