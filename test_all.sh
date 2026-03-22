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
run "highlight_repository"         "flutter test test/" "$SCRIPT_DIR/packages/highlight_repository"
run "dictionary_repository"        "flutter test test/" "$SCRIPT_DIR/packages/dictionary_repository"
run "flashcard_repository"         "flutter test test/" "$SCRIPT_DIR/packages/flashcard_repository"
run "article_parser"               "flutter test test/" "$SCRIPT_DIR/packages/article_parser"
run "translation_service"          "flutter test test/" "$SCRIPT_DIR/packages/translation_service"
run "ai_service"                   "flutter test test/" "$SCRIPT_DIR/packages/ai_service"
run "auth_service"                 "flutter test test/" "$SCRIPT_DIR/packages/auth_service"
run "connectivity_service"         "flutter test test/" "$SCRIPT_DIR/packages/connectivity_service"
run "subscription_service"         "flutter test test/" "$SCRIPT_DIR/packages/subscription_service"
run "notification_service"         "flutter test test/" "$SCRIPT_DIR/packages/notification_service"

echo ""
echo "────────────────────────────"
echo "  passed: $PASS  failed: $FAIL"
echo "────────────────────────────"

[ $FAIL -eq 0 ]
