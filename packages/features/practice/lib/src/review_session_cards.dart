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
        _ReviewWordHeading(word: entry.word, direction: direction),
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
        if (item.sourceTitle case final title?) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            key: const ValueKey('reviewWordSource'),
            textDirection: _directionOf(title),
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
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
          AppTextSelectionHost(
            child: SelectableText(
              entry.translation,
              key: const ValueKey('reviewAnswer'),
              textDirection: _directionOf(entry.translation),
              style: text.titleLarge.copyWith(color: colors.onSurface),
            ),
          ),
          if (base != null && base.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.translationWordMeaning,
              style: text.labelMedium.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppTextSelectionHost(
              child: SelectableText(
                base,
                textDirection: _directionOf(base),
                style: text.bodyLarge,
              ),
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

class _ReviewWordHeading extends StatelessWidget {
  const _ReviewWordHeading({required this.word, required this.direction});

  final String word;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: LayoutBuilder(
      builder: (context, constraints) => Text(
        word,
        key: const ValueKey('reviewWord'),
        textDirection: direction,
        style: appFitLongestWord(
          AppTypography.serif(
            textStyle: context.text.displaySmall,
            color: context.colors.onSurface,
          ),
          text: word,
          maxWidth: constraints.maxWidth,
          minFontSize: context.text.titleLarge.fontSize!,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: direction,
          locale: Localizations.maybeLocaleOf(context),
        ),
      ),
    ),
  );
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

TextDirection _directionOf(String value) =>
    Bidi.detectRtlDirectionality(value) ? TextDirection.rtl : TextDirection.ltr;
