#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p .local/coverage
OUTPUT="$(mktemp -d "$ROOT/.local/coverage/run-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
echo "Coverage run: $OUTPUT"
status=0
COVERAGE_DIR="$OUTPUT" bash test_all.sh > "$OUTPUT/run.log" 2>&1 || status=$?
node scripts/coverage_report.mjs "$OUTPUT" || status=$?
echo "Test log: $OUTPUT/run.log"
exit "$status"
