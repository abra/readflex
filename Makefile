.PHONY: get format format-check analyze test test-ui test-ui-contracts test-goldens update-goldens test-device coverage test-performance benchmark-mobi get-mobi-rust generate-mobi-rust build-mobi-rust test-mobi-rust benchmark-mobi-rust compare-mobi get-reader-native generate-reader-native build-reader-native test-reader-native benchmark-reader-parts verify clean build build-android build-apk analyze-apk run help
.PHONY: generate-pagecraft-mobi-native analyze-pagecraft-mobi-rust test-pagecraft-mobi-rust
.PHONY: test-tools check-architecture
.PHONY: test-phone test-tablet test-tablet-layout
.PHONY: test-native-selection
.PHONY: profile-ui
.PHONY: test-contracts

FLUTTER ?= fvm flutter
DART ?= fvm dart
PUB_GET_FLAGS ?=
MOBI_RUST_ENV = PATH="$$(dirname "$$(rustup which rustc)"):$$PATH"

ifndef ANDROID_SYMBOLS_DIR
ANDROID_SYMBOLS_DIR := .local/symbols/android/$(shell date -u +%Y%m%dT%H%M%SZ)
endif

PACKAGES = \
	packages/domain_models \
	packages/shared \
	packages/readflex_localizations \
	packages/monitoring \
	packages/native_text_selection \
	packages/component_library \
	packages/local_storage \
	packages/book_repository \
	packages/collection_repository \
	packages/bounded_http \
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
	packages/pagecraft \
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
generate-pagecraft-mobi-native:
	@test "$$(flutter_rust_bridge_codegen --version)" = "flutter_rust_bridge_codegen 2.13.0"
	cd packages/pagecraft && fvm exec flutter_rust_bridge_codegen generate --skip-fvm-install
	cd packages/pagecraft/rust && $(MOBI_RUST_ENV) cargo fmt
	$(DART) format packages/pagecraft/lib/src/formats/mobi/native/rust

## Analyze production Rust code and formatting
analyze-pagecraft-mobi-rust:
	cd packages/pagecraft/rust && $(MOBI_RUST_ENV) cargo fmt --check
	cd packages/pagecraft/rust && $(MOBI_RUST_ENV) cargo clippy --locked --all-targets -- -D warnings

## Test production Rust decoders, limits and session lifecycle
test-pagecraft-mobi-rust:
	cd packages/pagecraft/rust && $(MOBI_RUST_ENV) cargo test --locked

## Resolve the app and all workspace packages with one shared lockfile
get:
	$(FLUTTER) pub get $(PUB_GET_FLAGS)

## Format all Dart code
format:
	$(DART) format ./

## Check Dart formatting without changing files
format-check:
	$(DART) format --output=none --set-exit-if-changed $(ROOT_ANALYZE_PATHS) packages

## Analyze all Dart code and check production architecture boundaries
analyze: analyze-pagecraft-mobi-rust
	$(FLUTTER) analyze $(ROOT_ANALYZE_PATHS) $(PACKAGES)
	@$(MAKE) --no-print-directory check-architecture

## Check package dependencies, widget helpers and named View dependencies
check-architecture:
	$(DART) run scripts/check_architecture.dart .
	$(DART) run scripts/check_widget_helpers.dart . $(filter packages/%,$(PACKAGES))

## Run all tests across packages
test: test-pagecraft-mobi-rust
	@FLUTTER="$(FLUTTER)" DART="$(DART)" bash test_all.sh

## Check development tools without running the app test suites
test-tools:
	$(DART) test test/tooling --reporter expanded

## Check shared real/fake repository contracts and reading/review workflows
test-contracts:
	$(FLUTTER) test test/contracts test/review_content_integrity_test.dart test/source_deletion_transaction_test.dart test/reader_highlight_review_undo_test.dart test/reader_highlight_persistence_test.dart

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
	$(FLUTTER) test benchmarks/reader_search_benchmark_test.dart benchmarks/library_benchmark_test.dart benchmarks/pagecraft_document_benchmark_test.dart --concurrency=1 --reporter expanded

## Freeze MOBI workloads and record current decoder timings in host AOT
benchmark-mobi:
	DART="$(DART)" $(DART) scripts/mobi_benchmark.dart baseline $(ARGS)

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
	DART="$(DART)" $(DART) scripts/mobi_rust.dart build

