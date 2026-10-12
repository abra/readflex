import 'package:flutter/material.dart';

import 'theme/app_typography.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Muted metadata line under a headword: reading, pronunciation and part of
/// speech, wrapping onto further lines when the width is narrow.
///
/// Every string is already localized or language-specific; the row does not
/// translate grammatical tags. [pronunciation] is IPA and always renders
/// left-to-right in the bundled phonetic font. [textDirection] is the
/// headword's own writing direction: the row starts on the headword's edge
/// and orders its pieces that way, and [reading] is set in it, even in an
/// interface with the other direction. Without it the row follows the
/// ambient direction. Each piece keeps its own semantics node so assistive
/// technology reads them as separate items. Renders nothing when all three
/// are null or blank.
class AppLexicalMetadataRow extends StatelessWidget {
  const AppLexicalMetadataRow({
    this.pronunciation,
    this.reading,
    this.partOfSpeech,
    this.textDirection,
    super.key,
  });

  final String? pronunciation;
  final String? reading;
  final String? partOfSpeech;
  final TextDirection? textDirection;

  /// Whether every piece is null or blank: the row then renders nothing,
  /// and callers drop the spacing around it.
  bool get isEmpty =>
      _nonBlank(reading) == null &&
      _nonBlank(pronunciation) == null &&
      _nonBlank(partOfSpeech) == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final reading = _nonBlank(this.reading);
    final pronunciation = _nonBlank(this.pronunciation);
    final partOfSpeech = _nonBlank(this.partOfSpeech);
    final style = context.text.bodyMedium.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Wrap(
      textDirection: textDirection,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (reading != null)
          Semantics(
            container: true,
            child: Text(reading, textDirection: textDirection, style: style),
          ),
        if (pronunciation != null)
          Semantics(
            container: true,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                pronunciation,
                style: style.copyWith(
                  fontFamily: AppTypography.fontFamilyPhonetic,
                ),
              ),
            ),
          ),
        if (partOfSpeech != null)
          Semantics(container: true, child: Text(partOfSpeech, style: style)),
      ],
    );
  }
}

String? _nonBlank(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
