# dictionary_service

System and backend dictionary lookup contracts for Readflex.

- `PlatformSystemDictionaryService` opens the native definition UI when the
  platform has a definition handler.
- `RemoteDictionaryLookupService` calls the separate Readflex Dictionary API.
- Dictionary definitions remain in the language of the selected term. This
  package does not translate definitions.
- DeepSeek is called by the Dictionary API, never by this package. Provider
  credentials remain on the server.

## Lookup flow

`SystemDictionaryService.showDefinition(term)` returns whether native UI was
presented. The app runners implement the channel
`io.github.abra.readflex/dictionary`: iOS uses
`UIReferenceLibraryViewController`, while Android 10+ resolves
`Intent.ACTION_DEFINE`. Missing handlers and platform-channel failures return
`false` so the feature can fall back without treating absence as an error.

`RemoteDictionaryLookupService` sends `POST /v1/dictionary/lookup` with this
request shape:

```json
{
  "request_id": "uuid",
  "term": "power",
  "source_language": "en",
  "context_text": "The [[power]] bank is compact."
}
```

`source_language` is an optional hint. `context_text` is optional and is used
only to choose the relevant meaning; `[[...]]` marks the selected text when
marked context is available. Responses use typed statuses `found`, `not_found`,
or `unsupported_language`, include the same `request_id`, and may include
lexical entries, examples, and pronunciation.
