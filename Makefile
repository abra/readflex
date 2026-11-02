.PHONY: get format format-check analyze test test-ui test-ui-contracts test-goldens update-goldens test-device coverage test-performance benchmark-mobi get-mobi-rust generate-mobi-rust build-mobi-rust test-mobi-rust benchmark-mobi-rust compare-mobi get-reader-native generate-reader-native build-reader-native test-reader-native benchmark-reader-parts verify clean build build-android build-apk run help
.PHONY: generate-vellum-mobi-native analyze-vellum-mobi-rust test-vellum-mobi-rust

FLUTTER ?= fvm flutter
DART ?= fvm dart
MOBI_RUST_ENV = PATH="$$(dirname "$$(rustup which rustc)"):$$PATH"

PACKAGES = \
	packages/domain_models \
	packages/shared \
	packages/readflex_localizations \
	packages/monitoring \
	packages/component_library \
	packages/local_storage \
	packages/book_repository \
	packages/collection_repository \
	packages/article_extraction_service \
	packages/remote_content_policy \
	packages/article_repository \
	packages/highlight_repository \
	third_party/fsrs \
	packages/review_scheduler \
	packages/fsrs_repository \
	packages/dictionary_repository \
	packages/preferences_service \
	packages/connectivity_service \
	packages/contextual_translation_service \
	packages/dictionary_service \
	third_party/device_screen_brightness \
	packages/screen_control_service \
	packages/vellum \
	packages/toast_service \
	packages/features/library \
	packages/features/import_flow \
	packages/features/highlight \
	packages/features/translate \
	packages/features/dictionary \
	packages/features/reader \
	packages/features/onboarding \
	packages/features/practice \

ROOT_ANALYZE_PATHS = lib test integration_test test_driver bin benchmarks scripts

## Regenerate the production MOBI bridge with flutter_rust_bridge_codegen 2.13.0
generate-vellum-mobi-native:
	@test "$$(flutter_rust_bridge_codegen --version)" = "flutter_rust_bridge_codegen 2.13.0"
	cd packages/vellum && fvm exec flutter_rust_bridge_codegen generate --skip-fvm-install
	cd packages/vellum/rust && $(MOBI_RUST_ENV) cargo fmt
	$(DART) format packages/vellum/lib/src/formats/mobi/native/rust

## Analyze production Rust code and formatting
analyze-vellum-mobi-rust:
	cd packages/vellum/rust && $(MOBI_RUST_ENV) cargo fmt --check
	cd packages/vellum/rust && $(MOBI_RUST_ENV) cargo clippy --locked --all-targets -- -D warnings

## Test production Rust decoders, limits and session lifecycle
test-vellum-mobi-rust:
	cd packages/vellum/rust && $(MOBI_RUST_ENV) cargo test --locked

## Install dependencies for root and all packages
get:
	$(FLUTTER) pub get
	@set -e; for pkg in $(PACKAGES); do \
		echo "▶ pub get $$pkg"; \
		(cd $$pkg && $(FLUTTER) pub get); \
	done

## Format all Dart code
format:
	$(DART) format ./

## Check Dart formatting without changing files
format-check:
	$(DART) format --output=none --set-exit-if-changed $(ROOT_ANALYZE_PATHS) packages

## Analyze all Dart code, then reject widget-returning helpers in lib/
analyze: analyze-vellum-mobi-rust
	$(FLUTTER) analyze $(ROOT_ANALYZE_PATHS)
	@set -e; for pkg in $(PACKAGES); do \
		echo "▶ analyze $$pkg"; \
		(cd $$pkg && $(FLUTTER) analyze); \
	done
	@echo "▶ widget helpers"
	$(DART) run scripts/check_widget_helpers.dart . $(filter packages/%,$(PACKAGES))

## Run all tests across packages
test: test-vellum-mobi-rust
	@FLUTTER="$(FLUTTER)" DART="$(DART)" bash test_all.sh

## Run root UI flows and visual comparisons without a device or API keys
test-ui:
	$(FLUTTER) test test/ui

## Check shared UI contracts and representative flows without devices or goldens
test-ui-contracts:
	cd packages/component_library && $(FLUTTER) test test/
	cd packages/toast_service && $(FLUTTER) test test/
	cd packages/features/import_flow && $(FLUTTER) test test/import_flow_sheet_test.dart
	cd packages/features/library && $(FLUTTER) test test/library_display_sheet_test.dart
	$(FLUTTER) test test/ui/settings_consistency_test.dart test/ui/import_book_terms_test.dart test/ui/reader_search_overlay_test.dart

## Measure Dart line/branch coverage across all suites (fresh report in .local/)
coverage:
	@FLUTTER="$(FLUTTER)" DART="$(DART)" bash scripts/test_coverage.sh

## Run repeatable workload benchmarks, with reports in .local/performance/
test-performance:
	$(FLUTTER) test benchmarks/reader_search_benchmark_test.dart benchmarks/library_benchmark_test.dart benchmarks/vellum_document_benchmark_test.dart --concurrency=1 --reporter expanded

