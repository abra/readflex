<h1 align="center">
  <img width="120" height="120" alt="Logo" src="assets/logo.png">
  <br/>Readflex
</h1>

<p align="center">Read books, comics, and saved articles. Review words and highlights.</p>

## Getting started

Use Flutter **3.50.0 / Dart 3.14**, pinned in `.fvmrc`, through FVM.
Install Rust through rustup; the native toolchain is pinned in
`packages/pagecraft/rust/rust-toolchain.toml`. Android needs its SDK/NDK and
the JDK configured for Flutter; iOS needs Xcode and CocoaPods.
Pagecraft's build hooks compile and bundle native libraries automatically.

```sh
fvm install
make get
./run.sh
```

The first launch creates `.local/run-defines.json` and exits. Set
`READFLEX_API_KEY` and, optionally, `GLITCHTIP_DSN` there, then run `./run.sh`
again. Keep this local DEV configuration private.
The template uses `ENVIRONMENT=DEV` even in release mode. Production backend
authentication is still incomplete; static API credentials are DEV-only.

To choose a device or run mode:

```sh
./run.sh -d <device-id>
./run.sh --release -d <device-id>
```

Keep the committed SDK and dependency lockfiles; restore iOS dependencies with
`pod install`. Private defines, signing keys and build outputs stay untracked.
`make get` resolves the app and production packages as one Pub workspace with
the root lockfile. Native benchmark experiments keep their own dependency pins.

## Checks

```sh
make analyze
make test
make test-ui-contracts
make test-ui
```

## Android builds

Configure release signing using `android/key.properties.example` and save the
values in the ignored `android/key.properties` file.

```sh
make build                                                # Signed AAB
make build-apk                                            # APKs split by ABI
make build-apk ARGS='--target-platform android-arm64'       # ARM64 only
```

Build targets do not load `.local/run-defines.json` automatically. For a local
DEV build, pass `--dart-define-from-file=.local/run-defines.json` in `ARGS`.
APKs go to `build/app/outputs/flutter-apk/`; archive the matching debug symbols
from `.local/symbols/android/` with each release artifact.
DjVu uses DjVuLibre (GPLv2-or-later); its license is documented in Pagecraft.

## Documentation

- [Architecture](ARCHITECTURE.md) · [C4 diagrams](C4_MODEL.md) — structure and package boundaries.
- [Pagecraft](packages/pagecraft/README.md) — reader engine, formats and native backends.
- [UI verification](test/ui/README.md) · [Accessibility](ACCESSIBILITY.md) — checks and review guidelines.
- [Benchmarks](benchmarks/README.md) — performance measurements.

Package READMEs document their APIs and implementation details.
