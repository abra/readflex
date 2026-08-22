import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:shared/shared.dart';

String translationModeForSelection(TextSelectionContext selection) {
  final selected = _collapseWhitespace(selection.effectiveSelectedText);
  if (selected.isEmpty) return contextualTranslationMode;

  final contextText = selection.contextText?.trim();
  final currentContext = contextText == null || contextText.isEmpty
      ? selected
      : contextText;
  final words = selected.split(' ');
  final context = _collapseWhitespace(currentContext);
  final isWholeContext = words.length > 1 && selected == context;
  final containsSentenceBoundary = RegExp(
    r'[\r\n.!?\u2026\u3002\uFF01\uFF1F\u061F]',
  ).hasMatch(selected);
  final exceedsLexicalSpan =
      words.length > _maxContextualLookupWords ||
      selected.runes.length > _maxContextualLookupCharacters;

  return isWholeContext || containsSentenceBoundary || exceedsLexicalSpan
      ? selectedTextTranslationMode
      : contextualTranslationMode;
}

String _collapseWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

const _maxContextualLookupWords = 6;
const _maxContextualLookupCharacters = 64;
