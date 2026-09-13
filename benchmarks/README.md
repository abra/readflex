# Performance benchmarks

These checks are opt-in benchmarks, not part of `make test`. Run with the pinned
SDK and avoid concurrent builds, coverage collection, or emulator workloads
when comparing elapsed times.

```sh
make test-performance
```

- `reader_search_benchmark_test.dart`: 1k/5k/20k one-result chunks through the
  production search cubit; one warmup and three samples. Records median elapsed
  microseconds, state emissions, and cumulative result entries published.
- `library_benchmark_test.dart`: 1k/5k/20k books through the production Library
  state projection/search; one warmup and five samples, plus 10k cached reads.
- Results: `.local/performance/reader-search.json` and `library.json`. Preserve
  before/after artifacts locally before rerunning, since these paths are replaced.

Normal tests enforce structural budgets, without flaky stopwatch thresholds:
`reader_search_stress_test.dart` checks burst emissions, no lost results,
cancellation and completion; `test/ui/library_scaling_test.dart` bounds mounted
tiles during scrolling and verifies cached projection identity at 20k books.

These are host/JIT measurements, not release-device frame, peak-memory, import,
or native WebView benchmarks. The Library workload starts from loaded models;
it does not include SQLite reads or cover decoding. The search workload measures
burst handling, not the JS search engine or every continuous-stream pattern.

Run database query/index measurements:

```sh
fvm flutter test benchmarks/perf_audit_test.dart --dart-define=PERF_AUDIT_COMMAND=db --dart-define=PERF_AUDIT_SCALE=20000
```

Use these numbers to justify production changes; do not turn the benchmark into
a strict pass/fail test without platform-specific thresholds.
