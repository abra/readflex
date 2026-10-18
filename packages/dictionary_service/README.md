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

`source_language` is an optional hint. `context_text` is optional;
`[[...]]` marks the selected text when marked context is available. The backend
uses it to choose the relevant meaning and may recognize a conventional
lexicalized expression containing the selection. Responses use typed statuses
`found`, `not_found`, or `unsupported_language`, include the same `request_id`,
and may include ordered lexical entries, examples, and pronunciation. The
selected term's canonical lemma remains first; a contextual expression such as
`shut off` follows as a separate entry.

The client verifies response shape/status and matching request ID, and maps
HTTP/network/invalid-response failures to typed errors without displaying raw
backend bodies. The default request timeout is 40 seconds and aborts transport,
including response-body reads. Completing the optional `abortTrigger` future
cancels only that lookup, not the shared client. DictionaryCubit triggers it on
sheet closure; stale results never reach the closed sheet. This does not
guarantee cancellation of work already started by the backend. The app injects
the HTTP client shared with translation and article extraction; the service
closes only a client it created itself.

`MemoryDictionaryLookupCache` (`DictionaryLookupCache`) mirrors the translation
cache: an in-memory LRU of 128 answers for 30 minutes from each write, keyed by
the request's wire payload without `request_id` (term, source language and
context). A repeated Define of the same selection is answered without a
request, rebound to the current request ID. Only validated answers are cached:
`found` with entries, `not_found` and `unsupported_language`. Failures,
timeouts, cancellations, mismatched or malformed responses, and a `found`
answer without entries are not. Nothing is persisted to disk. There is no ML
Kit definition fallback in this package: when native lookup is unavailable and
the API fails, the sheet offers retry. Backend generation/caching is a separate
service contract, not implemented in this repo.
