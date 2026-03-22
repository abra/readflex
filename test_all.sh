#!/bin/bash

set -e

PASS=0
FAIL=0

run() {
  local label=$1
  local cmd=$2
  local dir=$3

  echo ""
  echo "▶ $label"
  if (cd "$dir" && eval "$cmd" 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

run "shared"                       "dart test test/"    "$SCRIPT_DIR/packages/shared"
run "monitoring"                   "flutter test test/" "$SCRIPT_DIR/packages/monitoring"
run "component_library"            "flutter test test/" "$SCRIPT_DIR/packages/component_library"
run "local_storage"                "flutter test test/" "$SCRIPT_DIR/packages/local_storage"
run "book_repository"              "flutter test test/" "$SCRIPT_DIR/packages/book_repository"

echo ""
echo "────────────────────────────"
echo "  passed: $PASS  failed: $FAIL"
echo "────────────────────────────"

[ $FAIL -eq 0 ]
