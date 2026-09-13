#!/bin/bash

set -e

FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
COVERAGE_DIR=${COVERAGE_DIR:-}

PASS=0
FAIL=0
FAILED_LABELS=()

run() {
  local label=$1
  local cmd=$2
  local dir=$3
  local measured=false
  local status=0

  if [ -n "$COVERAGE_DIR" ]; then
    local output="$COVERAGE_DIR/$label"
    mkdir -p "$output"
    case "$cmd" in
      "$FLUTTER test "*)
        cmd="$cmd --coverage --branch-coverage --coverage-path='$output/lcov.info' --coverage-package='$COVERAGE_PACKAGES' --file-reporter=json:'$output/tests.jsonl'"
        measured=true
        ;;
      "$DART test "*)
        cmd="$cmd --branch-coverage --coverage-path='$output/lcov.info' --coverage-package='$COVERAGE_PACKAGES' --file-reporter=json:'$output/tests.jsonl'"
        measured=true
        ;;
    esac
  fi

  echo ""
  echo "▶ $label"
  if (cd "$dir" && eval "$cmd" 2>&1); then
    PASS=$((PASS + 1))
  else
    status=$?
    FAIL=$((FAIL + 1))
    FAILED_LABELS+=("$label")
  fi
  if [ -n "$COVERAGE_DIR" ]; then
    printf '%s\t%s\t%s\t%s\n' "$label" "$dir" "$status" "$measured" >> "$COVERAGE_DIR/suites.tsv"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -n "$COVERAGE_DIR" ]; then
  mkdir -p "$COVERAGE_DIR"
  COVERAGE_DIR="$(cd "$COVERAGE_DIR" && pwd)"
  if [ -e "$COVERAGE_DIR/suites.tsv" ]; then
    echo "Use a fresh COVERAGE_DIR to avoid mixing results from different runs." >&2
    exit 2
  fi
  node "$SCRIPT_DIR/scripts/coverage_report.mjs" --snapshot "$COVERAGE_DIR"
  COVERAGE_PACKAGES="$(node -e 'const fs = require("node:fs"); const s = JSON.parse(fs.readFileSync(process.argv[1])); process.stdout.write("^(" + s.packages.join("|") + ")$");' "$COVERAGE_DIR/sources.json")"
fi

run "test_harness"                 "node --test scripts/test/*.test.mjs" "$SCRIPT_DIR"
run "app"                          "$FLUTTER test test/" "$SCRIPT_DIR"
run "domain_models"                "$FLUTTER test test/" "$SCRIPT_DIR/packages/domain_models"
run "shared"                       "$FLUTTER test test/" "$SCRIPT_DIR/packages/shared"
run "readflex_localizations"       "$FLUTTER test test/" "$SCRIPT_DIR/packages/readflex_localizations"
run "monitoring"                   "$FLUTTER test test/" "$SCRIPT_DIR/packages/monitoring"
run "component_library"            "$FLUTTER test test/" "$SCRIPT_DIR/packages/component_library"
run "local_storage"                "$FLUTTER test test/" "$SCRIPT_DIR/packages/local_storage"
run "book_repository"              "$FLUTTER test test/" "$SCRIPT_DIR/packages/book_repository"
run "collection_repository"        "$FLUTTER test test/" "$SCRIPT_DIR/packages/collection_repository"
run "article_extraction_service"   "$DART test test/" "$SCRIPT_DIR/packages/article_extraction_service"
run "remote_content_policy"        "$DART test test/" "$SCRIPT_DIR/packages/remote_content_policy"
run "article_repository"           "$FLUTTER test test/" "$SCRIPT_DIR/packages/article_repository"
run "highlight_repository"         "$FLUTTER test test/" "$SCRIPT_DIR/packages/highlight_repository"
run "connectivity_service"         "$FLUTTER test test/" "$SCRIPT_DIR/packages/connectivity_service"
run "contextual_translation_service" "$FLUTTER test test/" "$SCRIPT_DIR/packages/contextual_translation_service"
run "dictionary_service"           "$FLUTTER test test/" "$SCRIPT_DIR/packages/dictionary_service"
run "device_screen_brightness"    "$FLUTTER test test/" "$SCRIPT_DIR/packages/device_screen_brightness"
run "screen_control_service"       "$FLUTTER test test/" "$SCRIPT_DIR/packages/screen_control_service"
run "preferences_service"         "$FLUTTER test test/" "$SCRIPT_DIR/packages/preferences_service"
run "reader_server"               "$FLUTTER test test/" "$SCRIPT_DIR/packages/reader_server"
run "reader_webview"              "$FLUTTER test test/" "$SCRIPT_DIR/packages/reader_webview"
run "reader_webview_js"           "node --test test_js/*.test.mjs" "$SCRIPT_DIR/packages/reader_webview"
run "reader_browser_chromium"     "npm run test:browser" "$SCRIPT_DIR/packages/reader_webview"
run "reader_browser_webkit"       "READER_BROWSER=webkit npm run test:browser" "$SCRIPT_DIR/packages/reader_webview"
run "toast_service"               "$FLUTTER test test/" "$SCRIPT_DIR/packages/toast_service"
run "library"                     "$FLUTTER test test/" "$SCRIPT_DIR/packages/features/library"
run "import_flow"                 "$FLUTTER test test/" "$SCRIPT_DIR/packages/features/import_flow"
run "highlight"                   "$FLUTTER test test/" "$SCRIPT_DIR/packages/features/highlight"
run "translate"                   "$FLUTTER test test/" "$SCRIPT_DIR/packages/features/translate"
run "dictionary"                  "$FLUTTER test test/" "$SCRIPT_DIR/packages/features/dictionary"
run "reader"                      "$FLUTTER test test/" "$SCRIPT_DIR/packages/features/reader"

echo ""
echo "────────────────────────────"
echo "  passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
  echo "  failed labels: ${FAILED_LABELS[*]}"
fi
echo "────────────────────────────"

if [ -n "$COVERAGE_DIR" ]; then
  printf 'complete\n' > "$COVERAGE_DIR/completed"
fi
[ $FAIL -eq 0 ]
