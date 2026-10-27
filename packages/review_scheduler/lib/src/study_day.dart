/// A day as review scheduling counts it: it starts at [startHour] local time,
/// not at midnight, so a card reviewed at 23:50 and again at 00:10 is seen
/// once that day, and "due tomorrow" means tomorrow, whatever the clock said
/// at the review. The same rule as Anki's "next day starts at".
///
/// Days are compared by their calendar date in local time, so a change of
/// daylight saving time never makes a day 23 or 25 hours long.
class StudyDay {
  const StudyDay({this.startHour = defaultStartHour})
    : assert(startHour >= 0 && startHour < 24);

  /// Anki's default: reviews before 04:00 still belong to the day before.
  static const int defaultStartHour = 4;

  /// Hour of local time at which a study day begins.
  final int startHour;

  /// The calendar date of the study day holding [moment], as a UTC date-only
  /// value; two of these subtract to a whole number of days.
  DateTime dateOf(DateTime moment) {
    final local = moment.toLocal();
    final date = local.hour < startHour
        ? DateTime(local.year, local.month, local.day - 1)
        : local;
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// Whole study days from [from] to [to]: 0 within one day, negative when
  /// [to] is earlier.
  int between(DateTime from, DateTime to) =>
      dateOf(to).difference(dateOf(from)).inDays;

  /// When the study day holding [moment] began, in local time.
  DateTime startOf(DateTime moment) {
    final date = dateOf(moment);
    return DateTime(date.year, date.month, date.day, startHour);
  }

  /// When the study day [days] after the one holding [moment] begins, in
  /// local time: where a card scheduled that many days ahead comes due.
  DateTime startAfter(DateTime moment, int days) {
    final date = dateOf(moment);
    return DateTime(date.year, date.month, date.day + days, startHour);
  }
}