## Check Rust, native decoder tests and parity through the real FRB adapter
test-mobi-rust:
	DART="$(DART)" $(DART) scripts/mobi_rust.dart test

## Measure Rust through FRB: ARGS='--dataset <baseline-directory>/dataset.json'
benchmark-mobi-rust:
	DART="$(DART)" $(DART) scripts/mobi_rust.dart benchmark $(ARGS)

## Compare compatible MOBI reports: BASELINE=<report.json> CANDIDATE=<report.json>
compare-mobi:
	$(DART) scripts/mobi_benchmark.dart compare "$(BASELINE)" "$(CANDIDATE)"

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
	$(DART) scripts/reader_parts.dart "$(DATASET)" .local/performance/reader-parts/build/bundle "$(LIBRARY)"

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

## Profile warmed native UI on verified physical hardware: DEVICE=<id> [ALLOW_EMULATOR=1]
profile-ui:
	$(DART) scripts/native_ui_performance.dart --device "$(DEVICE)" $(if $(filter 1 true,$(ALLOW_EMULATOR)),--allow-emulator,)

## Check native selection activation and our menus: DEVICE=<iOS17+/Android-id>
test-native-selection:
	@test -n "$(DEVICE)" || { echo "Specify DEVICE from '$(FLUTTER) devices'."; exit 2; }
	READFLEX_NATIVE_DEVICE="$(DEVICE)" $(FLUTTER) drive --driver=test_driver/ui_driver.dart --target=integration_test/native_selection_controls_test.dart -d "$(DEVICE)"

## Run native phone Library/reader/Practice flows: DEVICE=<phone-id>
test-phone:
	@test -n "$(DEVICE)" || { echo "Specify phone DEVICE from '$(FLUTTER) devices'."; exit 2; }
	READFLEX_NATIVE_DEVICE="$(DEVICE)" READFLEX_NATIVE_COVERAGE="$(COVERAGE)" $(FLUTTER) drive --driver=test_driver/ui_driver.dart --target=integration_test/phone_regression_test.dart -d "$(DEVICE)"

## Run native tablet Library/reader regression flows: DEVICE=<tablet-id>
test-tablet:
	@test -n "$(DEVICE)" || { echo "Specify tablet DEVICE from '$(FLUTTER) devices'."; exit 2; }
	READFLEX_NATIVE_DEVICE="$(DEVICE)" READFLEX_NATIVE_COVERAGE="$(COVERAGE)" $(FLUTTER) drive --driver=test_driver/ui_driver.dart --target=integration_test/tablet_regression_test.dart -d "$(DEVICE)"

## Check native tablet layout, RTL and Practice: DEVICE=<tablet-id> [ROTATION=1]
test-tablet-layout:
	@test -n "$(DEVICE)" || { echo "Specify tablet DEVICE from '$(FLUTTER) devices'."; exit 2; }
	READFLEX_NATIVE_DEVICE="$(DEVICE)" READFLEX_NATIVE_COVERAGE="$(COVERAGE)" $(FLUTTER) drive --driver=test_driver/ui_driver.dart --target=integration_test/tablet_layout_test.dart --dart-define=READFLEX_TEST_TABLET_ROTATION=$(if $(filter 1 true,$(ROTATION)),true,false) -d "$(DEVICE)"

## Run the full local quality gate without modifying source files
verify: format-check analyze test

## Run the app in debug mode
run:
	@sh run.sh $(ARGS)

## Build the signed Android App Bundle used by Google Play
build: build-android

build-android:
	$(FLUTTER) build appbundle --release --split-debug-info="$(ANDROID_SYMBOLS_DIR)" $(ARGS)

## Build signed release APKs split by CPU architecture
build-apk:
	$(FLUTTER) build apk --release --split-per-abi --split-debug-info="$(ANDROID_SYMBOLS_DIR)" $(ARGS)

## Inspect APK size and native architectures: APK=<file> [ARGS='--expect-abi arm64-v8a']
analyze-apk:
	@test -n "$(APK)" || { echo "Specify APK=<path-to-apk>" >&2; exit 2; }
	$(DART) scripts/apk_size.dart "$(APK)" $(ARGS)

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
