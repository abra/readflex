import '../generated/l10n/readflex_localizations.dart';

/// Localized "time left" for reading estimates.
///
/// Estimates are rounded up so a nearly finished text never reads as
/// "0 min"; under an hour they show minutes only, otherwise hours and the
/// remaining minutes. Returns `null` when there is nothing left to read or
/// the estimate is unknown, so callers can omit the line.
extension ReadingTimeFormat on ReadflexLocalizations {
  String? readingTimeLeft(double? minutes) {
    final whole = _wholeMinutes(minutes);
    if (whole == null) return null;
    if (whole < 60) return readingTimeLeftMinutes(whole);
    return readingTimeLeftHours(whole ~/ 60, whole % 60);
  }
}

int? _wholeMinutes(double? minutes) {
  if (minutes == null || !minutes.isFinite || minutes <= 0) return null;
  return minutes.ceil();
}
