import 'package:readflex_localizations/readflex_localizations.dart';

/// Top chrome line: `chapter · title` when a distinct chapter title is known,
/// otherwise the title alone. Both parts are user content.
String readerTopChromeLine({required String title, String? chapterTitle}) {
  final trimmedTitle = title.trim();
  final chapter = chapterTitle?.trim() ?? '';
  if (chapter.isEmpty || chapter == trimmedTitle) return trimmedTitle;
  if (trimmedTitle.isEmpty) return chapter;
  return '$chapter · $trimmedTitle';
}

/// Time left in the whole article for the progress row; books show their
/// chapter instead. Null when unknown or nothing is left.
String? readerChromeArticleTimeLeftLabel(
  ReadflexLocalizations l10n, {
  required double? minutes,
}) => l10n.readingTimeLeft(minutes);
