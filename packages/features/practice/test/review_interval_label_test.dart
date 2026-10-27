import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/review_interval_label.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  final l10n = lookupReadflexLocalizations(const Locale('en'));

  test('rounds intervals to one unit', () {
    expect(reviewIntervalLabel(l10n, const Duration(seconds: 30)), '1m');
    expect(reviewIntervalLabel(l10n, const Duration(minutes: 10)), '10m');
    expect(reviewIntervalLabel(l10n, const Duration(hours: 5)), '5h');
    expect(reviewIntervalLabel(l10n, const Duration(days: 3)), '3d');
    expect(reviewIntervalLabel(l10n, const Duration(days: 21)), '3w');
    expect(reviewIntervalLabel(l10n, const Duration(days: 95)), '3mo');
    expect(reviewIntervalLabel(l10n, const Duration(days: 800)), '2y');
  });

  test('due labels', () {
    final now = DateTime(2026, 10, 26);
    expect(reviewDueLabel(l10n, null, isNew: true, now: now), 'New');
    expect(reviewDueLabel(l10n, now, isNew: false, now: now), 'Due');
    expect(
      reviewDueLabel(
        l10n,
        now.add(const Duration(days: 3)),
        isNew: false,
        now: now,
      ),
      'In 3d',
    );
  });
}