## Freeze MOBI workloads and record current decoder timings in host AOT
benchmark-mobi:
	DART="$(DART)" node scripts/mobi_benchmark.mjs baseline $(ARGS)

## Install locked dependencies for the isolated Rust experiment
get-mobi-rust:
	cd benchmarks/mobi_rust && $(FLUTTER) pub get --enforce-lockfile

## Regenerate FRB bindings with flutter_rust_bridge_codegen 2.13.0
generate-mobi-rust:
	@test "$$(flutter_rust_bridge_codegen --version)" = "flutter_rust_bridge_codegen 2.13.0"
	cd benchmarks/mobi_rust && fvm exec flutter_rust_bridge_codegen generate --skip-fvm-install
	cd benchmarks/mobi_rust/rust && cargo fmt
	$(DART) format benchmarks/mobi_rust/lib/src/rust

## Build the release Rust library and AOT candidate worker
build-mobi-rust:
	DART="$(DART)" node scripts/mobi_rust.mjs build

## Check Rust, native decoder tests and parity through the real FRB adapter
test-mobi-rust:
	DART="$(DART)" node scripts/mobi_rust.mjs test

## Measure Rust through FRB: ARGS='--dataset <baseline-directory>/dataset.json'
benchmark-mobi-rust:
	DART="$(DART)" node scripts/mobi_rust.mjs benchmark $(ARGS)

## Compare compatible MOBI reports: BASELINE=<report.json> CANDIDATE=<report.json>
compare-mobi:
	node scripts/mobi_benchmark.mjs compare "$(BASELINE)" "$(CANDIDATE)"

## Install the isolated ZIP/XML/HTML Rust comparison dependencies
get-reader-native:
	cd benchmarks/reader_native && $(FLUTTER) pub get --enforce-lockfile
	cd benchmarks/reader_native/rust && cargo fetch --locked

## Regenerate reader part bindings with flutter_rust_bridge_codegen 2.13.0
generate-reader-native:
	@test "$$(flutter_rust_bridge_codegen --version)" = "flutter_rust_bridge_codegen 2.13.0"
	cd benchmarks/reader_native && fvm exec flutter_rust_bridge_codegen generate --skip-fvm-install
	cd benchmarks/reader_native/rust && cargo fmt
	$(DART) format benchmarks/reader_native/lib/src/rust

## Build release Rust parts and a single AOT worker for both backends
build-reader-native:
	cd benchmarks/reader_native/rust && cargo build --locked --release --target-dir target
	cd benchmarks/reader_native && $(DART) build cli --target bin/reader_parts_benchmark.dart --output ../../.local/performance/reader-parts/build

## Check the isolated comparison and output parity through FRB
test-reader-native:
	cd benchmarks/reader_native/rust && cargo fmt --check
	cd benchmarks/reader_native/rust && cargo clippy --locked --all-targets -- -D warnings
	cd benchmarks/reader_native/rust && cargo test --locked
	cd benchmarks/reader_native/rust && cargo build --locked --release --target-dir target
	cd benchmarks/reader_native && $(DART) analyze
	cd benchmarks/reader_native && $(DART) test --reporter expanded

## Freeze and compare parts: DATASET=<dataset.json> LIBRARY=<release library>
benchmark-reader-parts:
	@test -n "$(DATASET)" && test -n "$(LIBRARY)"
	node scripts/reader_parts.mjs "$(DATASET)" .local/performance/reader-parts/build/bundle "$(LIBRARY)"

## Compare committed visual baselines (does not update them)
test-goldens:
	$(FLUTTER) test test/ui --tags golden

## Explicitly regenerate visual baselines; review images before committing
update-goldens:
	$(FLUTTER) test test/ui --tags golden --update-goldens

## Run native reader flows: DEVICE=<id>, optionally COVERAGE=1 (artifacts in .local/)
test-device:
	@test -n "$(DEVICE)" || { echo "Specify DEVICE from '$(FLUTTER) devices'."; exit 2; }
	READFLEX_NATIVE_DEVICE="$(DEVICE)" READFLEX_NATIVE_COVERAGE="$(COVERAGE)" $(FLUTTER) drive --driver=test_driver/ui_driver.dart --target=integration_test/reader_flows_test.dart -d "$(DEVICE)"

## Run the full local quality gate without modifying source files
verify: format-check analyze test

## Run the app in debug mode
run:
	@sh run.sh $(ARGS)

## Build the signed Android App Bundle used by Google Play
build: build-android

build-android:
	$(FLUTTER) build appbundle --release

## Build a signed release APK for direct device testing
build-apk:
	$(FLUTTER) build apk --release

## Remove build artifacts
clean:
	$(FLUTTER) clean

## Show available targets
help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^##' Makefile | sed 's/^## /  /'
	@echo ""
