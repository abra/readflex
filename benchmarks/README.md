# Performance benchmarks

These checks are opt-in benchmarks, not part of `make test`. They compare the
current implementation against prototype changes in the same process and print
JSON metrics for manual review.

Run database query/index measurements:

```sh
flutter test benchmarks/perf_audit_test.dart --dart-define=PERF_AUDIT_COMMAND=db --dart-define=PERF_AUDIT_SCALE=20000
```

Run EPUB builder time/RSS baseline:

```sh
flutter test benchmarks/perf_audit_test.dart --dart-define=PERF_AUDIT_COMMAND=epub
```

Use these numbers to justify production changes; do not turn the benchmark into
a strict pass/fail test without platform-specific thresholds.
