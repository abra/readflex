# dev_data

Fake seed data for development and UI testing. Not wired into release
builds — seeders are called from composition only behind a dev flag
(e.g. `config.isDev`), so they never run for end users.

Use this package to populate an empty database with realistic-looking
content while working on a screen, or to make dev builds feel alive
before real import flows exist.

---

## Public API

| Function           | Purpose                                                          |
|--------------------|------------------------------------------------------------------|
| `seedDictionary`   | Inserts ~10 sample words with FSRS review items and fake history |

All seeders are idempotent: they bail out early if data already exists
in the target table, so repeated hot-restarts do not accumulate rows.

---

## Example

```dart
// lib/app/composition.dart
if (config.isDev) {
  await seedDictionary(
    dictionaryRepository: dictionaryRepository,
    fsrsRepository: fsrsRepository,
  );
}
```

Seeders go through the real repositories, so they exercise the same
mappers and migrations the production path does.

---

## Where it fits

```
dev_data → domain_models, dictionary_repository, fsrs_repository
        ▲
        │
        └── lib/app/composition.dart   (called only under a dev flag)
```

No feature or other package imports `dev_data`.

---

## Rules

- Seeders never run in release. Gate every call with a dev flag.
- Idempotent: check for existing data and return early.
- Use real repositories, not direct DAO writes — seeding must go
  through the same validation path as user input.
- Remove a seeder once its matching import/creation flow exists.
- Never invent demo content proactively when asked for mechanics; a
  seeder is only justified when explicitly requested.
