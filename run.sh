#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
DEFINES_FILE="$PROJECT_ROOT/.local/run-defines.json"

if [ ! -f "$DEFINES_FILE" ]; then
  (
    umask 077
    mkdir -p "$PROJECT_ROOT/.local"
    # Do not overwrite a configuration created by another concurrent launch.
    set -C
    cat "$PROJECT_ROOT/config/run-defines.example.json" > "$DEFINES_FILE"
  )
  printf 'Created %s\n' "$DEFINES_FILE"
  printf 'Set READFLEX_API_KEY and, optionally, GLITCHTIP_DSN once, then run again.\n'
  exit 2
fi

if ! command -v fvm > /dev/null 2>&1; then
  printf 'FVM is required to run the Flutter version pinned in .fvmrc.\n' >&2
  exit 1
fi

cd "$PROJECT_ROOT"
exec fvm flutter run --dart-define-from-file="$DEFINES_FILE" "$@"
