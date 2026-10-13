part of 'translate_sheet.dart';

/// The selection's part of speech and base form, a muted line on the source
/// text's edge.
///
/// When both fit one line they are joined by ` · `, as metadata elsewhere in
/// the app. Otherwise the base form moves below the part of speech without
/// the separator, so no separator hangs at the end of a line.
class _TranslationGrammarLine extends StatelessWidget {
  const _TranslationGrammarLine({
    required this.textDirection,
    this.partOfSpeech,
    this.lemma,
  }) : assert(partOfSpeech != null || lemma != null);

  final String? partOfSpeech;
  final String? lemma;
  final TextDirection textDirection;

  static const _separator = ' · ';

  @override
  Widget build(BuildContext context) {
    final partOfSpeech = this.partOfSpeech;
    final lemma = this.lemma;
    // The style of AppLexicalMetadataRow, so the part of speech measures as
    // it renders.
    final style = context.text.bodyMedium.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    if (partOfSpeech == null) {
      return _TranslationBaseForm(
        lemma: lemma!,
        style: style,
        textDirection: textDirection,
      );
    }
    final grammar = AppLexicalMetadataRow(
      partOfSpeech: partOfSpeech,
      textDirection: textDirection,
    );
    if (lemma == null) return grammar;
    final baseForm = _TranslationBaseForm(
      lemma: lemma,
      style: style,
      textDirection: textDirection,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneLineWidth =
            _textWidth(context, partOfSpeech, style) +
            _textWidth(context, _separator, style) +
            _textWidth(context, _baseFormPhrase(context, lemma), style);
        if (oneLineWidth <= constraints.maxWidth) {
          return Wrap(
            textDirection: textDirection,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              grammar,
              ExcludeSemantics(child: Text(_separator, style: style)),
              baseForm,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          textDirection: textDirection,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            grammar,
            const SizedBox(height: AppSpacing.xxs),
            baseForm,
          ],
        );
      },
    );
  }
}

/// "Base form: lemma", one phrase in the interface language.
///
/// It wraps between words like any phrase, and its label precedes the lemma
/// in the interface's reading order, whatever the lemma's own direction.
/// Wrapped lines keep the source text's edge, [textDirection], like the rest
/// of the line.
class _TranslationBaseForm extends StatelessWidget {
  const _TranslationBaseForm({
    required this.lemma,
    required this.style,
    required this.textDirection,
  });

  final String lemma;
  final TextStyle style;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    return Text(
      _baseFormPhrase(context, lemma),
      key: const ValueKey('translation-base-form'),
      textAlign: textDirection == TextDirection.ltr
          ? TextAlign.left
          : TextAlign.right,
      style: style,
    );
  }
}

// The lemma is isolated in its own direction, so it cannot reorder the
// label around it.
String _baseFormPhrase(BuildContext context, String lemma) {
  final isolate = translationTextDirection(lemma) == TextDirection.rtl
      ? _rightToLeftIsolate
      : _leftToRightIsolate;
  return context.l10n.translationBaseForm(
    '$isolate$lemma$_popDirectionalIsolate',
  );
}

const _leftToRightIsolate = '\u2066';
const _rightToLeftIsolate = '\u2067';
const _popDirectionalIsolate = '\u2069';

// The width of [text] on one line as a `Text` in [context] draws it.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
