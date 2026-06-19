.PHONY: get format analyze test clean build run help

PACKAGES = \
	packages/domain_models \
	packages/shared \
	packages/monitoring \
	packages/component_library \
	packages/local_storage \
	packages/book_repository \
	packages/collection_repository \
	packages/article_extraction_service \
	packages/article_repository \
	packages/highlight_repository \
	packages/preferences_service \
	packages/connectivity_service \
	packages/device_screen_brightness \
	packages/screen_control_service \
	packages/reader_server \
	packages/reader_webview \
	packages/toast_service \
	packages/features/library \
	packages/features/import_flow \
	packages/features/highlight \
	packages/features/reader

ROOT_ANALYZE_PATHS = lib test benchmarks

## Install dependencies for root and all packages
get:
	flutter pub get
	@for pkg in $(PACKAGES); do \
		echo "▶ pub get $$pkg"; \
		(cd $$pkg && flutter pub get); \
	done

## Format all Dart code
format:
	dart format ./

## Analyze all Dart code
analyze:
	flutter analyze $(ROOT_ANALYZE_PATHS)
	@for pkg in $(PACKAGES); do \
		echo "▶ analyze $$pkg"; \
		(cd $$pkg && flutter analyze); \
	done

## Run all tests across packages
test:
	@bash test_all.sh

## Run the app in debug mode
run:
	flutter run

## Build release APK
build:
	flutter build apk --release

## Remove build artifacts
clean:
	flutter clean

## Show available targets
help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^##' Makefile | sed 's/^## /  /'
	@echo ""
