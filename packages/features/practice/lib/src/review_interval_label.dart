import 'package:readflex_localizations/readflex_localizations.dart';

/// A short, rounded label for how far a rating postpones a card: minutes
/// under an hour, then hours, days, weeks, months and years.
String reviewIntervalLabel(ReadflexLocalizations l10n, Duration interval) {
  if (interval.inMinutes < 1) return l10n.practiceIntervalMinutes(1);
  if (interval.inHours < 1) {
    return l10n.practiceIntervalMinutes(interval.inMinutes);
  }
  if (interval.inDays < 1) return l10n.practiceIntervalHours(interval.inHours);
  final days = interval.inDays;
  if (days < 14) return l10n.practiceIntervalDays(days);
  if (days < 60) return l10n.practiceIntervalWeeks((days / 7).round());
  if (days < 365) return l10n.practiceIntervalMonths((days / 30).round());
  return l10n.practiceIntervalYears((days / 365).round());
}

/// When a card is next due, relative to now: "Due" for anything due, else
/// the rounded interval ahead; a never-reviewed card is "New".
String reviewDueLabel(
  ReadflexLocalizations l10n,
  DateTime? nextReviewAt, {
  required bool isNew,
  required DateTime now,
}) {
  if (isNew) return l10n.practiceDueNew;
  if (nextReviewAt == null || !nextReviewAt.isAfter(now)) {
    return l10n.practiceDueNow;
  }
  return l10n.practiceDueIn(
    reviewIntervalLabel(l10n, nextReviewAt.difference(now)),
  );
}
