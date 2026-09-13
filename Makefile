.PHONY: get format format-check analyze test verify reader-browser-setup clean build build-android build-apk run help

FLUTTER ?= fvm flutter
DART ?= fvm dart

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
	packages/preferences_service \
	packages/connectivity_service \
	packages/contextual_translation_service \
	packages/dictionary_service \
	packages/device_screen_brightness \
	packages/screen_control_service \
	packages/reader_server \
	packages/reader_webview \
	packages/toast_service \
	packages/features/library \
	packages/features/import_flow \
	packages/features/highlight \
	packages/features/translate \
	packages/features/dictionary \
	packages/features/reader

ROOT_ANALYZE_PATHS = lib test benchmarks

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
	$(DART) format --output=none --set-exit-if-changed lib test benchmarks packages

## Analyze all Dart code
analyze:
	$(FLUTTER) analyze $(ROOT_ANALYZE_PATHS)
	@set -e; for pkg in $(PACKAGES); do \
		echo "▶ analyze $$pkg"; \
		(cd $$pkg && $(FLUTTER) analyze); \
	done

## Run all tests across packages
test:
	@FLUTTER="$(FLUTTER)" DART="$(DART)" bash test_all.sh

## Run the full local quality gate without modifying source files
verify: format-check analyze test

## Install pinned reader browser-test dependencies and browser engines
reader-browser-setup:
	cd packages/reader_webview && npm ci
	cd packages/reader_webview && npx playwright install chromium webkit

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
