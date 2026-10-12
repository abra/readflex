import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'translation_text_direction.dart';

/// The selected text, or with [showContext] its sentence with the selection
/// in semibold.
///
/// [quoted] sets it as a source quote, for the phrase being worked on while
/// the sheet loads or fails. Unquoted it is the muted source line above its
/// translation: secondary text with the selection in the body color.
class TranslationSelectionPreview extends StatelessWidget {
  const TranslationSelectionPreview({
    required this.selection,
    required this.showContext,
    this.quoted = true,
    super.key,
  });

  final TextSelectionContext selection;
  final bool showContext;
  final bool quoted;

  @override
  Widget build(BuildContext context) {
    final preview = showContext
        ? _SelectionPreviewData.contextual(selection)
        : _SelectionPreviewData.plain(selection.effectiveSelectedText);
    final baseStyle = context.text.bodyMedium.copyWith(
      color: quoted
          ? context.colors.onSurface
          : context.colors.onSurfaceVariant,
    );
    final selectedStyle = baseStyle.copyWith(
      color: context.colors.onSurface,
      fontWeight: FontWeight.w600,
    );

    final textDirection = translationTextDirection(
      '${preview.before}${preview.selected}${preview.after}',
    );
    final text = Text.rich(
      key: const ValueKey('translation-selection-preview-text'),
      textDirection: textDirection,
      TextSpan(
        style: baseStyle,
        children: [
          if (preview.before.isNotEmpty) TextSpan(text: preview.before),
          if (preview.selected.isNotEmpty)
            TextSpan(text: preview.selected, style: selectedStyle),
          if (preview.after.isNotEmpty) TextSpan(text: preview.after),
        ],
      ),
    );
    if (!quoted) {
      return KeyedSubtree(
        key: const ValueKey('translation-selection-preview'),
        child: text,
      );
    }
    return AppSourceQuote(
      key: const ValueKey('translation-selection-preview'),
      textDirection: textDirection,
      child: text,
    );
  }
}

class _SelectionPreviewData {
  const _SelectionPreviewData({
    required this.before,
    required this.selected,
    required this.after,
  });

  final String before;
  final String selected;
  final String after;

  factory _SelectionPreviewData.plain(String text) {
    return _SelectionPreviewData(before: text.trim(), selected: '', after: '');
  }

  factory _SelectionPreviewData.contextual(TextSelectionContext selection) {
    final selectedText = selection.effectiveSelectedText.trim();
    final marked = _fromMarkedText(
      selection.effectiveMarkedContextText,
      expectedSelection: selectedText,
    );
    if (marked != null) return marked;

    final contextText = selection.contextText?.trim();
    if (contextText == null || contextText.isEmpty) {
      return _SelectionPreviewData.plain(selectedText);
    }

    final matchIndex = _uniqueMatchIndex(contextText, selectedText);
    if (matchIndex == null) return _SelectionPreviewData.plain(contextText);

    return _SelectionPreviewData(
      before: contextText.substring(0, matchIndex),
      selected: selectedText,
      after: contextText.substring(matchIndex + selectedText.length),
    );
  }

  static _SelectionPreviewData? _fromMarkedText(
    String? markedText, {
    required String expectedSelection,
  }) {
    final text = markedText?.trim();
    if (text == null || text.isEmpty) return null;

    final opening = text.indexOf('[[');
    final closing = opening < 0 ? -1 : text.indexOf(']]', opening + 2);
    final hasSinglePair =
        opening >= 0 &&
        closing > opening + 2 &&
        text.lastIndexOf('[[') == opening &&
        text.indexOf(']]') == closing &&
        text.lastIndexOf(']]') == closing;
    if (!hasSinglePair) return null;

    final selected = text.substring(opening + 2, closing);
    if (_collapseWhitespace(selected) !=
        _collapseWhitespace(expectedSelection)) {
      return null;
    }

    return _SelectionPreviewData(
      before: text.substring(0, opening),
      selected: selected,
      after: text.substring(closing + 2),
    );
  }
}

int? _uniqueMatchIndex(String text, String selection) {
  if (selection.isEmpty) return null;
  final first = text.indexOf(selection);
  if (first < 0) return null;
  final next = text.indexOf(selection, first + selection.length);
  return next < 0 ? first : null;
}

String _collapseWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();
