# dictionary

Reader `TextAction` and bottom sheet for monolingual word definitions.

The action first asks `SystemDictionaryService` to present the native iOS or
Android definition UI. If the platform cannot present a definition handler,
the action opens the Readflex sheet backed by `DictionaryLookupService`.

`Define` is deliberately separate from `Translate`: definitions stay in the
language of the selected term. The remote service sends the selected term and
its sentence context to the Readflex Dictionary API. That backend calls
DeepSeek, validates its structured response, and caches valid definitions;
the mobile app never calls DeepSeek or contains its provider key.

## Architecture

- `DictionaryAction` owns system-first orchestration and opens the sheet only
  when native UI is unavailable.
- `DictionarySheet` creates `DictionaryCubit` from the injected service.
- The private sheet View reads only Cubit state and emits retry commands.
- `DictionaryCubit` maps backend statuses and typed failures to explicit UI
  states; it does not depend on platform or HTTP implementations.
