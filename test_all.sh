#!/bin/bash

set -e

PASS=0
FAIL=0
FAILED_LABELS=()

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
    FAILED_LABELS+=("$label")
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
run "collection_repository"        "flutter test test/" "$SCRIPT_DIR/packages/collection_repository"
run "article_extraction_service"   "dart test test/" "$SCRIPT_DIR/packages/article_extraction_service"
run "article_repository"           "flutter test test/" "$SCRIPT_DIR/packages/article_repository"
run "highlight_repository"         "flutter test test/" "$SCRIPT_DIR/packages/highlight_repository"
run "connectivity_service"         "flutter test test/" "$SCRIPT_DIR/packages/connectivity_service"
run "device_screen_brightness"    "flutter test test/" "$SCRIPT_DIR/packages/device_screen_brightness"
run "screen_control_service"       "flutter test test/" "$SCRIPT_DIR/packages/screen_control_service"
run "preferences_service"         "flutter test test/" "$SCRIPT_DIR/packages/preferences_service"
run "reader_server"               "flutter test test/" "$SCRIPT_DIR/packages/reader_server"
run "reader_webview"              "flutter test test/" "$SCRIPT_DIR/packages/reader_webview"
run "reader_webview_js"           "node --test test_js/*.test.mjs" "$SCRIPT_DIR/packages/reader_webview"
run "toast_service"               "flutter test test/" "$SCRIPT_DIR/packages/toast_service"
run "library"              "flutter test test/" "$SCRIPT_DIR/packages/features/library"
run "import_flow"                  "flutter test test/" "$SCRIPT_DIR/packages/features/import_flow"
run "highlight"                    "flutter test test/" "$SCRIPT_DIR/packages/features/highlight"
run "source_details"               "flutter test test/" "$SCRIPT_DIR/packages/features/source_details"
run "reader"                       "flutter test test/" "$SCRIPT_DIR/packages/features/reader"

echo ""
echo "────────────────────────────"
echo "  passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
  echo "  failed labels: ${FAILED_LABELS[*]}"
fi
echo "────────────────────────────"

[ $FAIL -eq 0 ]
