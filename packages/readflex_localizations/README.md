# readflex_localizations

Generated Flutter localizations and supported locale metadata for Readflex.

Supported locales follow the app-defined order from Nota:

```text
en, zh, hi, es, ar, fr, ru, pt, de, ja
```

## Rules

- Keep all user-facing UI copy in ARB files under `lib/l10n`.
- Do not put localized strings in Bloc/Cubit state. Emit typed error codes and
  map them to `context.l10n` in the widget that renders the message.
- Localize accessibility labels, tooltips, empty states, validation text, and
  toast text.
- Do not translate user data such as titles, author names, URLs, or collection
  names.

## Updating Copy

1. Update `lib/l10n/intl_en.arb`.
2. Add the same key to every other `intl_*.arb` file.
3. Run from this package:

```sh
fvm flutter gen-l10n
```

4. Run project checks from the repo root:

```sh
make analyze
make test
```
