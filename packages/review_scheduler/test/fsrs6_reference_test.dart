import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// The `fsrs` package against py-fsrs, the algorithm's reference
/// implementation: `fixtures/fsrs6_reference.json` (written by
/// `fixtures/fsrs6_reference.py` from a py-fsrs checkout, whose version it
/// names) replays 118 review histories, the defaults, each parameter moved
/// on its own and random sets, and records the memory state after every
/// review, the interval it gives and the retrievability some days later.
///
/// The package is what [ReviewScheduler] schedules with; its own tests are
/// thin, so this is what holds it to FSRS-6. Every history keeps its reviews
/// at one time of day, so py-fsrs's calendar days and the package's agree.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/fsrs6_reference.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
  final t0 = DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true);
  final ratings = {for (final r in fsrs.Rating.values) r.value: r};

  test('the fixture names its source and covers the planned cases', () {
    expect(fixture['source'], startsWith('py-fsrs '));
    expect(cases, hasLength(118));
  });

  for (final c in cases) {
    test(c['label'] as String, () {
      final parameters = (c['parameters'] as List)
          .cast<num>()
          .map((p) => p.toDouble())
          .toList();
      final scheduler = fsrs.Scheduler(
        parameters: parameters,
        desiredRetention: (c['retention'] as num).toDouble(),
        maximumInterval: 36500,
        enableFuzzing: false,
      );
      final reviews = (c['reviews'] as List).cast<List>();
      final memory = (c['memory'] as List).cast<List>();
      final intervals = (c['intervals'] as List).cast<num>();

      var card = fsrs.Card(cardId: 1, due: t0);
      var at = t0;
      for (var i = 0; i < reviews.length; i++) {
        final [rating, after] = reviews[i].cast<num>();
        at = at.add(Duration(milliseconds: after.toInt()));
        card = scheduler
            .reviewCard(card, ratings[rating.toInt()]!, reviewDateTime: at)
            .card;
        final [stability, difficulty] = memory[i].cast<num>();
        expect(
          card.stability,
          _near(stability),
          reason: 'stability after review $i',
        );
        expect(
          card.difficulty,
          _near(difficulty),
          reason: 'difficulty after review $i',
        );
        if (card.state == fsrs.State.review) {
          expect(
            card.due.difference(at).inDays,
            intervals[i].toInt(),
            reason: 'interval after review $i',
          );
        }
      }

      for (final later in (c['retrievability'] as List).cast<List>()) {
        final [days, expected] = later.cast<num>();
        final retrievability = scheduler.getCardRetrievability(
          card,
          currentDateTime: card.lastReview!.add(Duration(days: days.toInt())),
        );
        expect(
          retrievability,
          _near(expected),
          reason: 'retrievability after $days days',
        );
      }
    });
  }
}

/// Twelve significant digits in the fixture; the port is held to nine.
Matcher _near(num expected) => closeTo(
  expected.toDouble(),
  1e-9 * (expected.abs() < 1 ? 1 : expected.abs()),
);
