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

run "app"                          "flutter test test/" "$SCRIPT_DIR"
run "domain_models"                "flutter test test/" "$SCRIPT_DIR/packages/domain_models"
run "shared"                       "flutter test test/" "$SCRIPT_DIR/packages/shared"
run "monitoring"                   "flutter test test/" "$SCRIPT_DIR/packages/monitoring"
run "component_library"            "flutter test test/" "$SCRIPT_DIR/packages/component_library"
run "local_storage"                "flutter test test/" "$SCRIPT_DIR/packages/local_storage"
run "book_repository"              "flutter test test/" "$SCRIPT_DIR/packages/book_repository"
run "article_extraction_service"   "dart test test/" "$SCRIPT_DIR/packages/article_extraction_service"
run "article_repository"           "flutter test test/" "$SCRIPT_DIR/packages/article_repository"
run "highlight_repository"         "flutter test test/" "$SCRIPT_DIR/packages/highlight_repository"
run "dictionary_repository"        "flutter test test/" "$SCRIPT_DIR/packages/dictionary_repository"
run "flashcard_repository"         "flutter test test/" "$SCRIPT_DIR/packages/flashcard_repository"
run "review_scheduler"             "flutter test test/" "$SCRIPT_DIR/packages/review_scheduler"
run "fsrs_repository"              "flutter test test/" "$SCRIPT_DIR/packages/fsrs_repository"
run "translation_service"          "flutter test test/" "$SCRIPT_DIR/packages/translation_service"
run "ai_service"                   "flutter test test/" "$SCRIPT_DIR/packages/ai_service"
run "auth_service"                 "flutter test test/" "$SCRIPT_DIR/packages/auth_service"
run "connectivity_service"         "flutter test test/" "$SCRIPT_DIR/packages/connectivity_service"
run "subscription_service"         "flutter test test/" "$SCRIPT_DIR/packages/subscription_service"
run "notification_service"         "flutter test test/" "$SCRIPT_DIR/packages/notification_service"
run "device_screen_brightness"    "flutter test test/" "$SCRIPT_DIR/packages/device_screen_brightness"
run "screen_control_service"       "flutter test test/" "$SCRIPT_DIR/packages/screen_control_service"
run "preferences_service"         "flutter test test/" "$SCRIPT_DIR/packages/preferences_service"
run "reader_server"               "flutter test test/" "$SCRIPT_DIR/packages/reader_server"
run "reader_webview"              "flutter test test/" "$SCRIPT_DIR/packages/reader_webview"
run "reader_webview_js"           "node --test test_js/*.test.mjs" "$SCRIPT_DIR/packages/reader_webview"
run "toast_service"               "flutter test test/" "$SCRIPT_DIR/packages/toast_service"
run "catalog"              "flutter test test/" "$SCRIPT_DIR/packages/features/catalog"
run "import_flow"                  "flutter test test/" "$SCRIPT_DIR/packages/features/import_flow"
run "home"                         "flutter test test/" "$SCRIPT_DIR/packages/features/home"
run "profile"                      "flutter test test/" "$SCRIPT_DIR/packages/features/profile"
run "dictionary"                   "flutter test test/" "$SCRIPT_DIR/packages/features/dictionary"
run "practice"                     "flutter test test/" "$SCRIPT_DIR/packages/features/practice"
run "highlight"                    "flutter test test/" "$SCRIPT_DIR/packages/features/highlight"
run "flashcard"                    "flutter test test/" "$SCRIPT_DIR/packages/features/flashcard"
run "translate"                    "flutter test test/" "$SCRIPT_DIR/packages/features/translate"
run "subscription_paywall"         "flutter test test/" "$SCRIPT_DIR/packages/features/subscription_paywall"
run "source_details"               "flutter test test/" "$SCRIPT_DIR/packages/features/source_details"
run "reader"                       "flutter test test/" "$SCRIPT_DIR/packages/features/reader"

echo ""
echo "────────────────────────────"
echo "  passed: $PASS  failed: $FAIL"
echo "────────────────────────────"

[ $FAIL -eq 0 ]
