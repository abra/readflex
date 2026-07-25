.PHONY: get format analyze test clean build run help

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
	$(FLUTTER) pub get
	@for pkg in $(PACKAGES); do \
		echo "▶ pub get $$pkg"; \
		(cd $$pkg && $(FLUTTER) pub get); \
	done

## Format all Dart code
format:
	$(DART) format ./

## Analyze all Dart code
analyze:
	$(FLUTTER) analyze $(ROOT_ANALYZE_PATHS)
	@for pkg in $(PACKAGES); do \
		echo "▶ analyze $$pkg"; \
		(cd $$pkg && $(FLUTTER) analyze); \
	done

## Run all tests across packages
test:
	@bash test_all.sh

## Run the app in debug mode
run:
	$(FLUTTER) run

## Build release APK
build:
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
