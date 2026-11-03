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
