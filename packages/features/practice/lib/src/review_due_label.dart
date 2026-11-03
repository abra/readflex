import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

final _dateFormats = <String, DateFormat>{};

/// The stored FSRS deadline in local time, including its calendar date.
String reviewDueLabel(BuildContext context, FsrsCardData fsrs) {
  final l10n = context.l10n;
  final deadline = fsrs.nextReviewAt;
  if (deadline == null) {
    return fsrs.state == FsrsState.newCard
        ? l10n.practiceDueNew
        : l10n.practiceDueNow;
  }
  final local = deadline.toLocal();
  final dateFormat = _dateFormats.putIfAbsent(
    l10n.localeName,
    () => DateFormat.yMMMd(l10n.localeName),
  );
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return l10n.practiceNextReviewAt(dateFormat.format(local), time);
}
