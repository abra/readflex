part of 'review_session_screen.dart';

/// A saved word: the word large with its reading and part of speech, then
/// the sentence it came from with the word emphasized. The answer adds the
/// meaning in context, the word's own meaning and the sentence translation.
class ReviewWordCard extends StatelessWidget {
  const ReviewWordCard({
    required this.item,
    required this.revealed,
    super.key,
  });

  final PracticeWordItem item;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final entry = item.entry;
    final direction = _directionOf(entry.word);
    final sentence = entry.context?.trim();
    final base = entry.baseTranslation?.trim();
    final sentenceTranslation = entry.contextTranslation?.trim();
    final metadata = AppLexicalMetadataRow(
      pronunciation: entry.pronunciation,
      partOfSpeech: entry.partOfSpeech,
      textDirection: direction,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            entry.word,
            key: const ValueKey('reviewWord'),
            textDirection: direction,
            style: AppTypography.serif(
              textStyle: text.displaySmall,
              color: colors.onSurface,
            ),
          ),
        ),
        if (!metadata.isEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          metadata,
        ],
        if (sentence != null && sentence.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _EmphasizedSentence(
            key: const ValueKey('reviewSentence'),
            sentence: sentence,
            word: entry.word,
          ),
        ],
        if (revealed) ...[
          const SizedBox(height: AppSpacing.xl),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.translationInContext,
            style: text.labelMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            entry.translation,
            key: const ValueKey('reviewAnswer'),
            textDirection: _directionOf(entry.translation),
            style: text.titleLarge.copyWith(color: colors.onSurface),
          ),
          if (base != null && base.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.translationWordMeaning,
              style: text.labelMedium.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              base,
              textDirection: _directionOf(base),
              style: text.bodyLarge,
            ),
          ],
          if (sentenceTranslation != null &&
              sentenceTranslation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              sentenceTranslation,
              key: const ValueKey('reviewSentenceTranslation'),
              textDirection: _directionOf(sentenceTranslation),
              style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );
  }
}

/// The sentence with every occurrence of the word in bold.
class _EmphasizedSentence extends StatelessWidget {
  const _EmphasizedSentence({
    required this.sentence,
    required this.word,
    super.key,
  });

  final String sentence;
  final String word;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyLarge.copyWith(
      color: context.colors.onSurface,
    );
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    final needle = word.trim().toLowerCase();
    final spans = <TextSpan>[];
    if (needle.isEmpty) {
      spans.add(TextSpan(text: sentence));
    } else {
      final lower = sentence.toLowerCase();
      var cursor = 0;
      var at = lower.indexOf(needle);
      while (at >= 0) {
        if (at > cursor) {
          spans.add(TextSpan(text: sentence.substring(cursor, at)));
        }
        spans.add(
          TextSpan(
            text: sentence.substring(at, at + needle.length),
            style: bold,
          ),
        );
        cursor = at + needle.length;
        at = lower.indexOf(needle, cursor);
      }
      if (cursor < sentence.length) {
        spans.add(TextSpan(text: sentence.substring(cursor)));
      }
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textDirection: _directionOf(sentence),
    );
  }
}

/// A highlight: the quote on its colour with where it is from. The answer
/// is the note, or that there is none.
class ReviewHighlightCard extends StatelessWidget {
  const ReviewHighlightCard({
    required this.item,
    required this.revealed,
    super.key,
  });

  final PracticeHighlightItem item;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final highlight = item.highlight;
    final quote = highlight.text.trim();
    final note = highlight.note?.trim();
    final chapter = highlight.chapterTitle?.trim();
    final location = [
      ?item.sourceTitle,
      if (chapter != null && chapter.isNotEmpty) chapter,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: quote,
            style:
                AppTypography.serif(
                  textStyle: text.titleLarge,
                  color: colors.onSurface,
                ).copyWith(
                  backgroundColor: practiceHighlightTint(
                    context,
                    highlight.color,
                  ),
                ),
          ),
          key: const ValueKey('reviewQuote'),
          textDirection: _directionOf(quote),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            location,
            key: const ValueKey('reviewLocation'),
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        if (revealed) ...[
          const SizedBox(height: AppSpacing.xl),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.readerHighlightNoteTitle,
            style: text.labelMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note == null || note.isEmpty ? l10n.practiceNoNote : note,
            key: const ValueKey('reviewNote'),
            textDirection: note == null ? null : _directionOf(note),
            style: note == null || note.isEmpty
                ? text.bodyMedium.copyWith(color: colors.onSurfaceVariant)
                : text.bodyLarge,
          ),
        ],
      ],
    );
  }
}

TextDirection _directionOf(String value) =>
    Bidi.detectRtlDirectionality(value) ? TextDirection.rtl : TextDirection.ltr;
